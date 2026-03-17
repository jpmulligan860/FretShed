// LearningPhaseManager.swift
// FretShed — Quiz Layer
//
// Tracks the user's position in the 4-phase learning progression:
// Foundation → Expansion → Connection → Fluency.
// Persisted via UserDefaults (lightweight global state, not per-session data).

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "LearningPhaseManager")

// MARK: - LearningPhase

/// The 4-phase progression that structures Smart Practice sessions.
/// Phase 2/3 were resequenced in v2: Expansion (sharps/flats, single-string)
/// now comes before Connection (cross-string, all notes).
enum LearningPhase: Int, Codable, CaseIterable, Sendable {
    case foundation = 1   // Single string, natural notes, frets 0-12
    case expansion  = 2   // Single string, sharps & flats, frets 0-12
    case connection = 3   // Cross-string, all notes, any key
    case fluency    = 4   // Full fretboard, all notes

    var displayName: String {
        switch self {
        case .foundation: return "Foundation"
        case .expansion:  return "Expansion"
        case .connection: return "Connection"
        case .fluency:    return "Fluency"
        }
    }

    var description: String {
        switch self {
        case .foundation: return "Learn natural notes one string at a time"
        case .expansion:  return "Add sharps and flats to your vocabulary"
        case .connection: return "Find notes across multiple strings using all notes"
        case .fluency:    return "Master the full fretboard"
        }
    }

    /// The next phase in the progression, or nil if already at fluency.
    var next: LearningPhase? {
        LearningPhase(rawValue: rawValue + 1)
    }
}

// MARK: - StuckNote

/// A note that advanced via the grace threshold and needs periodic review.
struct StuckNote: Codable, Equatable, Sendable {
    let noteRaw: Int       // MusicalNote.rawValue
    let stringNumber: Int
    let phaseWhenStuck: Int // LearningPhase.rawValue

    var note: MusicalNote {
        MusicalNote(rawValue: noteRaw) ?? .c
    }
}

// MARK: - LearningPhaseManager

/// Manages the user's progression through the 4-phase learning system.
/// State is persisted via UserDefaults — lightweight global state, not SwiftData.
@MainActor @Observable
final class LearningPhaseManager {

    // MARK: - Constants

    /// Bayesian score threshold for a cell to count as "passed" for advancement.
    static let advancementThreshold: Double = 0.75

    /// Minimum score for a stuck note to qualify for the grace threshold.
    static let graceFloor: Double = 0.40

    /// Minimum attempts for a cell to be considered (cells with 0 attempts don't count).
    static let minimumAttempts: Int = 3

    /// All 6 strings.
    static let allStrings: [Int] = [1, 2, 3, 4, 5, 6]

    /// Fret range for advancement checks and session building (0-12).
    /// Phase 4 (EntitlementManager) will gate free-tier to frets 0-7.
    static let phaseRequiredFretEnd = 12
    static let fretStart = 0

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let currentPhase = "learningPhase_current"
        static let targetString = "learningPhase_targetString"
        static let completedStrings = "learningPhase_completedStrings"
        static let diagnosticMode = "learningPhase_diagnosticMode"
        static let confirmationMode = "learningPhase_confirmationMode"
        static let stuckNotes = "learningPhase_stuckNotes"
        static let sessionsInPhase = "learningPhase_sessionsInPhase"
        // Phase 2 (Expansion) per-string tracking
        static let phaseTwoCompletedStrings = "learningPhase_phaseTwoCompletedStrings"
        static let phaseTwoTargetString = "learningPhase_phaseTwoTargetString"
        // v2 migration flag
        static let v2Migrated = "learningPhase_v2Migrated"
    }

    /// Minimum sessions the user must complete in a phase before advancing.
    /// Prevents skipping phases when prior mastery already satisfies conditions.
    static let minimumSessionsBeforeAdvancement: Int = 3

    // MARK: - State

    var currentPhase: LearningPhase
    var currentTargetString: Int?
    var phaseOneCompletedStrings: Set<Int>
    var phaseTwoCompletedStrings: Set<Int>
    var currentPhaseTwoTargetString: Int?
    var isInDiagnosticMode: Bool
    var isInConfirmationMode: Bool
    var stuckNotes: [StuckNote]
    var sessionsInCurrentPhase: Int

    // MARK: - Dependencies

    private let fretboardMap: FretboardMap

    // MARK: - Init

    init(fretboardMap: FretboardMap = FretboardMap()) {
        self.fretboardMap = fretboardMap

        // v2 migration: swap connection(2) ↔ expansion(3) raw values
        if !UserDefaults.standard.bool(forKey: Keys.v2Migrated) {
            let raw = UserDefaults.standard.integer(forKey: Keys.currentPhase)
            if raw == 2 {
                // Was connection (old Phase 2) → now expansion (new Phase 2)
                // Content matches: single-string work stays single-string
                UserDefaults.standard.set(2, forKey: Keys.currentPhase)
            } else if raw == 3 {
                // Was expansion (old Phase 3) → now connection (new Phase 3)
                UserDefaults.standard.set(3, forKey: Keys.currentPhase)
            }
            UserDefaults.standard.set(true, forKey: Keys.v2Migrated)
        }

        // Load persisted state
        let phaseRaw = UserDefaults.standard.integer(forKey: Keys.currentPhase)
        self.currentPhase = LearningPhase(rawValue: phaseRaw) ?? .foundation

        let targetRaw = UserDefaults.standard.integer(forKey: Keys.targetString)
        self.currentTargetString = targetRaw > 0 ? targetRaw : nil

        if let completedData = UserDefaults.standard.data(forKey: Keys.completedStrings),
           let decoded = try? JSONDecoder().decode(Set<Int>.self, from: completedData) {
            self.phaseOneCompletedStrings = decoded
        } else {
            self.phaseOneCompletedStrings = []
        }

        if let p2Data = UserDefaults.standard.data(forKey: Keys.phaseTwoCompletedStrings),
           let decoded = try? JSONDecoder().decode(Set<Int>.self, from: p2Data) {
            self.phaseTwoCompletedStrings = decoded
        } else {
            self.phaseTwoCompletedStrings = []
        }

        let p2Target = UserDefaults.standard.integer(forKey: Keys.phaseTwoTargetString)
        self.currentPhaseTwoTargetString = p2Target > 0 ? p2Target : nil

        self.isInDiagnosticMode = UserDefaults.standard.bool(forKey: Keys.diagnosticMode)
        self.isInConfirmationMode = UserDefaults.standard.bool(forKey: Keys.confirmationMode)
        self.sessionsInCurrentPhase = UserDefaults.standard.integer(forKey: Keys.sessionsInPhase)

        if let stuckData = UserDefaults.standard.data(forKey: Keys.stuckNotes),
           let decoded = try? JSONDecoder().decode([StuckNote].self, from: stuckData) {
            self.stuckNotes = decoded
        } else {
            self.stuckNotes = []
        }
    }

    // MARK: - Cold Start

    /// Initializes the phase manager for a new user based on their onboarding baseline.
    func initializeForBaseline(_ baseline: BaselineLevel) {
        currentPhase = .foundation
        phaseOneCompletedStrings = []
        phaseTwoCompletedStrings = []
        currentPhaseTwoTargetString = nil
        stuckNotes = []
        sessionsInCurrentPhase = 0

        switch baseline {
        case .startingFresh:
            currentTargetString = 1  // high E — best audio accuracy, easiest physically
            isInDiagnosticMode = false
            isInConfirmationMode = false

        case .chordPlayer:
            currentTargetString = 5  // A string — connects to open chord roots
            isInDiagnosticMode = false
            isInConfirmationMode = false

        case .openPosition:
            // Verify priors before advancing — start confirmation on highest-prior string
            currentTargetString = startingStringForBaseline(.openPosition)
            isInDiagnosticMode = false
            isInConfirmationMode = true

        case .lowStringsSolid:
            // Verify, then start Phase 1 on string 4
            currentTargetString = startingStringForBaseline(.lowStringsSolid)
            isInDiagnosticMode = false
            isInConfirmationMode = true

        case .rustyEverywhere:
            currentTargetString = nil  // Diagnostic covers all strings
            isInDiagnosticMode = true
            isInConfirmationMode = false
        }

        persist()
        logger.info("Initialized for baseline: \(baseline.rawValue), target string: \(self.currentTargetString ?? 0), diagnostic: \(self.isInDiagnosticMode), confirmation: \(self.isInConfirmationMode)")
    }

    /// Maps a baseline level to the starting string for Phase 1.
    func startingStringForBaseline(_ baseline: BaselineLevel) -> Int {
        switch baseline {
        case .startingFresh:    return 1   // high E
        case .chordPlayer:      return 5   // A string
        case .openPosition:     return 1   // high E (highest prior area — verify first)
        case .lowStringsSolid:  return 5   // A string (verify known area, then move to D)
        case .rustyEverywhere:  return 6   // low E (after diagnostic)
        }
    }

    // MARK: - Phase Advancement

    /// Evaluates whether the current target/phase should advance based on mastery data.
    /// Returns `true` if advancement occurred.
    @discardableResult
    func evaluateAdvancement(using scores: [MasteryScore]) -> Bool {
        // Track sessions in current phase (each call = one completed session)
        sessionsInCurrentPhase += 1
        persist()

        switch currentPhase {
        case .foundation:
            return evaluateFoundationAdvancement(using: scores)
        case .expansion:
            guard sessionsInCurrentPhase >= Self.minimumSessionsBeforeAdvancement else {
                logger.info("Expansion: \(self.sessionsInCurrentPhase)/\(Self.minimumSessionsBeforeAdvancement) sessions before advancement eligible")
                return false
            }
            return evaluateExpansionAdvancement(using: scores)
        case .connection:
            guard sessionsInCurrentPhase >= Self.minimumSessionsBeforeAdvancement else {
                logger.info("Connection: \(self.sessionsInCurrentPhase)/\(Self.minimumSessionsBeforeAdvancement) sessions before advancement eligible")
                return false
            }
            return evaluateConnectionAdvancement(using: scores)
        case .fluency:
            return false // Already at max
        }
    }

    // MARK: Foundation (Phase 1) Advancement

    private func evaluateFoundationAdvancement(using scores: [MasteryScore]) -> Bool {
        // Auto-recover if currentTargetString is nil: scan all 6 strings,
        // credit any that are already mastered, then pick the next uncompleted one.
        if currentTargetString == nil {
            autoDetectCompletedStrings(using: scores)
            if phaseOneCompletedStrings.count >= Self.allStrings.count {
                currentPhase = .expansion
                currentTargetString = nil
                currentPhaseTwoTargetString = nextUncompletedPhaseTwoString()
                sessionsInCurrentPhase = 0
                persist()
                logger.info("Auto-advanced to Phase 2: Expansion (recovered from nil targetString)")
                return true
            }
            if let next = nextUncompletedString() {
                currentTargetString = next
                persist()
                logger.info("Auto-assigned target string \(next) (recovered from nil)")
            } else {
                return false
            }
        }

        guard let targetString = currentTargetString else { return false }

        // Get natural notes on the target string within learning fret range (0-12)
        let naturalCells = naturalNoteCells(onString: targetString, fretEnd: Self.phaseRequiredFretEnd)

        // Check each cell
        var passedCount = 0
        var stuckCandidate: (noteRaw: Int, stringNumber: Int)?
        var failedCount = 0

        for (note, _) in naturalCells {
            let cellScore = scores.first(where: {
                $0.noteRaw == note.rawValue && $0.stringNumber == targetString
            })

            let attempts = cellScore?.totalAttempts ?? 0
            let score = cellScore?.effectiveScore ?? defaultScore()

            if attempts < Self.minimumAttempts {
                // Not enough data — doesn't count as passed
                failedCount += 1
                continue
            }

            if score >= Self.advancementThreshold {
                passedCount += 1
            } else if score >= Self.graceFloor {
                // Potential grace candidate, but NOT for open strings (fret 0)
                let isOpenString = naturalCells.first(where: { $0.note == note })?.fret == 0
                if isOpenString {
                    failedCount += 1
                } else if stuckCandidate == nil {
                    stuckCandidate = (noteRaw: note.rawValue, stringNumber: targetString)
                } else {
                    // Already have one grace candidate — this is a second failure
                    failedCount += 1
                }
            } else {
                failedCount += 1
            }
        }

        let totalCells = naturalCells.count
        let passedWithGrace = stuckCandidate != nil ? passedCount + 1 : passedCount

        // Advance if all cells pass (with at most 1 grace)
        guard failedCount == 0 && passedWithGrace >= totalCells else {
            return false
        }

        // Record stuck note if grace was used
        if let stuck = stuckCandidate {
            let stuckNote = StuckNote(
                noteRaw: stuck.noteRaw,
                stringNumber: stuck.stringNumber,
                phaseWhenStuck: LearningPhase.foundation.rawValue
            )
            if !stuckNotes.contains(stuckNote) {
                stuckNotes.append(stuckNote)
            }
        }

        // Mark string as completed
        phaseOneCompletedStrings.insert(targetString)
        logger.info("Phase 1: String \(targetString) completed. Total completed: \(self.phaseOneCompletedStrings.count)")

        // Check if all 6 strings are done to advance to Phase 2 (Expansion)
        if phaseOneCompletedStrings.count >= Self.allStrings.count {
            currentPhase = .expansion
            currentTargetString = nil
            currentPhaseTwoTargetString = nextUncompletedPhaseTwoString()
            sessionsInCurrentPhase = 0
            logger.info("Advanced to Phase 2: Expansion")
        } else {
            // Move to next string
            currentTargetString = nextUncompletedString()
        }

        persist()
        return true
    }

    // MARK: Expansion (Phase 2) Advancement — per-string sharps/flats check

    private func evaluateExpansionAdvancement(using scores: [MasteryScore]) -> Bool {
        // Auto-assign a target string if nil
        if currentPhaseTwoTargetString == nil {
            autoDetectCompletedPhaseTwoStrings(using: scores)
            if phaseTwoCompletedStrings.count >= Self.allStrings.count {
                currentPhase = .connection
                currentPhaseTwoTargetString = nil
                sessionsInCurrentPhase = 0
                persist()
                logger.info("Auto-advanced to Phase 3: Connection (recovered from nil)")
                return true
            }
            currentPhaseTwoTargetString = nextUncompletedPhaseTwoString()
            persist()
        }

        guard let targetString = currentPhaseTwoTargetString else { return false }

        // Check ALL chromatic positions on this string (frets 0-12)
        let chromaticPositions = chromaticCells(onString: targetString, fretEnd: Self.phaseRequiredFretEnd)
        var passedCount = 0
        var stuckCandidate: (noteRaw: Int, stringNumber: Int)?
        var failedCount = 0

        for (note, _) in chromaticPositions {
            let cellScore = scores.first(where: {
                $0.noteRaw == note.rawValue && $0.stringNumber == targetString
            })
            let attempts = cellScore?.totalAttempts ?? 0
            let score = cellScore?.effectiveScore ?? defaultScore()

            if attempts < Self.minimumAttempts {
                failedCount += 1
                continue
            }

            if score >= Self.advancementThreshold {
                passedCount += 1
            } else if score >= Self.graceFloor {
                if stuckCandidate == nil {
                    stuckCandidate = (noteRaw: note.rawValue, stringNumber: targetString)
                } else {
                    failedCount += 1
                }
            } else {
                failedCount += 1
            }
        }

        let totalCells = chromaticPositions.count
        let passedWithGrace = stuckCandidate != nil ? passedCount + 1 : passedCount

        guard failedCount == 0 && passedWithGrace >= totalCells else {
            return false
        }

        // Record stuck note if grace was used
        if let stuck = stuckCandidate {
            let stuckNote = StuckNote(
                noteRaw: stuck.noteRaw,
                stringNumber: stuck.stringNumber,
                phaseWhenStuck: LearningPhase.expansion.rawValue
            )
            if !stuckNotes.contains(stuckNote) {
                stuckNotes.append(stuckNote)
            }
        }

        // Mark string as completed for Phase 2
        phaseTwoCompletedStrings.insert(targetString)
        logger.info("Phase 2: String \(targetString) chromatic complete. Total: \(self.phaseTwoCompletedStrings.count)")

        // Check if all 6 strings done → advance to Connection
        if phaseTwoCompletedStrings.count >= Self.allStrings.count {
            currentPhase = .connection
            currentPhaseTwoTargetString = nil
            sessionsInCurrentPhase = 0
            logger.info("Advanced to Phase 3: Connection")
        } else {
            currentPhaseTwoTargetString = nextUncompletedPhaseTwoString()
        }

        persist()
        return true
    }

    // MARK: Connection (Phase 3) Advancement — all chromatic cross-string

    private func evaluateConnectionAdvancement(using scores: [MasteryScore]) -> Bool {
        // All chromatic positions across all 6 strings, frets 0-12 must reach threshold
        for string in 1...kStringCount {
            let chromaticPositions = chromaticCells(onString: string, fretEnd: Self.phaseRequiredFretEnd)
            for (note, _) in chromaticPositions {
                let cellScore = scores.first(where: {
                    $0.noteRaw == note.rawValue && $0.stringNumber == string
                })
                let attempts = cellScore?.totalAttempts ?? 0
                let score = cellScore?.effectiveScore ?? defaultScore()
                if attempts < Self.minimumAttempts || score < Self.advancementThreshold {
                    return false
                }
            }
        }

        currentPhase = .fluency
        sessionsInCurrentPhase = 0
        persist()
        logger.info("Advanced to Phase 4: Fluency")
        return true
    }

    // MARK: - Progress

    /// Returns the current advancement progress as a fraction and a milestone description.
    func phaseAdvancementProgress() -> (completed: Int, total: Int, nextMilestone: String) {
        let totalStrings = Self.allStrings.count // 6

        switch currentPhase {
        case .foundation:
            let completed = phaseOneCompletedStrings.count
            if let target = currentTargetString {
                let stringName = Self.stringName(target)
                return (completed, totalStrings, "Complete the \(stringName) string")
            }
            return (completed, totalStrings, "Complete \(totalStrings - completed) more strings")

        case .expansion:
            let completed = phaseTwoCompletedStrings.count
            if let target = currentPhaseTwoTargetString {
                let stringName = Self.stringName(target)
                return (completed, totalStrings, "Complete sharps & flats on the \(stringName) string")
            }
            return (completed, totalStrings, "Complete sharps & flats on \(totalStrings - completed) more strings")

        case .connection:
            return (0, 1, "Master all notes across all strings")

        case .fluency:
            return (1, 1, "Full fretboard mastery — keep practicing!")
        }
    }

    /// Returns progress within the current Phase 1 target string.
    /// - Parameter scores: Current mastery scores.
    /// - Returns: Tuple of (mastered count, total natural notes on string).
    func currentStringProgress(using scores: [MasteryScore]) -> (mastered: Int, total: Int)? {
        guard currentPhase == .foundation, let targetString = currentTargetString else { return nil }
        let naturalCells = naturalNoteCells(onString: targetString, fretEnd: Self.phaseRequiredFretEnd)
        var mastered = 0
        for (note, _) in naturalCells {
            let cellScore = scores.first(where: {
                $0.noteRaw == note.rawValue && $0.stringNumber == targetString
            })
            let attempts = cellScore?.totalAttempts ?? 0
            let score = cellScore?.effectiveScore ?? defaultScore()
            if attempts >= Self.minimumAttempts && score >= Self.advancementThreshold {
                mastered += 1
            }
        }
        return (mastered, naturalCells.count)
    }

    /// Returns progress within the current Phase 2 (Expansion) target string.
    func currentPhaseTwoStringProgress(using scores: [MasteryScore]) -> (mastered: Int, total: Int)? {
        guard currentPhase == .expansion, let targetString = currentPhaseTwoTargetString else { return nil }
        let chromaticPositions = chromaticCells(onString: targetString, fretEnd: Self.phaseRequiredFretEnd)
        var mastered = 0
        for (note, _) in chromaticPositions {
            let cellScore = scores.first(where: {
                $0.noteRaw == note.rawValue && $0.stringNumber == targetString
            })
            let attempts = cellScore?.totalAttempts ?? 0
            let score = cellScore?.effectiveScore ?? defaultScore()
            if attempts >= Self.minimumAttempts && score >= Self.advancementThreshold {
                mastered += 1
            }
        }
        return (mastered, chromaticPositions.count)
    }

    // MARK: - Diagnostic / Confirmation Mode

    /// Completes diagnostic mode and places the user based on results.
    func completeDiagnostic(using scores: [MasteryScore]) {
        isInDiagnosticMode = false

        // Find the weakest string among all 6 strings based on diagnostic results
        var weakestString = 6
        var lowestAvg = Double.infinity
        for string in Self.allStrings {
            let naturalCells = naturalNoteCells(onString: string, fretEnd: Self.phaseRequiredFretEnd)
            let cellScores = naturalCells.compactMap { cell in
                scores.first(where: { $0.noteRaw == cell.note.rawValue && $0.stringNumber == string })?.effectiveScore
            }
            let avg = cellScores.isEmpty ? 0.5 : cellScores.reduce(0, +) / Double(cellScores.count)
            if avg < lowestAvg {
                lowestAvg = avg
                weakestString = string
            }
        }

        currentTargetString = weakestString
        persist()
        logger.info("Diagnostic complete. Starting on string \(weakestString)")
    }

    /// Completes confirmation mode — if the confirmation session passes, auto-advance completed strings.
    func completeConfirmation(passed: Bool, using scores: [MasteryScore]) {
        isInConfirmationMode = false

        if passed, let target = currentTargetString {
            phaseOneCompletedStrings.insert(target)
            currentTargetString = nextUncompletedString()
        }
        // If failed, stay on the same target string — user needs to build mastery

        persist()
        logger.info("Confirmation complete. Passed: \(passed). Target: \(self.currentTargetString ?? 0)")
    }

    // MARK: - Helpers

    /// Scans all 6 strings and credits any that are fully mastered
    /// (all natural notes on frets 0-12 ≥ advancementThreshold with ≥ minimumAttempts).
    /// Called to recover when `currentTargetString` is nil.
    private func autoDetectCompletedStrings(using scores: [MasteryScore]) {
        for string in Self.allStrings {
            guard !phaseOneCompletedStrings.contains(string) else { continue }
            let naturalCells = naturalNoteCells(onString: string, fretEnd: Self.phaseRequiredFretEnd)
            let allPassed = naturalCells.allSatisfy { cell in
                let cellScore = scores.first(where: {
                    $0.noteRaw == cell.note.rawValue && $0.stringNumber == string
                })
                let attempts = cellScore?.totalAttempts ?? 0
                let score = cellScore?.effectiveScore ?? defaultScore()
                return attempts >= Self.minimumAttempts && score >= Self.advancementThreshold
            }
            if allPassed {
                phaseOneCompletedStrings.insert(string)
                logger.info("Auto-detected string \(string) as completed")
            }
        }
    }

    /// Scans all 6 strings for Phase 2 (Expansion) and credits any with full chromatic mastery.
    private func autoDetectCompletedPhaseTwoStrings(using scores: [MasteryScore]) {
        for string in Self.allStrings {
            guard !phaseTwoCompletedStrings.contains(string) else { continue }
            let cells = chromaticCells(onString: string, fretEnd: Self.phaseRequiredFretEnd)
            let allPassed = cells.allSatisfy { cell in
                let cellScore = scores.first(where: {
                    $0.noteRaw == cell.note.rawValue && $0.stringNumber == string
                })
                let attempts = cellScore?.totalAttempts ?? 0
                let score = cellScore?.effectiveScore ?? defaultScore()
                return attempts >= Self.minimumAttempts && score >= Self.advancementThreshold
            }
            if allPassed {
                phaseTwoCompletedStrings.insert(string)
                logger.info("Auto-detected Phase 2 string \(string) as completed")
            }
        }
    }

    /// Returns the natural note cells on a given string within the specified fret range.
    /// Each entry is (note, fret) — representing a unique natural note position.
    func naturalNoteCells(onString string: Int, fretEnd: Int = phaseRequiredFretEnd) -> [(note: MusicalNote, fret: Int)] {
        var cells: [(note: MusicalNote, fret: Int)] = []
        var seenNotes: Set<Int> = []  // Deduplicate by note rawValue

        for fret in Self.fretStart...fretEnd {
            guard let note = fretboardMap.note(string: string, fret: fret),
                  note.isNatural,
                  !seenNotes.contains(note.rawValue) else { continue }
            seenNotes.insert(note.rawValue)
            cells.append((note: note, fret: fret))
        }
        return cells
    }

    /// Returns ALL chromatic note cells on a given string within the specified fret range.
    /// Each entry is (note, fret) — representing a unique note position (deduped by note).
    func chromaticCells(onString string: Int, fretEnd: Int = phaseRequiredFretEnd) -> [(note: MusicalNote, fret: Int)] {
        var cells: [(note: MusicalNote, fret: Int)] = []
        var seenNotes: Set<Int> = []

        for fret in Self.fretStart...fretEnd {
            guard let note = fretboardMap.note(string: string, fret: fret),
                  !seenNotes.contains(note.rawValue) else { continue }
            seenNotes.insert(note.rawValue)
            cells.append((note: note, fret: fret))
        }
        return cells
    }

    /// Returns the next uncompleted string across all 6, or nil if all done.
    private func nextUncompletedString() -> Int? {
        // Prefer strings in order: 6 (low E), 5, 4, 3, 2, 1
        for string in Self.allStrings.sorted().reversed() {
            if !phaseOneCompletedStrings.contains(string) {
                return string
            }
        }
        return nil
    }

    /// Returns the next uncompleted string for Phase 2 (Expansion), or nil.
    private func nextUncompletedPhaseTwoString() -> Int? {
        for string in Self.allStrings.sorted().reversed() {
            if !phaseTwoCompletedStrings.contains(string) {
                return string
            }
        }
        return nil
    }

    /// The Bayesian prior score for an unseen cell.
    private func defaultScore() -> Double {
        MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta) // 2/3 ≈ 0.667
    }

    static func stringName(_ string: Int) -> String {
        switch string {
        case 1: return "high E"
        case 2: return "B"
        case 3: return "G"
        case 4: return "D"
        case 5: return "A"
        case 6: return "low E"
        default: return "\(string)"
        }
    }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(currentPhase.rawValue, forKey: Keys.currentPhase)
        UserDefaults.standard.set(currentTargetString ?? 0, forKey: Keys.targetString)

        if let completedData = try? JSONEncoder().encode(phaseOneCompletedStrings) {
            UserDefaults.standard.set(completedData, forKey: Keys.completedStrings)
        }

        if let p2Data = try? JSONEncoder().encode(phaseTwoCompletedStrings) {
            UserDefaults.standard.set(p2Data, forKey: Keys.phaseTwoCompletedStrings)
        }

        UserDefaults.standard.set(currentPhaseTwoTargetString ?? 0, forKey: Keys.phaseTwoTargetString)
        UserDefaults.standard.set(isInDiagnosticMode, forKey: Keys.diagnosticMode)
        UserDefaults.standard.set(isInConfirmationMode, forKey: Keys.confirmationMode)
        UserDefaults.standard.set(sessionsInCurrentPhase, forKey: Keys.sessionsInPhase)

        if let stuckData = try? JSONEncoder().encode(stuckNotes) {
            UserDefaults.standard.set(stuckData, forKey: Keys.stuckNotes)
        }
    }

    /// Resets all phase state. Used for testing and data deletion.
    func reset() {
        currentPhase = .foundation
        currentTargetString = nil
        phaseOneCompletedStrings = []
        phaseTwoCompletedStrings = []
        currentPhaseTwoTargetString = nil
        isInDiagnosticMode = false
        isInConfirmationMode = false
        stuckNotes = []
        sessionsInCurrentPhase = 0

        for key in [Keys.currentPhase, Keys.targetString, Keys.completedStrings,
                    Keys.diagnosticMode, Keys.confirmationMode, Keys.stuckNotes,
                    Keys.sessionsInPhase, Keys.phaseTwoCompletedStrings,
                    Keys.phaseTwoTargetString, Keys.v2Migrated] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
