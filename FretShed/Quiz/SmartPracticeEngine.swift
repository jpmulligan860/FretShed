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

    // Session constraints — gated by entitlement for free-tier users.
    private static let allStrings: [Int] = LearningPhaseManager.allStrings
    private static let freeStrings: [Int] = [4, 5, 6]
    static let sessionFretStart = 0
    static let sessionFretEnd = LearningPhaseManager.phaseRequiredFretEnd

    /// Strings available for this engine instance, respecting entitlement.
    var sessionStrings: [Int] { isPremium ? Self.allStrings : Self.freeStrings }
    private let isPremium: Bool

    // Fluency rotation
    private static let fluencyRotationKey = "smartPractice_fluencyRotationIndex"

    /// The 4 focus mode styles rotated through in Fluency phase.
    enum FluencyMode: Int, CaseIterable {
        case fullFretboard = 0
        case stringFocus   = 1
        case noteFocus     = 2
        case positionFocus = 3
    }

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
        phaseManager: LearningPhaseManager? = nil,
        isPremium: Bool = false
    ) {
        self.masteryRepository = masteryRepository
        self.sessionRepository = sessionRepository
        self.fretboardMap = fretboardMap
        self.phaseManager = phaseManager ?? LearningPhaseManager(fretboardMap: fretboardMap)
        self.groupingEngine = NoteGroupingEngine(fretboardMap: fretboardMap)
        self.isPremium = isPremium
    }

    // MARK: - Public API (preserved for PracticeHomeView compatibility)

    /// Returns the next Smart Practice session and a human-readable description.
    func nextSession() throws -> (session: Session, description: String) {
        let allScores = try masteryRepository.allScores()

        // Diagnostic mode: run a full-fretboard natural notes session to map knowledge,
        // then completeDiagnostic() will place the user on the weakest string.
        if phaseManager.isInDiagnosticMode {
            let description = currentFocusDescription(using: allScores)
            let session = Session(
                focusMode: .naturalNotes,
                gameMode: .untimed,
                fretRangeStart: Self.sessionFretStart,
                fretRangeEnd: LearningPhaseManager.phaseRequiredFretEnd,
                isAdaptive: true
            )
            // Complete diagnostic after building — next session will be phase-appropriate
            phaseManager.completeDiagnostic(using: allScores)
            return (session, description)
        }

        // Confirmation mode: run a session on the confirmation target string
        if phaseManager.isInConfirmationMode, let target = phaseManager.currentTargetString {
            let description = currentFocusDescription(using: allScores)
            let session = Session(
                focusMode: .naturalNotes,
                gameMode: .untimed,
                fretRangeStart: Self.sessionFretStart,
                fretRangeEnd: LearningPhaseManager.phaseRequiredFretEnd,
                targetStrings: [target],
                isAdaptive: true
            )
            return (session, description)
        }

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
        case .expansion:
            if let target = phaseManager.currentPhaseTwoTargetString {
                return "\(Self.stringName(target)) Sharps & Flats"
            }
            return "Sharps & Flats"
        case .connection: return "Cross-String"
        case .fluency:
            let index = UserDefaults.standard.integer(forKey: Self.fluencyRotationKey)
            switch FluencyMode(rawValue: index % FluencyMode.allCases.count) ?? .fullFretboard {
            case .fullFretboard:  return "Full Fretboard"
            case .stringFocus:    return "String Deep Dive"
            case .noteFocus:      return "Note Hunt"
            case .positionFocus:  return "Position Focus"
            }
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
        for string in sessionStrings {
            guard let fretMap = fretboardMap.map[string] else { continue }
            for fret in Self.sessionFretStart...Self.sessionFretEnd {
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
            fretRangeStart: Self.sessionFretStart,
            fretRangeEnd: Self.sessionFretEnd,
            isAdaptive: true
        )
        alternatives.append((fullSession, "Full Fretboard", "Cover all positions", "rectangle.grid.3x2.fill"))

        // Offer weakest string as alternative
        let weakest = Self.weakestString(from: allScores, strings: sessionStrings, fretboardMap: fretboardMap)
        let name = Self.stringName(weakest)
        let stringSession = Session(
            focusMode: .singleString,
            gameMode: .untimed,
            fretRangeStart: Self.sessionFretStart,
            fretRangeEnd: Self.sessionFretEnd,
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
                return "\(stringName) String Natural Notes — \(p.mastered) of \(p.total) proficient"
            }
            return "\(stringName) String Natural Notes"

        case .expansion:
            guard let target = phaseManager.currentPhaseTwoTargetString else {
                return "Sharps & Flats — expanding your vocabulary"
            }
            let progress = phaseManager.currentPhaseTwoStringProgress(using: scores)
            let stringName = Self.stringName(target)
            if let p = progress {
                return "\(stringName) String Sharps & Flats — \(p.mastered) of \(p.total) proficient"
            }
            return "\(stringName) String Sharps & Flats"

        case .connection:
            return "Cross-String Patterns — all notes, any key"

        case .fluency:
            let index = UserDefaults.standard.integer(forKey: Self.fluencyRotationKey)
            switch FluencyMode(rawValue: index % FluencyMode.allCases.count) ?? .fullFretboard {
            case .fullFretboard:
                return "Full Fretboard — all notes, all strings"
            case .stringFocus:
                let target = Self.weakestString(from: scores, strings: LearningPhaseManager.allStrings, fretboardMap: fretboardMap)
                return "\(Self.stringName(target)) String Deep Dive"
            case .noteFocus:
                let target = Self.weakestNote(from: scores, fretboardMap: fretboardMap, strings: LearningPhaseManager.allStrings, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)
                return "Find Every \(target.displayName(format: .sharps)) — Note Hunt"
            case .positionFocus:
                let (start, end) = weakestFretRange(from: scores, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)
                return "Frets \(start)–\(end) — Position Focus"
            }
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

        case .expansion:
            return buildExpansionSession(using: scores)

        case .connection:
            return buildConnectionSession(using: scores)

        case .fluency:
            return buildFluencySession(using: scores)
        }
    }

    private func buildFoundationSession(using scores: [MasteryScore]) -> Session {
        let fretEnd = LearningPhaseManager.phaseRequiredFretEnd

        guard let targetString = phaseManager.currentTargetString else {
            // currentTargetString is nil — pick the weakest string
            let allStrings = LearningPhaseManager.allStrings
            let fallbackString = Self.weakestString(from: scores, strings: allStrings, fretboardMap: fretboardMap)
            logger.warning("Foundation session with nil targetString — using weakest string \(fallbackString)")
            return Session(
                focusMode: .naturalNotes,
                gameMode: .untimed,
                fretRangeStart: Self.sessionFretStart,
                fretRangeEnd: fretEnd,
                targetStrings: [fallbackString],
                isAdaptive: true
            )
        }

        // Use NoteGroupingEngine for musically meaningful groups
        let groups = groupingEngine.scaleFragments(
            onString: targetString,
            fretStart: Self.sessionFretStart,
            fretEnd: fretEnd,
            scores: scores,
            groupCount: 2
        )

        // Build review targets from stuck notes
        let reviewTargets = phaseManager.stuckNotes.prefix(2).compactMap { stuck -> NoteTarget? in
            guard let note = MusicalNote(rawValue: stuck.noteRaw) else { return nil }
            for fret in Self.sessionFretStart...fretEnd {
                if fretboardMap.note(string: stuck.stringNumber, fret: fret) == note {
                    return NoteTarget(note: note, string: stuck.stringNumber, fret: fret)
                }
            }
            return nil
        }

        let plan = groupingEngine.buildSessionPlan(
            groups: groups,
            sessionLength: 10,
            scores: scores,
            reviewTargets: reviewTargets
        )

        let session = Session(
            focusMode: .naturalNotes,
            gameMode: .untimed,
            fretRangeStart: Self.sessionFretStart,
            fretRangeEnd: fretEnd,
            targetStrings: [targetString],
            isAdaptive: true
        )

        lastSessionPlan = plan
        return session
    }

    private func buildExpansionSession(using scores: [MasteryScore]) -> Session {
        let fretEnd = LearningPhaseManager.phaseRequiredFretEnd

        // Phase 2: Single-string sharps & flats — target the Phase 2 target string
        let targetString = phaseManager.currentPhaseTwoTargetString
            ?? Self.weakestString(from: scores, strings: LearningPhaseManager.allStrings, fretboardMap: fretboardMap)

        // Use chromatic fragment groups for musically meaningful practice
        let groups = groupingEngine.chromaticFragments(
            onString: targetString,
            fretStart: Self.sessionFretStart,
            fretEnd: fretEnd,
            scores: scores,
            groupCount: 2
        )

        let plan = groupingEngine.buildSessionPlan(
            groups: groups,
            sessionLength: 10,
            scores: scores
        )

        lastSessionPlan = plan

        return Session(
            focusMode: .sharpsAndFlats,
            gameMode: .untimed,
            fretRangeStart: Self.sessionFretStart,
            fretRangeEnd: fretEnd,
            targetStrings: [targetString],
            isAdaptive: true
        )
    }

    private func buildConnectionSession(using scores: [MasteryScore]) -> Session {
        let fretEnd = LearningPhaseManager.phaseRequiredFretEnd

        // Phase 3: Cross-string, all notes, any key — use all-root triads
        let groups = groupingEngine.triadGroups(
            strings: LearningPhaseManager.allStrings,
            scores: scores,
            fretStart: Self.sessionFretStart,
            fretEnd: fretEnd,
            groupCount: 2,
            useAllRoots: true
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
            fretRangeStart: Self.sessionFretStart,
            fretRangeEnd: fretEnd,
            isAdaptive: true
        )
    }

    private func buildFluencySession(using scores: [MasteryScore]) -> Session {
        let fretEnd = LearningPhaseManager.phaseRequiredFretEnd
        let mode = nextFluencyMode()

        switch mode {
        case .fullFretboard:
            return Session(
                focusMode: .fullFretboard,
                gameMode: .untimed,
                fretRangeStart: Self.sessionFretStart,
                fretRangeEnd: fretEnd,
                isAdaptive: true
            )

        case .stringFocus:
            let target = Self.weakestString(from: scores, strings: LearningPhaseManager.allStrings, fretboardMap: fretboardMap)
            return Session(
                focusMode: .singleString,
                gameMode: .untimed,
                fretRangeStart: Self.sessionFretStart,
                fretRangeEnd: fretEnd,
                targetStrings: [target],
                isAdaptive: true
            )

        case .noteFocus:
            let target = Self.weakestNote(from: scores, fretboardMap: fretboardMap, strings: LearningPhaseManager.allStrings, fretEnd: fretEnd)
            return Session(
                focusMode: .singleNote,
                gameMode: .untimed,
                fretRangeStart: Self.sessionFretStart,
                fretRangeEnd: fretEnd,
                targetNotes: [target],
                isAdaptive: true
            )

        case .positionFocus:
            let (start, end) = weakestFretRange(from: scores, fretEnd: fretEnd)
            return Session(
                focusMode: .fretboardPosition,
                gameMode: .untimed,
                fretRangeStart: start,
                fretRangeEnd: end,
                isAdaptive: true
            )
        }
    }

    /// Returns the next Fluency focus mode in rotation, advancing the index.
    private func nextFluencyMode() -> FluencyMode {
        let index = UserDefaults.standard.integer(forKey: Self.fluencyRotationKey)
        let mode = FluencyMode(rawValue: index % FluencyMode.allCases.count) ?? .fullFretboard
        UserDefaults.standard.set(index + 1, forKey: Self.fluencyRotationKey)
        return mode
    }

    /// Returns the 5-fret range with the weakest average scores.
    private func weakestFretRange(from scores: [MasteryScore], fretEnd: Int) -> (start: Int, end: Int) {
        let windowSize = 5
        var weakestStart = 0
        var weakestAvg = Double.infinity

        for start in 0...(max(fretEnd - windowSize, 0)) {
            let end = min(start + windowSize - 1, fretEnd)
            var total = 0.0
            var count = 0
            let prior = MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta)
            for string in 1...kStringCount {
                for fret in start...end {
                    guard let note = fretboardMap.note(string: string, fret: fret) else { continue }
                    let cellScore = scores.first(where: {
                        $0.noteRaw == note.rawValue && $0.stringNumber == string
                    })?.score ?? prior
                    total += cellScore
                    count += 1
                }
            }
            let avg = count > 0 ? total / Double(count) : prior
            if avg < weakestAvg {
                weakestAvg = avg
                weakestStart = start
            }
        }
        return (weakestStart, min(weakestStart + windowSize - 1, fretEnd))
    }

    // MARK: - Review Sessions

    /// Check if the user needs a review session (e.g. returning after absence).
    private func needsReviewSession(using scores: [MasteryScore]) -> Bool {
        guard phaseManager.currentPhase.rawValue >= LearningPhase.expansion.rawValue else {
            return false
        }

        // Check if any completed Phase 1 strings have decayed below threshold
        for string in phaseManager.phaseOneCompletedStrings {
            let naturalCells = phaseManager.naturalNoteCells(onString: string, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)
            for (note, _) in naturalCells {
                let cellScore = scores.first(where: {
                    $0.noteRaw == note.rawValue && $0.stringNumber == string
                })
                if let score = cellScore, score.score < LearningPhaseManager.advancementThreshold {
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
        let fretEnd = LearningPhaseManager.phaseRequiredFretEnd

        // Find the most decayed string
        var weakestString = 6
        var lowestAvg = Double.infinity
        for string in phaseManager.phaseOneCompletedStrings {
            let naturalCells = phaseManager.naturalNoteCells(onString: string, fretEnd: fretEnd)
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
            fretRangeStart: Self.sessionFretStart,
            fretRangeEnd: fretEnd,
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
        let totalStrings = LearningPhaseManager.allStrings.count

        switch phase {
        case .foundation:
            guard let target = phaseManager.currentTargetString else { return nil }
            let progress = phaseManager.currentStringProgress(using: scores)
            guard let p = progress else { return nil }
            let remaining = p.total - p.mastered
            if remaining <= 2 && remaining > 0 {
                let stringsCompleted = phaseManager.phaseOneCompletedStrings.count
                if stringsCompleted == totalStrings - 1 {
                    return "\(remaining) more note\(remaining == 1 ? "" : "s") and you unlock Phase 2!"
                }
                let stringName = Self.stringName(target)
                return "\(remaining) more note\(remaining == 1 ? "" : "s") on the \(stringName) string!"
            }
            return nil

        case .expansion:
            guard let target = phaseManager.currentPhaseTwoTargetString else { return nil }
            let progress = phaseManager.currentPhaseTwoStringProgress(using: scores)
            guard let p = progress else { return nil }
            let remaining = p.total - p.mastered
            if remaining <= 2 && remaining > 0 {
                let stringsCompleted = phaseManager.phaseTwoCompletedStrings.count
                if stringsCompleted == totalStrings - 1 {
                    return "\(remaining) more note\(remaining == 1 ? "" : "s") and you unlock Phase 3!"
                }
                let stringName = Self.stringName(target)
                return "\(remaining) more note\(remaining == 1 ? "" : "s") on the \(stringName) string!"
            }
            return nil

        case .connection, .fluency:
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
                    progress = "\(p.mastered) of \(p.total) proficient"
                } else {
                    progress = nil
                }
            } else {
                target = "Natural Notes"
                progress = nil
            }
        case .expansion:
            if let ts = phaseManager.currentPhaseTwoTargetString {
                let stringName = Self.stringName(ts)
                target = "\(stringName) String Sharps & Flats"
                if let p = phaseManager.currentPhaseTwoStringProgress(using: scores) {
                    progress = "\(p.mastered) of \(p.total) proficient"
                } else {
                    progress = nil
                }
            } else {
                target = "Sharps & Flats"
                progress = nil
            }
        case .connection:
            target = "Cross-String Patterns"
            progress = "All notes, any key"
        case .fluency:
            let index = UserDefaults.standard.integer(forKey: Self.fluencyRotationKey)
            switch FluencyMode(rawValue: index % FluencyMode.allCases.count) ?? .fullFretboard {
            case .fullFretboard:  target = "Full Fretboard"
            case .stringFocus:    target = "String Deep Dive"
            case .noteFocus:      target = "Note Hunt"
            case .positionFocus:  target = "Position Focus"
            }
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
        case .expansion:
            return "Reviewing natural notes before adding sharps and flats"
        case .connection:
            let weakest = Self.weakestString(from: scores, strings: LearningPhaseManager.allStrings, fretboardMap: fretboardMap)
            return "Shoring up the \(Self.stringName(weakest)) string before cross-string work"
        case .fluency:
            return "Warming up with focused drills"
        }
    }

    // MARK: - Static Helpers

    /// Returns the weakest string by averaging attempted cell scores AND treating
    /// untried cells as the Bayesian prior (0.667). This prevents strings with few
    /// attempts from appearing "strong" when most of their cells are uncharted.
    static func weakestString(from scores: [MasteryScore], strings: [Int], fretboardMap: FretboardMap? = nil) -> Int {
        let fretEnd = LearningPhaseManager.phaseRequiredFretEnd
        var stringAvgs: [(string: Int, avg: Double)] = []
        for s in strings {
            let attempted = scores.filter { $0.stringNumber == s }
            if attempted.isEmpty {
                stringAvgs.append((s, 0.50))
            } else {
                // Count total positions on this string (frets 0-12, deduplicated by note)
                var totalPositions = 12 // reasonable default
                if let map = fretboardMap {
                    var seen: Set<Int> = []
                    for fret in 0...fretEnd {
                        if let note = map.note(string: s, fret: fret), !seen.contains(note.rawValue) {
                            seen.insert(note.rawValue)
                        }
                    }
                    totalPositions = max(seen.count, 1)
                }
                // Average attempted cells, treating untried as prior (0.667)
                let prior = MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta)
                let attemptedSum = attempted.map(\.score).reduce(0, +)
                let untriedCount = max(totalPositions - attempted.count, 0)
                let totalSum = attemptedSum + Double(untriedCount) * prior
                let avg = totalSum / Double(totalPositions)
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
