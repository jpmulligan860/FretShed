// SessionInsightEngineTests.swift
// FretShed — Unit Tests
//
// Tests for SessionInsightEngine insight generation logic.

import XCTest
import SwiftData
@testable import FretShed

@MainActor
final class SessionInsightEngineTests: XCTestCase {

    var engine: SessionInsightEngine!

    override func setUp() async throws {
        try await super.setUp()
        engine = SessionInsightEngine()
        // Clear all insight-related UserDefaults keys
        let keys = [
            "insight_lastType_summary",
            "insight_lastType_shed",
            "insight_consecutiveWeakness_summary",
            "insight_firedMilestones",
            "insight_hasShownRecalibration",
            "insight_hasShownFreeTierUpsell",
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Tier Transition Detection

    func test_tierTransition_detectedWhenCellCrossesBoundary() throws {
        // A mastery score that just crossed from Struggling to Learning
        // Post: 5 correct out of 10 total → score = (5+2)/(10+3) = 0.538 (Learning)
        // Session had 3 attempts, 3 correct
        // Pre: 2 correct out of 7 → score = (2+2)/(7+3) = 0.40 → Struggling
        let score = MasteryScore(note: .a, stringNumber: 5)
        score.totalAttempts = 10
        score.correctAttempts = 5

        let attempts = (0..<3).map { _ in
            Attempt(
                targetNote: .a, targetString: 5, targetFret: 0,
                playedNote: .a, playedString: 5, responseTimeMs: 500,
                wasCorrect: true, sessionID: UUID(), gameMode: .untimed,
                acceptedAnyString: false
            )
        }

        let transitions = engine.detectTierTransitions(
            sessionAttempts: attempts,
            currentScores: [score]
        )

        XCTAssertEqual(transitions.count, 1)
        XCTAssertEqual(transitions.first?.note, .a)
        XCTAssertEqual(transitions.first?.string, 5)
        XCTAssertEqual(transitions.first?.oldTier, .struggling)
        XCTAssertEqual(transitions.first?.newTier, .learning)
    }

    func test_tierTransition_triggersInsightCard() throws {
        let score = MasteryScore(note: .d, stringNumber: 4)
        score.totalAttempts = 10
        score.correctAttempts = 5

        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, isAdaptive: true)
        session.attemptCount = 3
        session.correctCount = 3

        let attempts = (0..<3).map { _ in
            Attempt(
                targetNote: .d, targetString: 4, targetFret: 0,
                playedNote: .d, playedString: 4, responseTimeMs: 400,
                wasCorrect: true, sessionID: session.id, gameMode: .untimed,
                acceptedAnyString: false
            )
        }

        let card = engine.insightForSummary(
            session: session,
            sessionAttempts: attempts,
            allSessions: [session],
            masteryScores: [score],
            baselineLevel: .startingFresh
        )

        XCTAssertEqual(card.type, .tierTransition)
        XCTAssertTrue(card.isMilestone)
        XCTAssertTrue(card.isPositive)
    }

    // MARK: - Rotation Rule

    func test_rotationRule_sameTypeNeverTwiceInRow() throws {
        // Set last shown type to weakString
        UserDefaults.standard.set("weakString", forKey: "insight_lastType_summary")

        let score1 = MasteryScore(note: .e, stringNumber: 6)
        score1.totalAttempts = 10
        score1.correctAttempts = 3

        let score2 = MasteryScore(note: .a, stringNumber: 5)
        score2.totalAttempts = 10
        score2.correctAttempts = 8

        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, isAdaptive: true)
        session.attemptCount = 10
        session.correctCount = 5

        let attempts = [
            Attempt(targetNote: .e, targetString: 6, targetFret: 0,
                    playedNote: .a, playedString: 6, responseTimeMs: 500,
                    wasCorrect: false, sessionID: session.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: session,
            sessionAttempts: attempts,
            allSessions: [session],
            masteryScores: [score1, score2],
            baselineLevel: .startingFresh
        )

        // Should NOT be weakString since that was the last type shown
        XCTAssertNotEqual(card.type, .weakString)
    }

    // MARK: - Positivity Threshold

    func test_positivityThreshold_afterFourWeaknessTypes() throws {
        // Set consecutive weakness count to 4
        UserDefaults.standard.set(4, forKey: "insight_consecutiveWeakness_summary")

        let score = MasteryScore(note: .e, stringNumber: 6)
        score.totalAttempts = 10
        score.correctAttempts = 3

        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, isAdaptive: true)
        session.attemptCount = 5
        session.correctCount = 2

        let attempts = [
            Attempt(targetNote: .e, targetString: 6, targetFret: 0,
                    playedNote: .a, playedString: 6, responseTimeMs: 500,
                    wasCorrect: false, sessionID: session.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: session,
            sessionAttempts: attempts,
            allSessions: [session],
            masteryScores: [score],
            baselineLevel: .startingFresh
        )

        // After 4 consecutive weakness types, the card should be positive
        XCTAssertTrue(card.isPositive || card.type == .sessionDelta || card.type == .coverage
                      || card.type == .strongString || card.type == .tierTransition
                      || card.type == .consistencyTrend || card.type == .knowledgeShapeMilestone)
    }

    // MARK: - Shed Insight Fatigue

    func test_shouldShowShedInsight_falseOnEveryFourthRegularSession() {
        // First 5 sessions always show
        XCTAssertTrue(engine.shouldShowShedInsight(sessionCount: 1, daysSinceLastSession: 0))
        XCTAssertTrue(engine.shouldShowShedInsight(sessionCount: 4, daysSinceLastSession: 0))

        // After 5 sessions, every 4th is skipped
        XCTAssertFalse(engine.shouldShowShedInsight(sessionCount: 8, daysSinceLastSession: 0))
        XCTAssertTrue(engine.shouldShowShedInsight(sessionCount: 9, daysSinceLastSession: 0))
        XCTAssertTrue(engine.shouldShowShedInsight(sessionCount: 10, daysSinceLastSession: 0))
        XCTAssertTrue(engine.shouldShowShedInsight(sessionCount: 11, daysSinceLastSession: 0))
        XCTAssertFalse(engine.shouldShowShedInsight(sessionCount: 12, daysSinceLastSession: 0))

        // Gap of 3+ days always shows
        XCTAssertTrue(engine.shouldShowShedInsight(sessionCount: 8, daysSinceLastSession: 3))
        XCTAssertTrue(engine.shouldShowShedInsight(sessionCount: 12, daysSinceLastSession: 5))
    }

    // MARK: - Knowledge Shape Milestone

    func test_knowledgeShapeMilestone_firesOnceAndNotAgain() throws {
        // startingFresh milestone: 20+ cells exit Untried
        var scores: [MasteryScore] = []
        for i in 0..<21 {
            let note = MusicalNote(rawValue: i % 12) ?? .c
            let string = [4, 5, 6][i % 3]
            let s = MasteryScore(note: note, stringNumber: string)
            s.totalAttempts = 5
            s.correctAttempts = 3
            scores.append(s)
        }

        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, isAdaptive: true)
        session.attemptCount = 10
        session.correctCount = 7

        let attempts = [
            Attempt(targetNote: .c, targetString: 4, targetFret: 0,
                    playedNote: .c, playedString: 4, responseTimeMs: 400,
                    wasCorrect: true, sessionID: session.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        // First call — should fire
        let card1 = engine.insightForSummary(
            session: session,
            sessionAttempts: attempts,
            allSessions: [session],
            masteryScores: scores,
            baselineLevel: .startingFresh
        )
        XCTAssertEqual(card1.type, .knowledgeShapeMilestone)

        // Second call — should NOT fire again (stored in UserDefaults)
        let card2 = engine.insightForSummary(
            session: session,
            sessionAttempts: attempts,
            allSessions: [session],
            masteryScores: scores,
            baselineLevel: .startingFresh
        )
        XCTAssertNotEqual(card2.type, .knowledgeShapeMilestone)
    }

    // MARK: - Session 3 Recalibration Message

    func test_session3RecalibrationMessage_firesOnceAndNotAgain() throws {
        let score = MasteryScore(note: .e, stringNumber: 6)
        score.totalAttempts = 5
        score.correctAttempts = 3

        // 3 sessions, newest-first (all identical accuracy so order doesn't matter)
        let sessions = makeSessionHistory([
            (5, 3), (5, 3), (5, 3),
        ])
        let current = sessions.first!

        let attempts = [
            Attempt(targetNote: .e, targetString: 6, targetFret: 0,
                    playedNote: .e, playedString: 6, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        // First call at session 3 — should include recalibration
        let card1 = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [score],
            baselineLevel: .startingFresh
        )
        XCTAssertTrue(card1.body?.contains("updated your starting point") ?? false,
                      "Session 3 should include recalibration message")

        // Second call — recalibration should NOT appear again
        let card2 = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [score],
            baselineLevel: .startingFresh
        )
        XCTAssertFalse(card2.body?.contains("updated your starting point") ?? false,
                       "Recalibration message should only fire once")
    }

    // MARK: - Free Tier Filtering

    func test_freeTier_noInsightsAboutStrings1To3() throws {
        // Create scores on strings 1-3 (premium-only)
        let premiumScore = MasteryScore(note: .e, stringNumber: 1)
        premiumScore.totalAttempts = 20
        premiumScore.correctAttempts = 5

        // Create scores on strings 4-6 (free tier)
        let freeScore = MasteryScore(note: .a, stringNumber: 5)
        freeScore.totalAttempts = 10
        freeScore.correctAttempts = 7

        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, isAdaptive: true)
        session.attemptCount = 5
        session.correctCount = 3

        let attempts = [
            Attempt(targetNote: .a, targetString: 5, targetFret: 0,
                    playedNote: .a, playedString: 5, responseTimeMs: 400,
                    wasCorrect: true, sessionID: session.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: session,
            sessionAttempts: attempts,
            allSessions: [session],
            masteryScores: [premiumScore, freeScore],
            baselineLevel: .startingFresh
        )

        // Headline should not mention "high E" (string 1)
        XCTAssertFalse(card.headline.contains("high E"),
                       "Free tier should not surface insights about string 1")
    }

    // MARK: - Session Delta Factual Accuracy

    /// Helper: creates a session with specific accuracy.
    /// Note: insightForSummary expects allSessions in NEWEST-FIRST order
    /// (matching the repository's default sort). The engine reverses internally.
    private func makeSession(attemptCount: Int, correctCount: Int) -> Session {
        let s = Session(focusMode: .fullFretboard, gameMode: .untimed, isAdaptive: true)
        s.attemptCount = attemptCount
        s.correctCount = correctCount
        s.isCompleted = true
        return s
    }

    /// Builds a session array in newest-first order (as the repository returns).
    /// Pass accuracies in chronological order; this reverses them.
    private func makeSessionHistory(_ accuracies: [(attempts: Int, correct: Int)]) -> [Session] {
        accuracies.map { makeSession(attemptCount: $0.attempts, correctCount: $0.correct) }.reversed()
    }

    func test_sessionDelta_bestInN_notClaimedWhenTied() {
        // History (chronological): 100%, 80%, 100%, 80%, 100%, 80%, 100% (current)
        // The current session ties prior 100% sessions — should NOT claim "best in N"
        let sessions = makeSessionHistory([
            (10, 10),  // 100%
            (10, 8),   // 80%
            (10, 10),  // 100%
            (10, 8),   // 80%
            (10, 10),  // 100%
            (10, 8),   // 80%  (prev)
            (10, 10),  // 100% (current)
        ])
        let current = sessions.first!  // newest-first

        let attempts = [
            Attempt(targetNote: .e, targetString: 6, targetFret: 0,
                    playedNote: .e, playedString: 6, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [],
            baselineLevel: .startingFresh
        )

        // The headline must NOT contain "Best accuracy in" because 100% is not
        // strictly better than other 100% sessions in the window
        XCTAssertFalse(card.headline.contains("Best accuracy in"),
                       "Should not claim 'best' when prior sessions have equal accuracy. Got: \(card.headline)")
    }

    func test_sessionDelta_bestInN_claimedWhenGenuinelyBest() {
        // History (chronological): 70%, 70%, 75%, 80%, 72% (prev), 90% (current)
        let sessions = makeSessionHistory([
            (10, 7),   // 70%
            (10, 7),   // 70%
            (20, 15),  // 75%
            (10, 8),   // 80%
            (25, 18),  // 72% (prev)
            (10, 9),   // 90% (current)
        ])
        let current = sessions.first!  // newest-first

        let attempts = [
            Attempt(targetNote: .e, targetString: 6, targetFret: 0,
                    playedNote: .e, playedString: 6, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        // Need a score to make the card meaningful
        let score = MasteryScore(note: .e, stringNumber: 6)
        score.totalAttempts = 5
        score.correctAttempts = 4

        let card = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [score],
            baselineLevel: .startingFresh
        )

        // If the card is a sessionDelta type, it should correctly claim "best in N"
        if card.type == .sessionDelta && card.headline.contains("Best accuracy in") {
            // Verify the N value is correct (should be 6 = all sessions in window)
            XCTAssertTrue(card.headline.contains("Best accuracy in 6"),
                          "Should claim best in 6 sessions (5 prior + current). Got: \(card.headline)")
        }
        // If a different insight type won (tier transition, etc.), that's fine too
    }

    func test_sessionDelta_noFalseClaimOnFirstSession() {
        // Single session — no prior to compare against, should not claim "best"
        let session = makeSession(attemptCount: 10, correctCount: 10)
        let attempts = [
            Attempt(targetNote: .a, targetString: 5, targetFret: 0,
                    playedNote: .a, playedString: 5, responseTimeMs: 400,
                    wasCorrect: true, sessionID: session.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: session,
            sessionAttempts: attempts,
            allSessions: [session],
            masteryScores: [],
            baselineLevel: .startingFresh
        )

        XCTAssertFalse(card.headline.contains("Best accuracy in"),
                       "First session should not claim 'best in N'. Got: \(card.headline)")
    }

    func test_sessionDelta_noDeltaWhenImprovedByLessThan3() {
        // 78% → 80% = only 2% improvement, below the 3% threshold
        let sessions = makeSessionHistory([
            (50, 39),  // 78%
            (10, 8),   // 80% (current)
        ])
        let current = sessions.first!  // newest-first

        let attempts = [
            Attempt(targetNote: .a, targetString: 5, targetFret: 0,
                    playedNote: .a, playedString: 5, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [],
            baselineLevel: .startingFresh
        )

        // Should not surface a sessionDelta insight for a 2% change
        if card.type == .sessionDelta {
            XCTAssertFalse(card.headline.contains("Up 2%"),
                           "2% improvement should not trigger session delta. Got: \(card.headline)")
        }
    }

    // MARK: - Coverage Phrase Accuracy

    func test_coverage_everyNotePhrase_usesPhaseAwareLabel() {
        // In Foundation phase, the coverage phrase should say "natural note" not "note"
        // Reset phase to foundation
        let phaseManager = LearningPhaseManager()
        phaseManager.reset()
        phaseManager.initializeForBaseline(.startingFresh)

        // Create scores where string 5 has all natural notes attempted (frets 0-12)
        // ~7 unique naturals: A(0), B(2), C(3), D(5), E(7), F(8), G(10)
        var scores: [MasteryScore] = []
        let fretboardMap = FretboardMap()
        for fret in 0...12 {
            guard let note = fretboardMap.note(string: 5, fret: fret), note.isNatural else { continue }
            let s = MasteryScore(note: note, stringNumber: 5)
            s.totalAttempts = (fret < 8) ? 10 : 2  // frets 8+ are new this session
            s.correctAttempts = s.totalAttempts - 1
            scores.append(s)
        }

        let session = makeSession(attemptCount: 10, correctCount: 8)
        var attempts: [Attempt] = []
        for fret in [8, 10] {  // F and G — new natural notes this session
            guard let note = fretboardMap.note(string: 5, fret: fret) else { continue }
            for _ in 0..<2 {
                attempts.append(Attempt(
                    targetNote: note, targetString: 5, targetFret: fret,
                    playedNote: note, playedString: 5, responseTimeMs: 400,
                    wasCorrect: true, sessionID: session.id, gameMode: .untimed,
                    acceptedAnyString: false
                ))
            }
        }

        let card = engine.insightForSummary(
            session: session,
            sessionAttempts: attempts,
            allSessions: [session],
            masteryScores: scores,
            baselineLevel: .startingFresh
        )

        // If coverage was selected, the phrase should say "natural note" in Foundation
        if card.type == .coverage && card.headline.contains("every") {
            XCTAssertTrue(card.headline.contains("natural note"),
                          "Foundation phase should say 'natural note', got: \(card.headline)")
            XCTAssertFalse(card.headline.contains("every note "),
                           "Should not say generic 'every note' in Foundation. Got: \(card.headline)")
        }

        phaseManager.reset()
    }

    func test_coverage_everyNotePhrase_notClaimedForPartialCoverage() {
        // Only 3 natural notes attempted on string 5 — should NOT claim "every natural note"
        let phaseManager = LearningPhaseManager()
        phaseManager.reset()
        phaseManager.initializeForBaseline(.startingFresh)

        var scores: [MasteryScore] = []
        let fretboardMap = FretboardMap()
        for fret in 0...2 {
            guard let note = fretboardMap.note(string: 5, fret: fret) else { continue }
            let s = MasteryScore(note: note, stringNumber: 5)
            s.totalAttempts = 2
            s.correctAttempts = 1
            scores.append(s)
        }

        let session = makeSession(attemptCount: 6, correctCount: 3)
        var attempts: [Attempt] = []
        for fret in 0...2 {
            guard let note = fretboardMap.note(string: 5, fret: fret) else { continue }
            for _ in 0..<2 {
                attempts.append(Attempt(
                    targetNote: note, targetString: 5, targetFret: fret,
                    playedNote: note, playedString: 5, responseTimeMs: 400,
                    wasCorrect: fret < 2, sessionID: session.id, gameMode: .untimed,
                    acceptedAnyString: false
                ))
            }
        }

        let card = engine.insightForSummary(
            session: session,
            sessionAttempts: attempts,
            allSessions: [session],
            masteryScores: scores,
            baselineLevel: .startingFresh
        )

        if card.type == .coverage {
            XCTAssertFalse(card.headline.contains("every"),
                           "Should not claim 'every' with only 3 positions. Got: \(card.headline)")
        }

        phaseManager.reset()
    }

    // MARK: - Consistency Trend Accuracy

    func test_consistencyTrend_improving_requiresThreeSessionUptrend() {
        // Sessions (chronological): 60%, 70%, 80% — genuine 3-session uptrend
        let sessions = makeSessionHistory([
            (10, 6), (10, 7), (10, 8),
        ])

        let attempts = [
            Attempt(targetNote: .e, targetString: 6, targetFret: 0,
                    playedNote: .e, playedString: 6, responseTimeMs: 400,
                    wasCorrect: true, sessionID: sessions.last!.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: sessions.last!,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [],
            baselineLevel: .startingFresh
        )

        // If consistency trend is selected, the claim is valid
        if card.type == .consistencyTrend {
            XCTAssertTrue(card.isPositive, "Uptrend should be positive")
        }
    }

    func test_consistencyTrend_flat_notClaimedAsImproving() {
        // Sessions (chronological): 65%, ~63%, 64% — flat AND below 80%
        let sessions = makeSessionHistory([
            (20, 13), (19, 12), (25, 16),
        ])

        let current = sessions.first!
        let attempts = [
            Attempt(targetNote: .a, targetString: 5, targetFret: 0,
                    playedNote: .a, playedString: 5, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [],
            baselineLevel: .startingFresh
        )

        if card.type == .consistencyTrend {
            XCTAssertFalse(card.isPositive, "Flat trend should not be marked positive")
            XCTAssertFalse(card.headline.contains("climbing") || card.headline.contains("improvement"),
                           "Flat trend should not claim improvement. Got: \(card.headline)")
        }
    }

    func test_consistencyTrend_highAndFlat_notCalledPlateau() {
        // Sessions (chronological): 90%, 88%, ~91% — all above 80%
        let sessions = makeSessionHistory([
            (10, 9), (25, 22), (22, 20),
        ])

        let current = sessions.first!
        let attempts = [
            Attempt(targetNote: .a, targetString: 5, targetFret: 0,
                    playedNote: .a, playedString: 5, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [],
            baselineLevel: .startingFresh
        )

        // Should NOT generate a "plateau" consistency trend
        if card.type == .consistencyTrend {
            XCTAssertFalse(card.headline.contains("plateau") || card.headline.contains("Flat"),
                           "High accuracy (80%+) should not be called a plateau. Got: \(card.headline)")
        }
    }

    // MARK: - Temporal Modifier "Best This Week"

    func test_temporalModifier_bestThisWeek_notClaimedOnTie() {
        // Two sessions this week, both 80% — should not claim "best this week"
        // temporalModifier expects chronological order (oldest-first)
        let sessions = [
            makeSession(attemptCount: 10, correctCount: 8),
            makeSession(attemptCount: 10, correctCount: 8),
        ]

        let modifier = InsightPhraseLibrary.temporalModifier(
            sessionCount: 2,
            allSessions: sessions,
            currentWeakString: 6,
            lastWeakString: 5,
            daysSinceLastSession: 0
        )

        if let mod = modifier {
            XCTAssertFalse(mod.prefix.contains("best session this week"),
                           "Should not claim 'best this week' when tied. Got: \(mod.prefix)")
        }
    }

    func test_temporalModifier_bestThisWeek_claimedWhenGenuinelyBest() {
        // Two sessions this week (chronological): 70% then 90% — 90% is genuinely best
        // temporalModifier expects chronological order (oldest-first)
        let sessions = [
            makeSession(attemptCount: 10, correctCount: 7),
            makeSession(attemptCount: 10, correctCount: 9),
        ]

        let modifier = InsightPhraseLibrary.temporalModifier(
            sessionCount: 2,
            allSessions: sessions,
            currentWeakString: nil,
            lastWeakString: nil,
            daysSinceLastSession: 0
        )

        // Should claim best this week since 90% > 70%
        XCTAssertNotNil(modifier)
        XCTAssertTrue(modifier?.prefix.contains("best session this week") ?? false,
                      "Should claim 'best this week' when genuinely best. Got: \(modifier?.prefix ?? "nil")")
    }

    // MARK: - Mastery Stage Computation

    func test_computeMasteryStage_exploring() {
        // Very few scores — most cells untried
        let score = MasteryScore(note: .e, stringNumber: 6)
        score.totalAttempts = 5
        score.correctAttempts = 3

        let stage = engine.computeMasteryStage(scores: [score])
        XCTAssertEqual(stage, .exploring)
    }

    func test_computeMasteryStage_consolidating() {
        // Many cells attempted, few proficient/mastered
        var scores: [MasteryScore] = []
        for i in 0..<20 {
            let note = MusicalNote(rawValue: i % 12) ?? .c
            let string = [4, 5, 6][i % 3]
            let s = MasteryScore(note: note, stringNumber: string)
            s.totalAttempts = 10
            s.correctAttempts = 5 // score ~0.54 → Learning
            scores.append(s)
        }

        let stage = engine.computeMasteryStage(scores: scores)
        XCTAssertEqual(stage, .consolidating)
    }

    func test_computeMasteryStage_refining() {
        // Many cells at proficient/mastered level
        var scores: [MasteryScore] = []
        for i in 0..<20 {
            let note = MusicalNote(rawValue: i % 12) ?? .c
            let string = [4, 5, 6][i % 3]
            let s = MasteryScore(note: note, stringNumber: string)
            s.totalAttempts = 20
            s.correctAttempts = 19 // score ~0.91 → Proficient (or Mastered if 15+)
            scores.append(s)
        }

        let stage = engine.computeMasteryStage(scores: scores)
        XCTAssertEqual(stage, .refining)
    }

    // MARK: - Insight Contradiction Detection

    /// Validates that an InsightCard's headline contains no unreplaced placeholders
    /// and no claims that contradict the session data.
    private func assertNoContradictions(
        card: InsightCard,
        currentSession: Session,
        allSessions: [Session],
        scores: [MasteryScore],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let headline = card.headline
        let body = card.body ?? ""
        let combined = headline + " " + body

        // 1. No unreplaced placeholders
        let placeholders = ["[STRING]", "[NOTE]", "[ACCURACY]", "[DELTA]", "[N]",
                            "[COUNT]", "[TIER]", "[ATTEMPTS]", "[PREV]", "[RANGE]", "[NOTE_TYPE]"]
        for p in placeholders {
            XCTAssertFalse(combined.contains(p),
                           "Unreplaced placeholder \(p) in: \(combined)", file: file, line: line)
        }

        // 2. "Best in N" — verify the claim is true
        if let range = headline.range(of: "Best accuracy in ") {
            let afterBest = headline[range.upperBound...]
            if let nEnd = afterBest.firstIndex(of: " "),
               let n = Int(afterBest[..<nEnd]) {
                let priorSessions = allSessions.dropLast()
                let windowPrior = priorSessions.suffix(n - 1)
                let priorMax = windowPrior.map(\.accuracyPercent).max() ?? 0
                XCTAssertGreaterThan(currentSession.accuracyPercent, priorMax,
                                     "\"Best in \(n)\" claim is false: current \(currentSession.accuracyPercent)% <= prior max \(priorMax)%",
                                     file: file, line: line)
            }
        }

        // 3. "[ACCURACY]%" values must match actual data
        // Session delta: "[ACCURACY]% today" should match currentSession
        if headline.contains("% today") {
            let accuracyStr = "\(Int(currentSession.accuracyPercent))"
            XCTAssertTrue(headline.contains(accuracyStr + "% today") || headline.contains(accuracyStr + "%"),
                          "Accuracy \(accuracyStr)% not found in: \(headline)", file: file, line: line)
        }

        // 4. "plateau" / "flat" not valid when accuracy is high and rising
        if combined.lowercased().contains("plateau") || combined.contains("Flat accuracy") {
            let last3 = allSessions.suffix(3).map(\.accuracyPercent)
            if last3.count >= 3 {
                let allHigh = last3.allSatisfy { $0 >= 80 }
                XCTAssertFalse(allHigh,
                               "Plateau/flat claimed but all 3 sessions are 80%+: \(last3)",
                               file: file, line: line)
                let isRising = last3.last! > last3.first!
                XCTAssertFalse(isRising && (last3.last! - last3.first!) >= 5,
                               "Plateau claimed but accuracy rose \(Int(last3.last! - last3.first!))%",
                               file: file, line: line)
            }
        }

        // 5. Consistency trend "climbing" / "improvement" requires actual uptrend
        if card.type == .consistencyTrend &&
           (combined.contains("climbing") || combined.contains("improvement") || combined.contains("Steady progress")) {
            let last3 = allSessions.suffix(3).map(\.accuracyPercent)
            if last3.count >= 3 {
                let isImproving = last3[1] > last3[0] && last3[2] > last3[1]
                XCTAssertTrue(isImproving,
                              "Consistency trend claims improvement but sessions aren't trending up: \(last3). Card: type=\(card.type), headline=\(headline)",
                              file: file, line: line)
            }
        }

        // 6. Positive/negative alignment
        if card.type == .sessionDelta {
            if headline.contains("Up ") || headline.contains("Best accuracy") {
                XCTAssertTrue(card.isPositive,
                              "Positive delta headline but card marked negative", file: file, line: line)
            }
            if headline.contains("Down ") || headline.contains("dipped") {
                XCTAssertFalse(card.isPositive,
                               "Negative delta headline but card marked positive", file: file, line: line)
            }
        }
    }

    // MARK: - Scenario: Rapid Phase 1 Progression

    func test_scenario_rapidPhase1_noFalseClaims() {
        // Simulates a user rapidly progressing through Phase 1:
        // 7 sessions, accuracy rising from 70% to 95%
        let accuracies: [(attempts: Int, correct: Int)] = [
            (10, 7),   // 70%
            (10, 7),   // 70%
            (10, 8),   // 80%
            (10, 8),   // 80%
            (10, 9),   // 90%
            (10, 9),   // 90%
            (20, 19),  // 95%
        ]

        let sessions = makeSessionHistory(accuracies)
        let current = sessions.first!  // newest-first: first element is the current session
        let attempts = [
            Attempt(targetNote: .a, targetString: 5, targetFret: 0,
                    playedNote: .a, playedString: 5, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [],
            baselineLevel: .startingFresh
        )

        assertNoContradictions(card: card, currentSession: current,
                               allSessions: sessions, scores: [])
    }

    // MARK: - Scenario: Plateau then Breakthrough

    func test_scenario_plateauThenBreakthrough_noFalseClaims() {
        // 5 sessions at 65%, then a breakthrough to 85%
        let accuracies: [(attempts: Int, correct: Int)] = [
            (20, 13),  // 65%
            (20, 13),  // 65%
            (20, 13),  // 65%
            (20, 13),  // 65%
            (20, 13),  // 65%
            (20, 17),  // 85% — breakthrough
        ]

        let sessions = makeSessionHistory(accuracies)
        let current = sessions.first!  // newest-first: first element is the current session
        let attempts = [
            Attempt(targetNote: .d, targetString: 4, targetFret: 0,
                    playedNote: .d, playedString: 4, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [],
            baselineLevel: .startingFresh
        )

        assertNoContradictions(card: card, currentSession: current,
                               allSessions: sessions, scores: [])
        // A 20% jump should be positive
        if card.type == .sessionDelta {
            XCTAssertTrue(card.isPositive, "20% improvement should be positive")
        }
    }

    // MARK: - Scenario: Consistently High

    func test_scenario_consistentlyHigh_noPlateauClaim() {
        // User is doing great: 88%, 92%, 90%, 91%, 89%
        let accuracies: [(attempts: Int, correct: Int)] = [
            (25, 22),  // 88%
            (25, 23),  // 92%
            (10, 9),   // 90%
            (22, 20),  // ~91%
            (19, 17),  // ~89%
        ]

        let sessions = makeSessionHistory(accuracies)
        let current = sessions.first!  // newest-first: first element is the current session
        let attempts = [
            Attempt(targetNote: .e, targetString: 6, targetFret: 0,
                    playedNote: .e, playedString: 6, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [],
            baselineLevel: .chordPlayer
        )

        assertNoContradictions(card: card, currentSession: current,
                               allSessions: sessions, scores: [])
    }

    // MARK: - Scenario: Declining then Recovery

    func test_scenario_declineThenRecovery_noFalseClaims() {
        // 90% → 75% → 70% → 82% — recovery after a dip
        let accuracies: [(attempts: Int, correct: Int)] = [
            (10, 9),   // 90%
            (20, 15),  // 75%
            (10, 7),   // 70%
            (50, 41),  // 82%
        ]

        let sessions = makeSessionHistory(accuracies)
        let current = sessions.first!  // newest-first: first element is the current session
        let attempts = [
            Attempt(targetNote: .a, targetString: 5, targetFret: 0,
                    playedNote: .a, playedString: 5, responseTimeMs: 400,
                    wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        let card = engine.insightForSummary(
            session: current,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [],
            baselineLevel: .startingFresh
        )

        assertNoContradictions(card: card, currentSession: current,
                               allSessions: sessions, scores: [])
    }

    // MARK: - Scenario: First Few Sessions

    func test_scenario_firstThreeSessions_noFalseClaims() {
        // Brand new user: sessions 1, 2, 3
        for sessionIndex in 1...3 {
            let accuracies = (0..<sessionIndex).map { i in (attempts: 10, correct: 5 + i) }
            let sessions = makeSessionHistory(accuracies)
            let current = sessions.first!  // newest-first
            let attempts = [
                Attempt(targetNote: .e, targetString: 6, targetFret: 0,
                        playedNote: .e, playedString: 6, responseTimeMs: 400,
                        wasCorrect: true, sessionID: current.id, gameMode: .untimed,
                        acceptedAnyString: false),
            ]

            let card = engine.insightForSummary(
                session: current,
                sessionAttempts: attempts,
                allSessions: sessions,
                masteryScores: [],
                baselineLevel: .startingFresh
            )

            assertNoContradictions(card: card, currentSession: current,
                                   allSessions: sessions, scores: [])
        }
    }
}
