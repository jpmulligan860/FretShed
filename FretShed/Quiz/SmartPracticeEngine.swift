// SmartPracticeEngine.swift
// FretShed — Quiz Layer
//
// Generates Smart Practice sessions using the 4-phase learning progression.
// Reads current phase from LearningPhaseManager, generates musically grouped
// questions via NoteGroupingEngine, and maintains session narrative continuity.

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "SmartPracticeEngine")

// MARK: - SmartPracticeMode (kept for backward compat with UserDefaults key)

/// The three focus mode categories that Smart Practice rotates through.
/// Retained for backward compatibility — new sessions use phase-based planning.
enum SmartPracticeMode: String, CaseIterable {
    case fullFretboard
    case singleString
    case sameNote
}

// MARK: - SmartPracticeEngine

@MainActor
final class SmartPracticeEngine {

    private let masteryRepository: any MasteryRepository
    private let sessionRepository: any SessionRepository
    private let fretboardMap: FretboardMap
    private let phaseManager: LearningPhaseManager
    private let groupingEngine: NoteGroupingEngine

    // Free-tier constraints (hardcoded until Phase 4 EntitlementManager)
    static let freeStrings: [Int] = [4, 5, 6]
    static let freeFretStart = 0
    static let freeFretEnd = 7

    // Struggling user detection
    private static let strugglingSessionThreshold = 3
    private static let strugglingAccuracyThreshold: Double = 60.0 // percent
    private static let recoverySessionCount = 2
    private static let consecutiveAccuracyKey = "smartPractice_consecutivePoorSessions"
    private static let isStrugglingKey = "smartPractice_isStruggling"

    init(
        masteryRepository: any MasteryRepository,
        sessionRepository: any SessionRepository,
        fretboardMap: FretboardMap,
        phaseManager: LearningPhaseManager? = nil
    ) {
        self.masteryRepository = masteryRepository
        self.sessionRepository = sessionRepository
        self.fretboardMap = fretboardMap
        self.phaseManager = phaseManager ?? LearningPhaseManager(fretboardMap: fretboardMap)
        self.groupingEngine = NoteGroupingEngine(fretboardMap: fretboardMap)
    }

    // MARK: - Public API (preserved for PracticeHomeView compatibility)

    /// Returns the next Smart Practice session and a human-readable description.
    func nextSession() throws -> (session: Session, description: String) {
        let allScores = try masteryRepository.allScores()

        // Only evaluate Foundation advancement here (handles nil targetString
        // recovery). Connection/Expansion advancement happens on the results
        // screen (QuizView.loadPhaseContext) so the user always gets at least
        // one session in each phase before advancing further.
        if phaseManager.currentPhase == .foundation {
            phaseManager.evaluateAdvancement(using: allScores)
        }

        let description = currentFocusDescription(using: allScores)

        // Check for review session need (returning user)
        if needsReviewSession(using: allScores) {
            let session = buildReviewSession(using: allScores)
            return (session, description)
        }

        // Build phase-appropriate session
        let session = try buildPhaseSession(using: allScores)
        return (session, description)
    }

    /// Returns the current phase description without side effects.
    func nextModeDescription() -> String {
        let phase = phaseManager.currentPhase
        switch phase {
        case .foundation:
            if let target = phaseManager.currentTargetString {
                return "\(Self.stringName(target)) String"
            }
            return "Foundation"
        case .connection: return "Cross-String"
        case .expansion:  return "Sharps & Flats"
        case .fluency:    return "Full Fretboard"
        }
    }

    /// Returns a detailed description of the next session without side effects.
    func peekNextSessionDescription() throws -> String {
        let allScores = try masteryRepository.allScores()
        return currentFocusDescription(using: allScores)
    }

    /// Count of fretboard cells with mastery score below 0.50 (within free area).
    func weakSpotCount() throws -> Int {
        let allScores = try masteryRepository.allScores()
        var count = 0
        for string in Self.freeStrings {
            guard let fretMap = fretboardMap.map[string] else { continue }
            for fret in Self.freeFretStart...Self.freeFretEnd {
                guard let note = fretMap[fret] else { continue }
                let cellScore = allScores.first(where: {
                    $0.noteRaw == note.rawValue && $0.stringNumber == string
                })
                if let score = cellScore {
                    if score.score < 0.50 { count += 1 }
                } else {
                    count += 1
                }
            }
        }
        return count
    }

    /// Returns two alternative session options for quick-start tiles.
    func alternativeSessions() throws -> [(session: Session, title: String, subtitle: String, icon: String)] {
        let allScores = try masteryRepository.allScores()
        var alternatives: [(session: Session, title: String, subtitle: String, icon: String)] = []

        // Always offer Full Fretboard as an alternative
        let fullSession = Session(
            focusMode: .fullFretboard,
            gameMode: .untimed,
            fretRangeStart: Self.freeFretStart,
            fretRangeEnd: Self.freeFretEnd,
            isAdaptive: true
        )
        alternatives.append((fullSession, "Full Fretboard", "Cover all positions", "rectangle.grid.3x2.fill"))

        // Offer weakest string as alternative
        let weakest = Self.weakestString(from: allScores, strings: Self.freeStrings)
        let name = Self.stringName(weakest)
        let stringSession = Session(
            focusMode: .singleString,
            gameMode: .untimed,
            fretRangeStart: Self.freeFretStart,
            fretRangeEnd: Self.freeFretEnd,
            targetStrings: [weakest],
            isAdaptive: true
        )
        alternatives.append((stringSession, "Single String", "Weakest: \(Self.stringOrdinal(weakest)) — \(name)", "custom.singleString.\(weakest)"))

        return alternatives
    }

    // MARK: - Phase-Aware Description (single source of truth)

    /// Human-readable description of the current learning focus.
    /// Used by CTA card, session results, and next-session recommendation.
    func currentFocusDescription(using scores: [MasteryScore]) -> String {
        let phase = phaseManager.currentPhase

        if phaseManager.isInDiagnosticMode {
            return "Diagnostic — mapping your fretboard knowledge"
        }

        if phaseManager.isInConfirmationMode {
            if let target = phaseManager.currentTargetString {
                return "Confirmation — verifying \(Self.stringName(target)) string"
            }
            return "Confirmation session"
        }

        if isStruggling {
            return strugglingDescription(using: scores)
        }

        switch phase {
        case .foundation:
            guard let target = phaseManager.currentTargetString else {
                return "Foundation — natural notes"
            }
            let progress = phaseManager.currentStringProgress(using: scores)
            let stringName = Self.stringName(target)
            if let p = progress {
                return "\(stringName) String Natural Notes — \(p.mastered) of \(p.total) mastered"
            }
            return "\(stringName) String Natural Notes"

        case .connection:
            let completed = phaseManager.phaseOneCompletedStrings.count
            return "Cross-String Patterns — \(completed) of 6 strings ready"

        case .expansion:
            return "Sharps & Flats — expanding your vocabulary"

        case .fluency:
            return "Full Fretboard Fluency — all notes, all strings"
        }
    }

    // MARK: - Struggling User Detection

    /// Whether the user is currently flagged as struggling.
    var isStruggling: Bool {
        UserDefaults.standard.bool(forKey: Self.isStrugglingKey)
    }

    /// Call after each session to track struggling state.
    func recordSessionPerformance(accuracy: Double) {
        var consecutivePoor = UserDefaults.standard.integer(forKey: Self.consecutiveAccuracyKey)

        if accuracy < Self.strugglingAccuracyThreshold {
            consecutivePoor += 1
        } else {
            // Good session — count toward recovery
            if isStruggling {
                consecutivePoor = max(0, consecutivePoor - 1)
                if consecutivePoor <= 0 {
                    UserDefaults.standard.set(false, forKey: Self.isStrugglingKey)
                    logger.info("User recovered from struggling state")
                }
            } else {
                consecutivePoor = 0
            }
        }

        UserDefaults.standard.set(consecutivePoor, forKey: Self.consecutiveAccuracyKey)

        if consecutivePoor >= Self.strugglingSessionThreshold && !isStruggling {
            UserDefaults.standard.set(true, forKey: Self.isStrugglingKey)
            logger.info("User flagged as struggling after \(consecutivePoor) poor sessions")
        }
    }

    // MARK: - Phase-Aware Session Building

    private func buildPhaseSession(using scores: [MasteryScore]) throws -> Session {
        let phase = phaseManager.currentPhase

        switch phase {
        case .foundation:
            return buildFoundationSession(using: scores)

        case .connection:
            return buildConnectionSession(using: scores)

        case .expansion:
            return buildExpansionSession(using: scores)

        case .fluency:
            return buildFluencySession(using: scores)
        }
    }

    private func buildFoundationSession(using scores: [MasteryScore]) -> Session {
        guard let targetString = phaseManager.currentTargetString else {
            // currentTargetString is nil — pick the weakest free-tier string
            let fallbackString = Self.weakestString(from: scores, strings: Self.freeStrings)
            logger.warning("Foundation session with nil targetString — using weakest string \(fallbackString)")
            return Session(
                focusMode: .naturalNotes,
                gameMode: .untimed,
                fretRangeStart: Self.freeFretStart,
                fretRangeEnd: Self.freeFretEnd,
                targetStrings: [fallbackString],
                isAdaptive: true
            )
        }

        // Use NoteGroupingEngine for musically meaningful groups
        let groups = groupingEngine.scaleFragments(
            onString: targetString,
            fretStart: Self.freeFretStart,
            fretEnd: Self.freeFretEnd,
            scores: scores,
            groupCount: 2
        )

        // Build review targets from stuck notes
        let reviewTargets = phaseManager.stuckNotes.prefix(2).compactMap { stuck -> NoteTarget? in
            guard let note = MusicalNote(rawValue: stuck.noteRaw) else { return nil }
            // Find fret position for this note on its string
            for fret in Self.freeFretStart...Self.freeFretEnd {
                if fretboardMap.note(string: stuck.stringNumber, fret: fret) == note {
                    return NoteTarget(note: note, string: stuck.stringNumber, fret: fret)
                }
            }
            return nil
        }

        // If struggling, mix in prior-phase drills (same string but easier)
        let plan = groupingEngine.buildSessionPlan(
            groups: groups,
            sessionLength: 10,
            scores: scores,
            reviewTargets: reviewTargets
        )

        // Create session targeting this specific string with natural notes
        let session = Session(
            focusMode: .naturalNotes,
            gameMode: .untimed,
            fretRangeStart: Self.freeFretStart,
            fretRangeEnd: Self.freeFretEnd,
            targetStrings: [targetString],
            isAdaptive: true
        )

        // Store the session plan for use by QuizViewModel (via the session plan)
        lastSessionPlan = plan

        return session
    }

    private func buildConnectionSession(using scores: [MasteryScore]) -> Session {
        let completedStrings = Array(phaseManager.phaseOneCompletedStrings)
        let targetStrings = completedStrings.isEmpty ? Self.freeStrings : completedStrings

        // Generate triad groups across mastered strings
        let groups = groupingEngine.triadGroups(
            strings: targetStrings,
            scores: scores,
            fretStart: Self.freeFretStart,
            fretEnd: Self.freeFretEnd,
            groupCount: 2
        )

        let plan = groupingEngine.buildSessionPlan(
            groups: groups,
            sessionLength: 10,
            scores: scores
        )

        lastSessionPlan = plan

        return Session(
            focusMode: .naturalNotes,
            gameMode: .untimed,
            fretRangeStart: Self.freeFretStart,
            fretRangeEnd: Self.freeFretEnd,
            targetStrings: targetStrings,
            isAdaptive: true
        )
    }

    private func buildExpansionSession(using scores: [MasteryScore]) -> Session {
        // Sharps & flats on the weakest string
        let weakest = Self.weakestString(from: scores, strings: Self.freeStrings)

        return Session(
            focusMode: .sharpsAndFlats,
            gameMode: .untimed,
            fretRangeStart: Self.freeFretStart,
            fretRangeEnd: Self.freeFretEnd,
            targetStrings: [weakest],
            isAdaptive: true
        )
    }

    private func buildFluencySession(using scores: [MasteryScore]) -> Session {
        // Full fretboard with chord-tone patterns
        let progression: [(root: MusicalNote, quality: TriadQuality)] = [
            (.c, .major), (.f, .major), (.g, .major)
        ]
        let groups = groupingEngine.chordToneGroups(
            progression: progression,
            strings: Array(1...6),
            fretStart: Self.freeFretStart,
            fretEnd: Self.freeFretEnd
        )

        let plan = groupingEngine.buildSessionPlan(
            groups: groups,
            sessionLength: 10,
            scores: scores
        )

        lastSessionPlan = plan

        return Session(
            focusMode: .fullFretboard,
            gameMode: .untimed,
            fretRangeStart: Self.freeFretStart,
            fretRangeEnd: Self.freeFretEnd,
            isAdaptive: true
        )
    }

    // MARK: - Review Sessions

    /// Check if the user needs a review session (e.g. returning after absence).
    private func needsReviewSession(using scores: [MasteryScore]) -> Bool {
        guard phaseManager.currentPhase.rawValue >= LearningPhase.connection.rawValue else {
            return false
        }

        // Check if any completed Phase 1 strings have decayed below threshold
        for string in phaseManager.phaseOneCompletedStrings {
            let naturalCells = phaseManager.naturalNoteCells(onString: string)
            for (note, _) in naturalCells {
                let cellScore = scores.first(where: {
                    $0.noteRaw == note.rawValue && $0.stringNumber == string
                })
                if let score = cellScore, score.score < LearningPhaseManager.advancementThreshold {
                    // Check if it's been a while since last practice
                    if let lastDate = score.lastAttemptDate,
                       Date().timeIntervalSince(lastDate) > 3 * 24 * 3600 { // 3+ days
                        return true
                    }
                }
            }
        }
        return false
    }

    /// Build a review session targeting decayed cells.
    private func buildReviewSession(using scores: [MasteryScore]) -> Session {
        // Find the most decayed string
        var weakestString = Self.freeStrings.first ?? 6
        var lowestAvg = Double.infinity
        for string in phaseManager.phaseOneCompletedStrings {
            let naturalCells = phaseManager.naturalNoteCells(onString: string)
            let cellScores = naturalCells.compactMap { cell in
                scores.first(where: { $0.noteRaw == cell.note.rawValue && $0.stringNumber == string })?.score
            }
            let avg = cellScores.isEmpty ? 0.5 : cellScores.reduce(0, +) / Double(cellScores.count)
            if avg < lowestAvg {
                lowestAvg = avg
                weakestString = string
            }
        }

        return Session(
            focusMode: .naturalNotes,
            gameMode: .untimed,
            fretRangeStart: Self.freeFretStart,
            fretRangeEnd: Self.freeFretEnd,
            targetStrings: [weakestString],
            isAdaptive: true
        )
    }

    // MARK: - Session Plan Storage

    /// The last generated session plan (for QuizViewModel to consume).
    var lastSessionPlan: SessionPlan?

    // MARK: - Phase Context for UI

    /// Returns a proximity message when the user is close to advancing, or nil.
    func phaseProximityMessage() throws -> String? {
        let scores = try masteryRepository.allScores()
        let phase = phaseManager.currentPhase

        switch phase {
        case .foundation:
            guard let target = phaseManager.currentTargetString else { return nil }
            let progress = phaseManager.currentStringProgress(using: scores)
            guard let p = progress else { return nil }
            let remaining = p.total - p.mastered
            if remaining <= 2 && remaining > 0 {
                let stringsCompleted = phaseManager.phaseOneCompletedStrings.count
                let stringsNeeded = LearningPhaseManager.stringsRequiredForPhase2
                if stringsCompleted == stringsNeeded - 1 {
                    return "\(remaining) more note\(remaining == 1 ? "" : "s") and you unlock Phase 2!"
                }
                let stringName = Self.stringName(target)
                return "\(remaining) more note\(remaining == 1 ? "" : "s") on the \(stringName) string!"
            }
            return nil

        case .connection:
            // Count strings with all natural notes mastered
            var fullyMastered = 0
            for string in 1...6 {
                let cells = phaseManager.naturalNoteCells(onString: string)
                let allPassed = cells.allSatisfy { cell in
                    let s = scores.first(where: { $0.noteRaw == cell.note.rawValue && $0.stringNumber == string })
                    return (s?.totalAttempts ?? 0) >= 3 && (s?.effectiveScore ?? 0) >= 0.75
                }
                if allPassed { fullyMastered += 1 }
            }
            let remaining = 6 - fullyMastered
            if remaining <= 2 && remaining > 0 {
                return "\(remaining) more string\(remaining == 1 ? "" : "s") to Phase 3!"
            }
            return nil

        case .expansion, .fluency:
            return nil
        }
    }

    /// Returns musical context summary from the last session plan's note groups.
    func musicalContextSummary(sessionCount: Int) -> (headline: String, body: String)? {
        guard let plan = lastSessionPlan, let firstGroup = plan.groups.first else { return nil }
        let context = firstGroup.context
        let noteNames = firstGroup.targets.map { $0.note.sharpName }
        let stringNumbers = Set(firstGroup.targets.map(\.string))
        let stringName: String? = stringNumbers.count == 1
            ? Self.stringName(stringNumbers.first!)
            : stringNumbers.sorted().map { Self.stringName($0) }.joined(separator: " and ")

        let frets = firstGroup.targets.map(\.fret)
        let body = PhaseInsightLibrary.musicalContextMessage(
            from: context,
            noteNames: noteNames,
            sessionCount: sessionCount,
            stringName: stringName,
            fretStart: frets.min(),
            fretEnd: frets.max()
        )

        return (headline: context.description, body: body)
    }

    /// Returns the phase info for display on the CTA card.
    /// NOTE: This is read-only — does NOT call evaluateAdvancement().
    /// Advancement is evaluated in nextSession() and QuizView.loadPhaseContext().
    func phaseDisplayInfo() throws -> (phaseName: String, phaseNumber: Int, target: String, progress: String?, proximity: String?) {
        let scores = try masteryRepository.allScores()
        let phase = phaseManager.currentPhase
        let phaseName = phase.displayName
        let phaseNumber = phase.rawValue

        let target: String
        let progress: String?

        switch phase {
        case .foundation:
            if let ts = phaseManager.currentTargetString {
                let stringName = Self.stringName(ts)
                target = "\(stringName) String Natural Notes"
                if let p = phaseManager.currentStringProgress(using: scores) {
                    progress = "\(p.mastered) of \(p.total) mastered"
                } else {
                    progress = nil
                }
            } else {
                target = "Natural Notes"
                progress = nil
            }
        case .connection:
            target = "Cross-String Patterns"
            let completed = phaseManager.phaseOneCompletedStrings.count
            progress = "\(completed) of 6 strings ready"
        case .expansion:
            target = "Sharps & Flats"
            progress = nil
        case .fluency:
            target = "Full Fretboard"
            progress = nil
        }

        let proximity = try? phaseProximityMessage()

        return (phaseName, phaseNumber, target, progress, proximity)
    }

    // MARK: - Struggling Description

    private func strugglingDescription(using scores: [MasteryScore]) -> String {
        switch phaseManager.currentPhase {
        case .foundation:
            if let target = phaseManager.currentTargetString {
                return "Shoring up the \(Self.stringName(target)) string"
            }
            return "Reinforcing your foundation"
        case .connection:
            let weakest = Self.weakestString(from: scores, strings: Self.freeStrings)
            return "Shoring up the \(Self.stringName(weakest)) string before cross-string work"
        case .expansion:
            return "Reviewing natural notes before adding sharps and flats"
        case .fluency:
            return "Warming up with focused drills"
        }
    }

    // MARK: - Static Helpers

    static func weakestString(from scores: [MasteryScore], strings: [Int]) -> Int {
        var stringAvgs: [(string: Int, avg: Double)] = []
        for s in strings {
            let relevant = scores.filter { $0.stringNumber == s }
            if relevant.isEmpty {
                stringAvgs.append((s, 0.50))
            } else {
                let avg = relevant.map(\.score).reduce(0, +) / Double(relevant.count)
                stringAvgs.append((s, avg))
            }
        }
        return stringAvgs.min(by: { $0.avg < $1.avg })?.string ?? strings.first ?? 6
    }

    static func weakestNote(
        from scores: [MasteryScore],
        fretboardMap: FretboardMap,
        strings: [Int],
        fretEnd: Int
    ) -> MusicalNote {
        var noteScores: [MusicalNote: [Double]] = [:]
        for string in strings {
            guard let fretMap = fretboardMap.map[string] else { continue }
            for fret in 0...fretEnd {
                guard let note = fretMap[fret] else { continue }
                let score = scores.first(where: {
                    $0.noteRaw == note.rawValue && $0.stringNumber == string
                })?.score ?? 0.50
                noteScores[note, default: []].append(score)
            }
        }
        let weakest = noteScores.min(by: { a, b in
            let avgA = a.value.reduce(0, +) / Double(a.value.count)
            let avgB = b.value.reduce(0, +) / Double(b.value.count)
            return avgA < avgB
        })
        return weakest?.key ?? .e
    }

    static func stringOrdinal(_ string: Int) -> String {
        switch string {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(string)th"
        }
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
}
