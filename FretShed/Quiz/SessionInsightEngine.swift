// SessionInsightEngine.swift
// FretShed — Quiz Layer
//
// Generates pedagogically grounded insight cards from existing SwiftData.
// Pure algorithmic logic — no network calls, no AI, no latency.

import Foundation

// MARK: - SessionInsightEngine

@MainActor
final class SessionInsightEngine {

    // MARK: - Free Tier

    // TODO: Phase 4 — wire to EntitlementManager
    private var isPremium: Bool {
        return false // conservative default: treat all users as free tier
    }

    /// User's preferred note name format, read from UserDefaults.
    private var noteFormat: NoteNameFormat {
        let raw = UserDefaults.standard.string(forKey: LocalUserPreferences.Key.noteNameFormat)
            ?? LocalUserPreferences.Default.noteNameFormat
        return NoteNameFormat(rawValue: raw) ?? .sharps
    }

    /// Display name for a note using the user's preferred format.
    private func noteName(_ note: MusicalNote) -> String {
        note.displayName(format: noteFormat)
    }

    // All strings and positions accessible — Phase 4 (EntitlementManager) will gate free tier.
    private static let allCellCount = 72 // 6 strings × 12 unique chromatic notes

    private var accessibleCellCount: Int {
        Self.allCellCount
    }

    private var accessibleStrings: Set<Int> {
        Set(1...6)
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lastInsightTypeSummary = "insight_lastType_summary"
        static let lastInsightTypeShed = "insight_lastType_shed"
        static let consecutiveWeaknessCountSummary = "insight_consecutiveWeakness_summary"
        static let firedMilestones = "insight_firedMilestones"
        static let hasShownRecalibrationMessage = "insight_hasShownRecalibration"
        static let hasShownFreeTierUpsell = "insight_hasShownFreeTierUpsell"
    }

    private func lastInsightTypeKey(for surface: InsightSurface) -> String {
        switch surface {
        case .summary: return Keys.lastInsightTypeSummary
        case .shed: return Keys.lastInsightTypeShed
        }
    }

    // MARK: - Entry Points

    /// Called from SessionSummaryView after session completes.
    func insightForSummary(
        session: Session,
        sessionAttempts: [Attempt],
        allSessions allSessionsNewestFirst: [Session],
        masteryScores: [MasteryScore],
        baselineLevel: BaselineLevel
    ) -> InsightCard {
        // allSessions from the repository is sorted newest-first (.reverse).
        // The insight engine expects oldest-first (chronological) throughout.
        let allSessions = allSessionsNewestFirst.reversed() as [Session]
        let sessionCount = allSessions.count
        let stage = computeMasteryStage(scores: masteryScores)
        let filteredScores = scoresForAccessibleStrings(masteryScores)
        let stringAccuracy = computeStringAccuracy(from: sessionAttempts)

        // Step 1 — Tier Transition (always wins if it occurred)
        let transitions = detectTierTransitions(
            sessionAttempts: sessionAttempts,
            currentScores: filteredScores
        )
        if let card = buildTierTransitionCard(transitions: transitions, sessionCount: sessionCount) {
            return applyTemporalAndFraming(
                card: card,
                session: session,
                allSessions: allSessions,
                sessionAttempts: sessionAttempts,
                stringAccuracy: stringAccuracy,
                sessionCount: sessionCount,
                stage: stage
            )
        }

        // Step 2 — Knowledge Shape Milestone
        if let card = buildKnowledgeShapeMilestone(
            scores: filteredScores,
            baselineLevel: baselineLevel,
            sessionCount: sessionCount
        ) {
            return applyTemporalAndFraming(
                card: card,
                session: session,
                allSessions: allSessions,
                sessionAttempts: sessionAttempts,
                stringAccuracy: stringAccuracy,
                sessionCount: sessionCount,
                stage: stage
            )
        }

        // Step 3 — Select by rotation + salience
        let card = selectBestInsight(
            surface: .summary,
            session: session,
            sessionAttempts: sessionAttempts,
            allSessions: allSessions,
            scores: filteredScores,
            stringAccuracy: stringAccuracy,
            sessionCount: sessionCount,
            stage: stage
        )

        return applyTemporalAndFraming(
            card: card,
            session: session,
            allSessions: allSessions,
            sessionAttempts: sessionAttempts,
            stringAccuracy: stringAccuracy,
            sessionCount: sessionCount,
            stage: stage
        )
    }

    /// Called from PracticeHomeView on appear.
    func insightForShed(
        allSessions allSessionsNewestFirst: [Session],
        masteryScores: [MasteryScore],
        baselineLevel: BaselineLevel
    ) -> InsightCard? {
        let allSessions = allSessionsNewestFirst.reversed() as [Session]
        let sessionCount = allSessions.count
        guard sessionCount > 0 else { return nil }

        let daysSinceLastSession = self.daysSinceLastSession(allSessions: allSessions)
        guard shouldShowShedInsight(sessionCount: sessionCount, daysSinceLastSession: daysSinceLastSession) else {
            return nil
        }

        let filteredScores = scoresForAccessibleStrings(masteryScores)

        // Forward-looking: pick the most relevant prompt
        var headline: String
        var body: String?
        var type: InsightType = .weakString

        // Find weakest string for forward prompt
        let weakString = findWeakestString(scores: filteredScores)
        let stringName = stringDisplayName(weakString)

        let shedPhrase = InsightPhraseLibrary.phrase(
            from: InsightPhraseLibrary.shedWeakStringPhrases,
            sessionCount: sessionCount
        ).replacingOccurrences(of: "[STRING]", with: stringName)
        headline = shedPhrase

        // Continuity line from last session
        if let lastSession = allSessions.last {
            let lastWeakString = dominantStringFromSession(lastSession)
            if let last = lastWeakString {
                body = InsightPhraseLibrary.phrase(
                    from: InsightPhraseLibrary.continuityLinePhrases,
                    sessionCount: sessionCount
                ).replacingOccurrences(of: "[STRING]", with: stringDisplayName(last))
            }
        }

        // Free tier upsell (once, after session 5)
        if !isPremium && sessionCount >= 5
            && !UserDefaults.standard.bool(forKey: Keys.hasShownFreeTierUpsell) {
            body = InsightPhraseLibrary.freeTierUpsellMessage
            UserDefaults.standard.set(true, forKey: Keys.hasShownFreeTierUpsell)
        }

        // Rotation: don't repeat same type
        let lastType = UserDefaults.standard.string(forKey: Keys.lastInsightTypeShed)
        if type.rawValue == lastType {
            headline = InsightPhraseLibrary.phrase(
                from: InsightPhraseLibrary.shedGenericPrompts,
                sessionCount: sessionCount
            )
            type = .coverage // Use coverage as the generic alternate (positive type)
        }
        UserDefaults.standard.set(type.rawValue, forKey: Keys.lastInsightTypeShed)

        return InsightCard(
            type: type,
            headline: headline,
            body: body,
            isPositive: false,
            isMilestone: false
        )
    }

    /// Controls whether the Shed page shows an insight card.
    func shouldShowShedInsight(sessionCount: Int, daysSinceLastSession: Int) -> Bool {
        if sessionCount < 5 { return true }
        if daysSinceLastSession >= 3 { return true }
        return sessionCount % 4 != 0
    }

    // MARK: - Tier Transition Detection

    func detectTierTransitions(
        sessionAttempts: [Attempt],
        currentScores: [MasteryScore]
    ) -> [TierTransition] {
        // Group attempts by CellKey
        var cellAttempts: [CellKey: (total: Int, correct: Int)] = [:]
        for attempt in sessionAttempts {
            guard accessibleStrings.contains(attempt.targetString) else { continue }
            let key = CellKey(noteRaw: attempt.targetNoteRaw, string: attempt.targetString)
            var current = cellAttempts[key] ?? (total: 0, correct: 0)
            current.total += 1
            if attempt.wasCorrect { current.correct += 1 }
            cellAttempts[key] = current
        }

        var transitions: [TierTransition] = []
        for (key, counts) in cellAttempts {
            guard let score = currentScores.first(where: {
                $0.noteRaw == key.noteRaw && $0.stringNumber == key.string
            }) else { continue }

            // Current tier
            let currentTier = MasteryLevel.from(score: score.score, isMastered: score.isMastered, totalAttempts: score.totalAttempts)

            // Pre-session score
            let preTotalAttempts = score.totalAttempts - counts.total
            let preCorrectAttempts = score.correctAttempts - counts.correct
            guard preTotalAttempts >= 0, preCorrectAttempts >= 0 else { continue }

            let preScore = MasteryCalculator.score(correct: preCorrectAttempts, total: preTotalAttempts)
            let preIsMastered = preScore >= MasteryScore.masteredThreshold
                && score.hasCompletedSpacingGate
            let preTier = MasteryLevel.from(score: preScore, isMastered: preIsMastered, totalAttempts: preTotalAttempts)

            if currentTier > preTier {
                transitions.append(TierTransition(
                    note: MusicalNote(rawValue: key.noteRaw) ?? .c,
                    string: key.string,
                    oldTier: preTier,
                    newTier: currentTier,
                    totalAttempts: score.totalAttempts
                ))
            }
        }

        return transitions.sorted { $0.newTier > $1.newTier }
    }

    // MARK: - Knowledge Shape Milestone

    private func buildKnowledgeShapeMilestone(
        scores: [MasteryScore],
        baselineLevel: BaselineLevel,
        sessionCount: Int
    ) -> InsightCard? {
        let fired = Set(UserDefaults.standard.stringArray(forKey: Keys.firedMilestones) ?? [])
        let milestoneKey = baselineLevel.rawValue

        guard !fired.contains(milestoneKey) else { return nil }

        let triggered: Bool
        switch baselineLevel {
        case .startingFresh:
            let attempted = scores.filter { $0.totalAttempts > 0 }.count
            triggered = attempted >= 20
        case .chordPlayer:
            let learningPlus = scores.filter {
                MasteryLevel.from(score: $0.score, isMastered: $0.isMastered) >= .learning
                && $0.totalAttempts >= 3
            }
            triggered = learningPlus.count >= 10
        case .openPosition:
            let midNeckScores = scores.filter { $0.totalAttempts >= 3 }
            let avgScore = midNeckScores.isEmpty ? 0.0 :
                midNeckScores.reduce(0.0) { $0 + $1.score } / Double(midNeckScores.count)
            triggered = avgScore >= 0.50 && midNeckScores.count >= 12
        case .lowStringsSolid:
            let dStringLearning = scores.filter {
                $0.stringNumber == 4
                && MasteryLevel.from(score: $0.score, isMastered: $0.isMastered) >= .learning
            }.count
            let gStringLearning = scores.filter {
                $0.stringNumber == 3
                && MasteryLevel.from(score: $0.score, isMastered: $0.isMastered) >= .learning
            }.count
            triggered = dStringLearning >= 3 || gStringLearning >= 3
        case .rustyEverywhere:
            let attemptedScores = scores.filter { $0.totalAttempts > 0 }
            guard attemptedScores.count >= 10 else { triggered = false; break }
            let values = attemptedScores.map(\.score)
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
            triggered = variance < 0.0625 // 0.25^2
        }

        guard triggered else { return nil }

        // Mark as fired
        var updated = fired
        updated.insert(milestoneKey)
        UserDefaults.standard.set(Array(updated), forKey: Keys.firedMilestones)

        let phrase = InsightPhraseLibrary.phrase(
            from: InsightPhraseLibrary.knowledgeShapeMilestonePhrases,
            sessionCount: sessionCount
        )

        return InsightCard(
            type: .knowledgeShapeMilestone,
            headline: phrase,
            body: nil,
            isPositive: true,
            isMilestone: true
        )
    }

    // MARK: - Best Insight Selection

    private func selectBestInsight(
        surface: InsightSurface,
        session: Session,
        sessionAttempts: [Attempt],
        allSessions: [Session],
        scores: [MasteryScore],
        stringAccuracy: [Int: Double],
        sessionCount: Int,
        stage: MasteryStage
    ) -> InsightCard {
        let lastTypeRaw = UserDefaults.standard.string(forKey: lastInsightTypeKey(for: surface))
        let consecutiveWeakness = UserDefaults.standard.integer(forKey: Keys.consecutiveWeaknessCountSummary)

        // Force positive after 4 consecutive weakness types
        let mustBePositive = consecutiveWeakness >= 4

        // Build candidate insights with salience scores
        var candidates: [(type: InsightType, salience: Double, card: InsightCard)] = []

        // Session delta
        if let delta = buildSessionDelta(session: session, allSessions: allSessions, sessionCount: sessionCount) {
            if !mustBePositive || delta.1.isPositive {
                candidates.append((type: .sessionDelta, salience: abs(delta.0), card: delta.1))
            }
        }

        // Weak string (uses pre-computed stringAccuracy)
        if !mustBePositive, let card = buildWeakStringCard(stringAccuracy: stringAccuracy, sessionCount: sessionCount) {
            candidates.append((type: .weakString, salience: card.1, card: card.0))
        }

        // Strong string (uses pre-computed stringAccuracy)
        if let card = buildStrongStringCard(stringAccuracy: stringAccuracy, sessionCount: sessionCount) {
            candidates.append((type: .strongString, salience: card.1, card: card.0))
        }

        // Hardest note — only consider notes actually tested in this session
        let sessionNoteKeys = Set(sessionAttempts.map { "\($0.targetNoteRaw)-\($0.targetString)" })
        let sessionRelevantScores = scores.filter {
            sessionNoteKeys.contains("\($0.noteRaw)-\($0.stringNumber)")
        }
        if !mustBePositive, let card = buildHardestNoteCard(scores: sessionRelevantScores, sessionCount: sessionCount) {
            candidates.append((type: .hardestNote, salience: card.1, card: card.0))
        }

        // Close to level up — only session-relevant notes
        if !mustBePositive, let card = buildCloseToLevelUpCard(scores: sessionRelevantScores, sessionCount: sessionCount) {
            candidates.append((type: .closeToLevelUp, salience: card.1, card: card.0))
        }

        // Cold spot — only session-relevant notes
        if !mustBePositive, let card = buildColdSpotCard(scores: sessionRelevantScores, sessionCount: sessionCount) {
            candidates.append((type: .coldSpot, salience: card.1, card: card.0))
        }

        // Coverage
        if let card = buildCoverageCard(sessionAttempts: sessionAttempts, scores: scores, sessionCount: sessionCount) {
            candidates.append((type: .coverage, salience: card.1, card: card.0))
        }

        // Consistency trend
        if let card = buildConsistencyCard(allSessions: allSessions, sessionCount: sessionCount) {
            if !mustBePositive || card.0.isPositive {
                candidates.append((type: .consistencyTrend, salience: card.1, card: card.0))
            }
        }

        // Filter: don't repeat last type
        let filtered = candidates.filter { $0.type.rawValue != lastTypeRaw }
        let pool = filtered.isEmpty ? candidates : filtered

        // Pick highest salience
        guard let best = pool.max(by: { $0.salience < $1.salience }) else {
            return fallbackCard(sessionCount: sessionCount)
        }

        // Update rotation state
        UserDefaults.standard.set(best.type.rawValue, forKey: lastInsightTypeKey(for: surface))

        // Update consecutive weakness counter
        if best.card.isPositive {
            UserDefaults.standard.set(0, forKey: Keys.consecutiveWeaknessCountSummary)
        } else {
            UserDefaults.standard.set(consecutiveWeakness + 1, forKey: Keys.consecutiveWeaknessCountSummary)
        }

        return best.card
    }

    // MARK: - Individual Insight Builders

    private func buildSessionDelta(
        session: Session,
        allSessions: [Session],
        sessionCount: Int
    ) -> (Double, InsightCard)? {
        guard allSessions.count >= 2 else { return nil }
        // allSessions is chronological (oldest-first), so second-to-last is the previous session
        let prevSession = allSessions[allSessions.count - 2]
        let delta = session.accuracyPercent - prevSession.accuracyPercent
        guard abs(delta) >= 3 else { return nil } // Only surface meaningful deltas

        let isPositive = delta > 0
        let phrases = isPositive
            ? InsightPhraseLibrary.sessionDeltaPositivePhrases
            : InsightPhraseLibrary.sessionDeltaNegativePhrases

        var headline = InsightPhraseLibrary.phrase(from: phrases, sessionCount: sessionCount)
        headline = headline
            .replacingOccurrences(of: "[DELTA]", with: "\(Int(abs(delta)))")
            .replacingOccurrences(of: "[ACCURACY]", with: "\(Int(session.accuracyPercent))")
            .replacingOccurrences(of: "[PREV]", with: "\(Int(prevSession.accuracyPercent))")

        // Best in N sessions — exclude the current session when comparing
        if isPositive {
            let priorSessions = allSessions.dropLast() // everything except the current session
            let recentPrior = priorSessions.suffix(6) // last 6 prior sessions (+ current = 7 window)
            let priorMax = recentPrior.map(\.accuracyPercent).max() ?? 0
            if session.accuracyPercent > priorMax && !recentPrior.isEmpty {
                // Strictly better than all prior sessions in the window
                headline = headline.replacingOccurrences(of: "[N]", with: "\(recentPrior.count + 1)")
            } else {
                // Not actually the best — remove the "best in N" claim
                headline = headline.replacingOccurrences(of: "Best accuracy in [N] sessions. ", with: "")
                headline = headline.replacingOccurrences(of: "[N]", with: "\(allSessions.count)")
            }
        }

        let card = InsightCard(
            type: .sessionDelta,
            headline: headline,
            body: nil,
            isPositive: isPositive,
            isMilestone: false
        )
        return (delta, card)
    }

    private func buildWeakStringCard(
        stringAccuracy: [Int: Double],
        sessionCount: Int
    ) -> (InsightCard, Double)? {
        guard let weakest = stringAccuracy.min(by: { $0.value < $1.value }),
              weakest.value < 80 else { return nil }

        var headline = InsightPhraseLibrary.phrase(
            from: InsightPhraseLibrary.weakStringPhrases,
            sessionCount: sessionCount
        )
        headline = headline
            .replacingOccurrences(of: "[STRING]", with: stringDisplayName(weakest.key))
            .replacingOccurrences(of: "[ACCURACY]", with: "\(Int(weakest.value))")
            .replacingOccurrences(of: "[RANGE]", with: "0–\(LearningPhaseManager.phaseRequiredFretEnd)")

        let salience = abs(50.0 - weakest.value)
        let card = InsightCard(
            type: .weakString,
            headline: headline,
            body: nil,
            isPositive: false,
            isMilestone: false
        )
        return (card, salience)
    }

    private func buildStrongStringCard(
        stringAccuracy: [Int: Double],
        sessionCount: Int
    ) -> (InsightCard, Double)? {
        guard let strongest = stringAccuracy.max(by: { $0.value < $1.value }),
              strongest.value >= 70 else { return nil }

        var headline = InsightPhraseLibrary.phrase(
            from: InsightPhraseLibrary.strongStringPhrases,
            sessionCount: sessionCount
        )
        headline = headline
            .replacingOccurrences(of: "[STRING]", with: stringDisplayName(strongest.key))
            .replacingOccurrences(of: "[ACCURACY]", with: "\(Int(strongest.value))")

        let salience = strongest.value - 70.0
        let card = InsightCard(
            type: .strongString,
            headline: headline,
            body: nil,
            isPositive: true,
            isMilestone: false
        )
        return (card, salience)
    }

    private func buildHardestNoteCard(
        scores: [MasteryScore],
        sessionCount: Int
    ) -> (InsightCard, Double)? {
        let attempted = scores.filter { $0.totalAttempts >= 3 }
        guard let worst = attempted.min(by: { $0.score < $1.score }),
              worst.score < 0.70 else { return nil }

        var headline = InsightPhraseLibrary.phrase(
            from: InsightPhraseLibrary.hardestNotePhrases,
            sessionCount: sessionCount
        )
        headline = headline
            .replacingOccurrences(of: "[NOTE]", with: worst.note.displayName(format: noteFormat))

        let body = InsightPhraseLibrary.normalisingClause(
            note: worst.note, string: worst.stringNumber, sessionCount: sessionCount
        )

        let salience = abs(0.50 - worst.score) * 100
        let card = InsightCard(
            type: .hardestNote,
            headline: headline,
            body: body,
            isPositive: false,
            isMilestone: false
        )
        return (card, salience)
    }

    private func buildCloseToLevelUpCard(
        scores: [MasteryScore],
        sessionCount: Int
    ) -> (InsightCard, Double)? {
        let closeToLearning = scores.filter {
            $0.score >= 0.40 && $0.score < 0.50 && $0.totalAttempts >= 3
        }
        let closeToProficient = scores.filter {
            $0.score >= 0.65 && $0.score < 0.75 && $0.totalAttempts >= 5
        }
        let closeToMastered = scores.filter {
            $0.score >= 0.75 && $0.totalAttempts >= 10 && $0.totalAttempts < 15
        }

        let allClose = closeToLearning + closeToProficient + closeToMastered
        guard !allClose.isEmpty else { return nil }

        var headline = InsightPhraseLibrary.phrase(
            from: InsightPhraseLibrary.closeToLevelUpPhrases,
            sessionCount: sessionCount
        )
        headline = headline
            .replacingOccurrences(of: "[COUNT]", with: "\(allClose.count)")

        if let first = allClose.first {
            headline = headline
                .replacingOccurrences(of: "[NOTE]", with: first.note.displayName(format: noteFormat))
                .replacingOccurrences(of: "[STRING]", with: stringDisplayName(first.stringNumber))
        }

        // Build body listing the specific notes
        let noteDescriptions = allClose.prefix(8).map { score in
            "\(noteName(score.note)) on string \(score.stringNumber)"
        }
        let body = noteDescriptions.joined(separator: ", ")

        // Collect unique target notes for the Next Up session
        let targetNotes = Array(Set(allClose.map(\.note)))

        let salience = Double(allClose.count) * 10.0
        let card = InsightCard(
            type: .closeToLevelUp,
            headline: headline,
            body: body,
            isPositive: false,
            isMilestone: false,
            targetNotes: targetNotes
        )
        return (card, salience)
    }

    private func buildColdSpotCard(
        scores: [MasteryScore],
        sessionCount: Int
    ) -> (InsightCard, Double)? {
        let coldSpots = scores.filter {
            $0.totalAttempts >= 10 && $0.score < 0.50
        }
        guard let worst = coldSpots.min(by: { $0.score < $1.score }) else { return nil }

        var headline = InsightPhraseLibrary.phrase(
            from: InsightPhraseLibrary.coldSpotPhrases,
            sessionCount: sessionCount
        )
        headline = headline
            .replacingOccurrences(of: "[NOTE]", with: worst.note.displayName(format: noteFormat))
            .replacingOccurrences(of: "[STRING]", with: stringDisplayName(worst.stringNumber))

        let body = InsightPhraseLibrary.normalisingClause(
            note: worst.note, string: worst.stringNumber, sessionCount: sessionCount
        )

        let salience = Double(worst.totalAttempts) * (0.50 - worst.score)
        let card = InsightCard(
            type: .coldSpot,
            headline: headline,
            body: body,
            isPositive: false,
            isMilestone: false
        )
        return (card, salience)
    }

    private func buildCoverageCard(
        sessionAttempts: [Attempt],
        scores: [MasteryScore],
        sessionCount: Int
    ) -> (InsightCard, Double)? {
        // Find cells attempted for the first time this session
        var sessionCellCounts: [CellKey: Int] = [:]
        for attempt in sessionAttempts {
            guard accessibleStrings.contains(attempt.targetString) else { continue }
            let key = CellKey(noteRaw: attempt.targetNoteRaw, string: attempt.targetString)
            sessionCellCounts[key, default: 0] += 1
        }

        var newCells: [(note: MusicalNote, string: Int)] = []
        for (key, count) in sessionCellCounts {
            if let score = scores.first(where: { $0.noteRaw == key.noteRaw && $0.stringNumber == key.string }) {
                if score.totalAttempts == count {
                    newCells.append((note: MusicalNote(rawValue: key.noteRaw) ?? .c, string: key.string))
                }
            }
        }

        guard !newCells.isEmpty else { return nil }

        // Phase-aware coverage: determine what kind of notes the user is working on
        let phase = LearningPhaseManager().currentPhase
        let noteTypeLabel: String
        let expectedCountPerString: Int
        switch phase {
        case .foundation:
            noteTypeLabel = "natural note"
            expectedCountPerString = 7 // ~7 unique naturals on frets 0-12
        case .expansion:
            noteTypeLabel = "accidental"
            expectedCountPerString = 5 // ~5 sharps/flats on frets 0-12
        case .connection, .fluency:
            noteTypeLabel = "note"
            expectedCountPerString = 12 // all 12 chromatic notes
        }

        // Filter out the "every [NOTE_TYPE]" phrase unless we can verify full coverage
        // for the relevant note type on at least one string
        var phrasePool = InsightPhraseLibrary.coveragePhrases
        if let everyPhrase = phrasePool.first, everyPhrase.contains("[NOTE_TYPE]") {
            let stringCounts = Dictionary(grouping: newCells, by: \.string)
            let hasFullCoverage = stringCounts.contains { (string, _) in
                let relevantAttempted = scores.filter {
                    $0.stringNumber == string && accessibleStrings.contains(string) && $0.totalAttempts > 0
                    && (phase == .foundation ? (MusicalNote(rawValue: $0.noteRaw)?.isNatural ?? false)
                        : phase == .expansion ? !(MusicalNote(rawValue: $0.noteRaw)?.isNatural ?? true)
                        : true)
                }.count
                return relevantAttempted >= expectedCountPerString
            }
            if !hasFullCoverage {
                phrasePool = Array(phrasePool.dropFirst())
                if phrasePool.isEmpty { phrasePool = InsightPhraseLibrary.coveragePhrases }
            }
        }

        var headline = InsightPhraseLibrary.phrase(
            from: phrasePool,
            sessionCount: sessionCount
        )
        headline = headline
            .replacingOccurrences(of: "[COUNT]", with: "\(newCells.count)")
            .replacingOccurrences(of: "[NOTE_TYPE]", with: noteTypeLabel)

        if let first = newCells.first {
            headline = headline
                .replacingOccurrences(of: "[NOTE]", with: first.note.displayName(format: noteFormat))
                .replacingOccurrences(of: "[STRING]", with: stringDisplayName(first.string))
        }

        let salience = Double(newCells.count) * 15.0
        let card = InsightCard(
            type: .coverage,
            headline: headline,
            body: nil,
            isPositive: true,
            isMilestone: false
        )
        return (card, salience)
    }

    private func buildConsistencyCard(
        allSessions: [Session],
        sessionCount: Int
    ) -> (InsightCard, Double)? {
        guard allSessions.count >= 3 else { return nil }
        let last3 = allSessions.suffix(3).map(\.accuracyPercent)
        let isImproving = last3[1] > last3[0] && last3[2] > last3[1]
        let isFlat = abs(last3[2] - last3[0]) < 5

        // Don't call consistently high accuracy a "plateau" — that's sustained
        // strong performance, not stagnation. Only flag flat when accuracy is
        // genuinely stuck below a strong threshold.
        let allHigh = last3.allSatisfy { $0 >= 80 }

        let phrases: [String]
        let isPositive: Bool
        if isImproving {
            phrases = InsightPhraseLibrary.consistencyTrendPositivePhrases
            isPositive = true
        } else if isFlat && !allHigh {
            phrases = InsightPhraseLibrary.consistencyTrendFlatPhrases
            isPositive = false
        } else {
            return nil // High + flat = good, or declining — let session delta handle it
        }

        let headline = InsightPhraseLibrary.phrase(from: phrases, sessionCount: sessionCount)
        let salience = isImproving ? (last3[2] - last3[0]) : 5.0
        let card = InsightCard(
            type: .consistencyTrend,
            headline: headline,
            body: nil,
            isPositive: isPositive,
            isMilestone: false
        )
        return (card, salience)
    }

    private func buildTierTransitionCard(
        transitions: [TierTransition],
        sessionCount: Int
    ) -> InsightCard? {
        guard !transitions.isEmpty else { return nil }

        var headline = InsightPhraseLibrary.phrase(
            from: InsightPhraseLibrary.tierTransitionPhrases,
            sessionCount: sessionCount
        )

        let first = transitions[0]
        headline = headline
            .replacingOccurrences(of: "[NOTE]", with: first.note.displayName(format: noteFormat))
            .replacingOccurrences(of: "[STRING]", with: stringDisplayName(first.string))
            .replacingOccurrences(of: "[TIER]", with: first.newTier.localizedLabel)
            .replacingOccurrences(of: "[COUNT]", with: "\(transitions.count)")
            .replacingOccurrences(of: "[ATTEMPTS]", with: "\(first.totalAttempts)")

        // Store in rotation (overrides normal rotation)
        UserDefaults.standard.set(InsightType.tierTransition.rawValue, forKey: Keys.lastInsightTypeSummary)
        // Reset weakness counter on a positive event
        UserDefaults.standard.set(0, forKey: Keys.consecutiveWeaknessCountSummary)

        let body: String?
        if transitions.count > 1 {
            let noteNames = transitions.map { $0.note.displayName(format: noteFormat) }
            body = "\(noteNames.joined(separator: ", ")) — \(transitions.count) notes promoted this session."
        } else {
            body = nil
        }

        return InsightCard(
            type: .tierTransition,
            headline: headline,
            body: body,
            isPositive: true,
            isMilestone: true
        )
    }

    // MARK: - Temporal & Framing Modifiers

    private func applyTemporalAndFraming(
        card: InsightCard,
        session: Session,
        allSessions: [Session],
        sessionAttempts: [Attempt],
        stringAccuracy: [Int: Double],
        sessionCount: Int,
        stage: MasteryStage
    ) -> InsightCard {
        let headline = card.headline
        var body = card.body

        // Struggling phase framing (sessions 1–8, exploring/consolidating stage)
        if sessionCount <= 8 && (stage == .exploring || stage == .consolidating) {
            let strugglingAttempts = sessionAttempts.filter { !$0.wasCorrect }.count
            let totalAttempts = sessionAttempts.count
            if totalAttempts > 0 && Double(strugglingAttempts) / Double(totalAttempts) > 0.50 {
                let framing = InsightPhraseLibrary.phrase(
                    from: InsightPhraseLibrary.strugglingFramingPhrases,
                    sessionCount: sessionCount
                )
                body = body.map { $0 + " " + framing } ?? framing
            }
        }

        // Session 3 recalibration message
        if sessionCount == 3 && !UserDefaults.standard.bool(forKey: Keys.hasShownRecalibrationMessage) {
            let recal = InsightPhraseLibrary.recalibrationMessage
            body = body.map { $0 + "\n\n" + recal } ?? recal
            UserDefaults.standard.set(true, forKey: Keys.hasShownRecalibrationMessage)
        }

        return InsightCard(
            type: card.type,
            headline: headline,
            body: body,
            isPositive: card.isPositive,
            isMilestone: card.isMilestone
        )
    }

    // MARK: - Helpers

    func computeMasteryStage(scores: [MasteryScore]) -> MasteryStage {
        let total = accessibleCellCount
        let attempted = scores.filter { $0.totalAttempts > 0 && accessibleStrings.contains($0.stringNumber) }.count
        let untriedFraction = Double(total - attempted) / Double(max(total, 1))

        if untriedFraction > 0.60 { return .exploring }

        let proficientPlus = scores.filter {
            accessibleStrings.contains($0.stringNumber)
            && MasteryLevel.from(score: $0.score, isMastered: $0.isMastered, totalAttempts: $0.totalAttempts) >= .proficient
        }.count

        if Double(proficientPlus) / Double(max(attempted, 1)) >= 0.40 {
            return .refining
        }
        return .consolidating
    }

    private func scoresForAccessibleStrings(_ scores: [MasteryScore]) -> [MasteryScore] {
        scores.filter { accessibleStrings.contains($0.stringNumber) }
    }

    private func computeStringAccuracy(from attempts: [Attempt]) -> [Int: Double] {
        var totals: [Int: (correct: Int, total: Int)] = [:]
        for attempt in attempts {
            guard accessibleStrings.contains(attempt.targetString) else { continue }
            var current = totals[attempt.targetString] ?? (correct: 0, total: 0)
            current.total += 1
            if attempt.wasCorrect { current.correct += 1 }
            totals[attempt.targetString] = current
        }
        // Require at least 3 attempts on a string for a meaningful accuracy reading
        return totals.compactMapValues { counts in
            counts.total >= 3 ? (Double(counts.correct) / Double(counts.total)) * 100 : nil
        }
    }

    private func findWeakestString(scores: [MasteryScore]) -> Int {
        var stringScores: [Int: [Double]] = [:]
        for score in scores where accessibleStrings.contains(score.stringNumber) {
            stringScores[score.stringNumber, default: []].append(score.score)
        }
        let averages = stringScores.mapValues { values in
            values.isEmpty ? 0.0 : values.reduce(0, +) / Double(values.count)
        }
        return averages.min(by: { $0.value < $1.value })?.key ?? 6
    }

    private func dominantStringFromSession(_ session: Session) -> Int? {
        if !session.targetStrings.isEmpty {
            return session.targetStrings.first
        }
        return nil
    }

    private func daysSinceLastSession(allSessions: [Session]) -> Int {
        guard let last = allSessions.last else { return 999 }
        let lastDate = last.endTime ?? last.startTime
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
    }

    private func stringDisplayName(_ string: Int) -> String {
        switch string {
        case 1: return "high E"
        case 2: return "B"
        case 3: return "G"
        case 4: return "D"
        case 5: return "A"
        case 6: return "low E"
        default: return "string \(string)"
        }
    }

    private func fallbackCard(sessionCount: Int) -> InsightCard {
        let headline = InsightPhraseLibrary.phrase(
            from: InsightPhraseLibrary.shedGenericPrompts,
            sessionCount: sessionCount
        )
        return InsightCard(
            type: .coverage,
            headline: headline,
            body: nil,
            isPositive: true,
            isMilestone: false
        )
    }
}
