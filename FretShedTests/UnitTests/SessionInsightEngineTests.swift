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

        let sessions = (0..<3).map { _ in
            let s = Session(focusMode: .fullFretboard, gameMode: .untimed, isAdaptive: true)
            s.attemptCount = 5
            s.correctCount = 3
            s.isCompleted = true
            return s
        }

        let attempts = [
            Attempt(targetNote: .e, targetString: 6, targetFret: 0,
                    playedNote: .e, playedString: 6, responseTimeMs: 400,
                    wasCorrect: true, sessionID: sessions.last!.id, gameMode: .untimed,
                    acceptedAnyString: false),
        ]

        // First call at session 3 — should include recalibration
        let card1 = engine.insightForSummary(
            session: sessions.last!,
            sessionAttempts: attempts,
            allSessions: sessions,
            masteryScores: [score],
            baselineLevel: .startingFresh
        )
        XCTAssertTrue(card1.body?.contains("updated your starting point") ?? false,
                      "Session 3 should include recalibration message")

        // Second call — recalibration should NOT appear again
        let card2 = engine.insightForSummary(
            session: sessions.last!,
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
}
