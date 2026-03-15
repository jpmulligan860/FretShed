// LearningPhaseManager.swift
// FretShed — Quiz Layer
//
// Tracks the user's position in the 4-phase learning progression:
// Foundation → Connection → Expansion → Fluency.
// Persisted via UserDefaults (lightweight global state, not per-session data).

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "LearningPhaseManager")

// MARK: - LearningPhase

/// The 4-phase progression that structures Smart Practice sessions.
enum LearningPhase: Int, Codable, CaseIterable, Sendable {
    case foundation = 1   // Single string, natural notes
    case connection = 2   // Cross-string, natural notes
    case expansion  = 3   // Sharps & flats (premium)
    case fluency    = 4   // Full fretboard, all notes

    var displayName: String {
        switch self {
        case .foundation: return "Foundation"
        case .connection: return "Connection"
        case .expansion:  return "Expansion"
        case .fluency:    return "Fluency"
        }
    }

    var description: String {
        switch self {
        case .foundation: return "Learn natural notes one string at a time"
        case .connection: return "Find notes across multiple strings"
        case .expansion:  return "Add sharps and flats to your vocabulary"
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

    /// Number of strings that must pass Phase 1 before advancing to Phase 2.
    static let stringsRequiredForPhase2: Int = 3

    /// Free-tier constraints (matching SmartPracticeEngine).
    static let freeStrings: [Int] = [4, 5, 6]
    static let freeFretStart = 0
    static let freeFretEnd = 7

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let currentPhase = "learningPhase_current"
        static let targetString = "learningPhase_targetString"
        static let completedStrings = "learningPhase_completedStrings"
        static let diagnosticMode = "learningPhase_diagnosticMode"
        static let confirmationMode = "learningPhase_confirmationMode"
        static let stuckNotes = "learningPhase_stuckNotes"
    }

    // MARK: - State

    var currentPhase: LearningPhase
    var currentTargetString: Int?
    var phaseOneCompletedStrings: Set<Int>
    var isInDiagnosticMode: Bool
    var isInConfirmationMode: Bool
    var stuckNotes: [StuckNote]

    // MARK: - Dependencies

    private let fretboardMap: FretboardMap

    // MARK: - Init

    init(fretboardMap: FretboardMap = FretboardMap()) {
        self.fretboardMap = fretboardMap

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

        self.isInDiagnosticMode = UserDefaults.standard.bool(forKey: Keys.diagnosticMode)
        self.isInConfirmationMode = UserDefaults.standard.bool(forKey: Keys.confirmationMode)

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
        stuckNotes = []

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
        switch currentPhase {
        case .foundation:
            return evaluateFoundationAdvancement(using: scores)
        case .connection:
            return evaluateConnectionAdvancement(using: scores)
        case .expansion:
            return evaluateExpansionAdvancement(using: scores)
        case .fluency:
            return false // Already at max
        }
    }

    // MARK: Foundation (Phase 1) Advancement

    private func evaluateFoundationAdvancement(using scores: [MasteryScore]) -> Bool {
        guard let targetString = currentTargetString else { return false }

        // Get natural notes on the target string within free fret range
        let naturalCells = naturalNoteCells(onString: targetString)

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

        // Check if enough strings are done to advance to Phase 2
        if phaseOneCompletedStrings.count >= Self.stringsRequiredForPhase2 {
            currentPhase = .connection
            currentTargetString = nil
            logger.info("Advanced to Phase 2: Connection")
        } else {
            // Move to next string
            currentTargetString = nextUncompletedString()
        }

        persist()
        return true
    }

    // MARK: Connection (Phase 2) Advancement

    private func evaluateConnectionAdvancement(using scores: [MasteryScore]) -> Bool {
        // All natural notes across all 6 strings must reach threshold
        for string in 1...kStringCount {
            let naturalCells = naturalNoteCells(onString: string)
            for (note, _) in naturalCells {
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

        currentPhase = .expansion
        persist()
        logger.info("Advanced to Phase 3: Expansion")
        return true
    }

    // MARK: Expansion (Phase 3) Advancement

    private func evaluateExpansionAdvancement(using scores: [MasteryScore]) -> Bool {
        // All chromatic positions on all strings within fret range must reach threshold
        for string in 1...kStringCount {
            for fret in Self.freeFretStart...Self.freeFretEnd {
                guard let note = fretboardMap.note(string: string, fret: fret) else { continue }
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
        persist()
        logger.info("Advanced to Phase 4: Fluency")
        return true
    }

    // MARK: - Progress

    /// Returns the current advancement progress as a fraction and a milestone description.
    func phaseAdvancementProgress() -> (completed: Int, total: Int, nextMilestone: String) {
        switch currentPhase {
        case .foundation:
            let completed = phaseOneCompletedStrings.count
            let total = Self.stringsRequiredForPhase2
            if let target = currentTargetString {
                let stringName = Self.stringName(target)
                return (completed, total, "Complete the \(stringName) string")
            }
            return (completed, total, "Complete \(total - completed) more strings")

        case .connection:
            return (phaseOneCompletedStrings.count, kStringCount, "Master natural notes on all 6 strings")

        case .expansion:
            return (0, 1, "Master sharps and flats across the fretboard")

        case .fluency:
            return (1, 1, "Full fretboard mastery — keep practicing!")
        }
    }

    /// Returns progress within the current Phase 1 target string.
    /// - Parameter scores: Current mastery scores.
    /// - Returns: Tuple of (mastered count, total natural notes on string).
    func currentStringProgress(using scores: [MasteryScore]) -> (mastered: Int, total: Int)? {
        guard currentPhase == .foundation, let targetString = currentTargetString else { return nil }
        let naturalCells = naturalNoteCells(onString: targetString)
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

    // MARK: - Diagnostic / Confirmation Mode

    /// Completes diagnostic mode and places the user based on results.
    func completeDiagnostic(using scores: [MasteryScore]) {
        isInDiagnosticMode = false

        // Find the weakest string among free-tier strings based on diagnostic results
        var weakestString = Self.freeStrings.first ?? 6
        var lowestAvg = Double.infinity
        for string in Self.freeStrings {
            let naturalCells = naturalNoteCells(onString: string)
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

    /// Returns the natural note cells on a given string within the free fret range.
    /// Each entry is (note, fret) — representing a unique natural note position.
    func naturalNoteCells(onString string: Int) -> [(note: MusicalNote, fret: Int)] {
        var cells: [(note: MusicalNote, fret: Int)] = []
        var seenNotes: Set<Int> = []  // Deduplicate by note rawValue

        for fret in Self.freeFretStart...Self.freeFretEnd {
            guard let note = fretboardMap.note(string: string, fret: fret),
                  note.isNatural,
                  !seenNotes.contains(note.rawValue) else { continue }
            seenNotes.insert(note.rawValue)
            cells.append((note: note, fret: fret))
        }
        return cells
    }

    /// Returns the next uncompleted string in the free tier, or nil if all done.
    private func nextUncompletedString() -> Int? {
        // Prefer strings in order: 6 (low E), 5 (A), 4 (D) — for free tier
        for string in Self.freeStrings.sorted().reversed() {
            if !phaseOneCompletedStrings.contains(string) {
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

        UserDefaults.standard.set(isInDiagnosticMode, forKey: Keys.diagnosticMode)
        UserDefaults.standard.set(isInConfirmationMode, forKey: Keys.confirmationMode)

        if let stuckData = try? JSONEncoder().encode(stuckNotes) {
            UserDefaults.standard.set(stuckData, forKey: Keys.stuckNotes)
        }
    }

    /// Resets all phase state. Used for testing and data deletion.
    func reset() {
        currentPhase = .foundation
        currentTargetString = nil
        phaseOneCompletedStrings = []
        isInDiagnosticMode = false
        isInConfirmationMode = false
        stuckNotes = []

        for key in [Keys.currentPhase, Keys.targetString, Keys.completedStrings,
                    Keys.diagnosticMode, Keys.confirmationMode, Keys.stuckNotes] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
