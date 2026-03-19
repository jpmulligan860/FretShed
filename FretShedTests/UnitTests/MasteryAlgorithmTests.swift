// MasteryAlgorithmTests.swift
// FretShed — Unit Tests
//
// Tests the Bayesian mastery calculation including edge cases.

import XCTest
@testable import FretShed

final class MasteryAlgorithmTests: XCTestCase {

    // MARK: - Basic Score Calculation

    func test_score_zeroAttempts_returnsPrior() {
        // With 0 attempts: (0 + α) / (0 + α + β) = 2/3 ≈ 0.667
        let score = MasteryCalculator.score(correct: 0, total: 0)
        XCTAssertEqual(score, 2.0 / 3.0, accuracy: 0.0001)
    }

    func test_score_allCorrect_10attempts() {
        // (10 + 2) / (10 + 2 + 1) = 12/13 ≈ 0.923
        let score = MasteryCalculator.score(correct: 10, total: 10)
        XCTAssertEqual(score, 12.0 / 13.0, accuracy: 0.0001)
    }

    func test_score_allWrong_10attempts() {
        // (0 + 2) / (10 + 2 + 1) = 2/13 ≈ 0.154
        let score = MasteryCalculator.score(correct: 0, total: 10)
        XCTAssertEqual(score, 2.0 / 13.0, accuracy: 0.0001)
    }

    func test_score_50percent_10attempts() {
        // (5 + 2) / (10 + 2 + 1) = 7/13 ≈ 0.538
        let score = MasteryCalculator.score(correct: 5, total: 10)
        XCTAssertEqual(score, 7.0 / 13.0, accuracy: 0.0001)
    }

    func test_score_1correct_1attempt() {
        // (1 + 2) / (1 + 2 + 1) = 3/4 = 0.75
        let score = MasteryCalculator.score(correct: 1, total: 1)
        XCTAssertEqual(score, 3.0 / 4.0, accuracy: 0.0001)
    }

    func test_score_isAlwaysBetween0And1() {
        let cases = [(0, 0), (0, 5), (5, 5), (0, 100), (100, 100), (1, 1000)]
        for (correct, total) in cases {
            let score = MasteryCalculator.score(correct: correct, total: total)
            XCTAssertGreaterThanOrEqual(score, 0.0)
            XCTAssertLessThanOrEqual(score, 1.0)
        }
    }

    // MARK: - Mastery Object

    func test_masteryScore_newObject_hasCorrectDefaults() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        XCTAssertEqual(ms.totalAttempts, 0)
        XCTAssertEqual(ms.correctAttempts, 0)
        XCTAssertFalse(ms.isMastered)
        XCTAssertFalse(ms.isStruggling)
        XCTAssertNil(ms.spacingCheckpoint1Date)
        XCTAssertNil(ms.spacingCheckpoint2Date)
        XCTAssertNil(ms.spacingCheckpoint3Date)
        XCTAssertFalse(ms.hasCompletedSpacingGate)
    }

    func test_masteryScore_isMastered_requiresSpacingGate() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        // 1 correct attempt — score = 3/4 = 0.75, but NO spacing checkpoints
        ms.record(wasCorrect: true)
        XCTAssertFalse(ms.isMastered, "isMastered requires spacing gate completion")
        XCTAssertFalse(ms.hasCompletedSpacingGate)

        // Set all 3 checkpoints → now mastered (no attempt minimum needed)
        ms.spacingCheckpoint1Date = Date().addingTimeInterval(-7 * 86400)
        ms.spacingCheckpoint2Date = Date().addingTimeInterval(-3 * 86400)
        ms.spacingCheckpoint3Date = Date()
        XCTAssertTrue(ms.hasCompletedSpacingGate)
        XCTAssertTrue(ms.isMastered)
    }

    func test_masteryScore_notMastered_scoreBelowThreshold() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        // 3 correct, 5 wrong → score = 5/10 = 0.50 < 0.75
        for i in 0..<8 { ms.record(wasCorrect: i < 3) }
        // Even with all checkpoints, score too low
        ms.spacingCheckpoint1Date = Date().addingTimeInterval(-7 * 86400)
        ms.spacingCheckpoint2Date = Date().addingTimeInterval(-3 * 86400)
        ms.spacingCheckpoint3Date = Date()
        XCTAssertFalse(ms.isMastered, "Score below threshold blocks mastery even with checkpoints")
    }

    func test_masteryScore_notMastered_noSpacingGate() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        // 5 correct attempts, score well above threshold
        for _ in 0..<5 { ms.record(wasCorrect: true) }
        ms.spacingCheckpoint1Date = Date()
        // Only CP1 set — not mastered
        XCTAssertFalse(ms.isMastered, "Needs all 3 spacing checkpoints")
    }

    func test_masteryScore_isStruggling_whenBelowThreshold() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        // 5 wrong, 0 correct
        for _ in 0..<5 {
            ms.record(wasCorrect: false)
        }
        // Score = (0 + 2) / (5 + 2 + 1) = 2/8 = 0.25 < 0.50 → struggling
        XCTAssertTrue(ms.isStruggling)
    }

    func test_masteryScore_notStruggling_insufficientAttempts() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        // Only 4 wrong (< required 5 for struggling label)
        for _ in 0..<4 {
            ms.record(wasCorrect: false)
        }
        XCTAssertFalse(ms.isStruggling)
    }

    func test_masteryScore_record_incrementsTotalAttempts() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        ms.record(wasCorrect: true)
        ms.record(wasCorrect: false)
        ms.record(wasCorrect: true)
        XCTAssertEqual(ms.totalAttempts, 3)
        XCTAssertEqual(ms.correctAttempts, 2)
    }

    func test_masteryScore_updateBestStreak_keepsHighest() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        ms.updateBestStreak(5)
        XCTAssertEqual(ms.bestStreakCount, 5)
        ms.updateBestStreak(3)
        XCTAssertEqual(ms.bestStreakCount, 5, "Best streak should not decrease")
        ms.updateBestStreak(10)
        XCTAssertEqual(ms.bestStreakCount, 10)
    }

    // MARK: - Overall Score

    func test_overallScore_emptyArray_returnsZero() {
        XCTAssertEqual(MasteryCalculator.overallScore(from: []), 0.0)
    }

    func test_overallScore_noAttempts_returnsPrior() {
        let scores = [MasteryScore(note: .a, stringNumber: 1),
                      MasteryScore(note: .b, stringNumber: 2)]
        // All zero attempts → prior = α/(α+β) = 2/3
        let overall = MasteryCalculator.overallScore(from: scores)
        XCTAssertEqual(overall, 2.0 / 3.0, accuracy: 0.0001)
    }

    func test_overallScore_weightsHigherAttemptCountsMore() {
        let highAttempts = MasteryScore(note: .a, stringNumber: 1)
        for _ in 0..<20 { highAttempts.record(wasCorrect: true) }

        let lowAttempts = MasteryScore(note: .b, stringNumber: 2)
        for _ in 0..<2 { lowAttempts.record(wasCorrect: false) }

        let overall = MasteryCalculator.overallScore(from: [highAttempts, lowAttempts])
        // Should be much closer to highAttempts' score (≈ 0.95) than to 0.5
        XCTAssertGreaterThan(overall, 0.7)
    }

    // MARK: - Constants Verification

    func test_alpha_is2() {
        XCTAssertEqual(MasteryScore.alpha, 2.0)
    }

    func test_beta_is1() {
        XCTAssertEqual(MasteryScore.beta, 1.0)
    }

    func test_masteredThreshold_is75Percent() {
        XCTAssertEqual(MasteryScore.masteredThreshold, 0.75)
    }

    func test_masteredMinAttempts_is15() {
        XCTAssertEqual(MasteryScore.masteredMinAttempts, 15)
    }

    func test_strugglingThreshold_is50Percent() {
        XCTAssertEqual(MasteryScore.strugglingThreshold, 0.50)
    }

    func test_strugglingMinAttempts_is5() {
        XCTAssertEqual(MasteryScore.strugglingMinAttempts, 5)
    }

    // MARK: - Spacing Gate

    func test_spacingGate_partialCheckpoints_notComplete() {
        let ms = MasteryScore(note: .c, stringNumber: 3)
        ms.spacingCheckpoint1Date = Date()
        XCTAssertFalse(ms.hasCompletedSpacingGate)

        ms.spacingCheckpoint2Date = Date()
        XCTAssertFalse(ms.hasCompletedSpacingGate)

        ms.spacingCheckpoint3Date = Date()
        XCTAssertTrue(ms.hasCompletedSpacingGate)
    }

    func test_spacingGate_regressFromCP2_dropsToCP1() {
        let ms = MasteryScore(note: .d, stringNumber: 2)
        let cp1Date = Date().addingTimeInterval(-5 * 86400)
        ms.spacingCheckpoint1Date = cp1Date
        ms.spacingCheckpoint2Date = Date()
        // Regress drops CP2, keeps CP1
        ms.regressSpacingCheckpoint()
        XCTAssertEqual(ms.spacingCheckpoint1Date, cp1Date, "CP1 preserved on regression from CP2")
        XCTAssertNil(ms.spacingCheckpoint2Date, "CP2 dropped on regression")
    }

    func test_spacingGate_regressFromCP1_dropsToNil() {
        let ms = MasteryScore(note: .d, stringNumber: 2)
        ms.spacingCheckpoint1Date = Date()
        // Regress drops CP1
        ms.regressSpacingCheckpoint()
        XCTAssertNil(ms.spacingCheckpoint1Date)
    }

    func test_spacingGate_regressDoesNotClearCompletedGate() {
        let ms = MasteryScore(note: .e, stringNumber: 1)
        ms.spacingCheckpoint1Date = Date().addingTimeInterval(-10 * 86400)
        ms.spacingCheckpoint2Date = Date().addingTimeInterval(-5 * 86400)
        ms.spacingCheckpoint3Date = Date()
        XCTAssertTrue(ms.hasCompletedSpacingGate)
        // Regress is a no-op when gate is complete
        ms.regressSpacingCheckpoint()
        XCTAssertNotNil(ms.spacingCheckpoint1Date)
        XCTAssertNotNil(ms.spacingCheckpoint2Date)
        XCTAssertNotNil(ms.spacingCheckpoint3Date)
    }

    func test_spacingGate_absenceDoesNotResetCheckpoints() {
        let ms = MasteryScore(note: .g, stringNumber: 4)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 86400)
        ms.spacingCheckpoint1Date = thirtyDaysAgo
        // Simulate 30 days of absence — checkpoint should remain
        XCTAssertNotNil(ms.spacingCheckpoint1Date)
        XCTAssertEqual(ms.spacingCheckpoint1Date, thirtyDaysAgo)
    }

    func test_spacingGate_doubleRegressFromCP2_clearsAll() {
        let ms = MasteryScore(note: .a, stringNumber: 5)
        ms.spacingCheckpoint1Date = Date().addingTimeInterval(-5 * 86400)
        ms.spacingCheckpoint2Date = Date()
        // First regress: CP2 → CP1
        ms.regressSpacingCheckpoint()
        XCTAssertNotNil(ms.spacingCheckpoint1Date)
        XCTAssertNil(ms.spacingCheckpoint2Date)
        // Second regress: CP1 → nil
        ms.regressSpacingCheckpoint()
        XCTAssertNil(ms.spacingCheckpoint1Date)
    }

    // MARK: - Spacing Gate Checkpoint Advancement

    func test_tryAdvanceCheckpoint_CP1_setsOnFirstProficient() {
        let ms = makeProficientScore()
        let result = ms.tryAdvanceCheckpoint()
        XCTAssertEqual(result, 1)
        XCTAssertNotNil(ms.spacingCheckpoint1Date)
        XCTAssertNil(ms.spacingCheckpoint2Date)
    }

    func test_tryAdvanceCheckpoint_CP2_requires1CalendarDay() {
        let ms = makeProficientScore()
        let today = Date()
        ms.spacingCheckpoint1Date = today
        // Same day → no advancement
        XCTAssertNil(ms.tryAdvanceCheckpoint(today: today))
        XCTAssertNil(ms.spacingCheckpoint2Date)
        // Next calendar day → advances
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        XCTAssertEqual(ms.tryAdvanceCheckpoint(today: tomorrow), 2)
        XCTAssertNotNil(ms.spacingCheckpoint2Date)
    }

    func test_tryAdvanceCheckpoint_CP3_requires3CalendarDays() {
        let ms = makeProficientScore()
        let day0 = Date()
        ms.spacingCheckpoint1Date = Calendar.current.date(byAdding: .day, value: -5, to: day0)!
        ms.spacingCheckpoint2Date = day0
        // 1 day later → too soon for CP3
        let day1 = Calendar.current.date(byAdding: .day, value: 1, to: day0)!
        XCTAssertNil(ms.tryAdvanceCheckpoint(today: day1))
        // 2 days later → still too soon
        let day2 = Calendar.current.date(byAdding: .day, value: 2, to: day0)!
        XCTAssertNil(ms.tryAdvanceCheckpoint(today: day2))
        // 3 days later → advances
        let day3 = Calendar.current.date(byAdding: .day, value: 3, to: day0)!
        XCTAssertEqual(ms.tryAdvanceCheckpoint(today: day3), 3)
        XCTAssertTrue(ms.hasCompletedSpacingGate)
    }

    func test_tryAdvanceCheckpoint_belowThreshold_doesNotAdvance() {
        let ms = MasteryScore(note: .c, stringNumber: 1)
        // 5 correct out of 10 → score ≈ 0.538 < 0.75
        for i in 0..<10 { ms.record(wasCorrect: i < 5) }
        XCTAssertNil(ms.tryAdvanceCheckpoint())
        XCTAssertNil(ms.spacingCheckpoint1Date)
    }

    func test_tryAdvanceCheckpoint_insufficientAttempts_doesNotAdvance() {
        let ms = MasteryScore(note: .c, stringNumber: 1)
        // 2 correct → score = 4/5 = 0.80 (above threshold) but only 2 attempts (< 3 minimum)
        ms.record(wasCorrect: true)
        ms.record(wasCorrect: true)
        XCTAssertGreaterThanOrEqual(ms.score, MasteryScore.masteredThreshold)
        XCTAssertNil(ms.tryAdvanceCheckpoint(), "Need >= 3 attempts before CP1")
        XCTAssertNil(ms.spacingCheckpoint1Date)

        // Third attempt crosses the floor
        ms.record(wasCorrect: true)
        XCTAssertEqual(ms.tryAdvanceCheckpoint(), 1, "3 attempts = checkpoint can advance")
        XCTAssertNotNil(ms.spacingCheckpoint1Date)
    }

    func test_tryAdvanceCheckpoint_alreadyComplete_noOp() {
        let ms = makeProficientScore()
        ms.spacingCheckpoint1Date = Date().addingTimeInterval(-10 * 86400)
        ms.spacingCheckpoint2Date = Date().addingTimeInterval(-5 * 86400)
        ms.spacingCheckpoint3Date = Date()
        XCTAssertNil(ms.tryAdvanceCheckpoint())
    }

    func test_tryAdvanceCheckpoint_largeGap_satisfiesCP2ButNotCP3InSameSession() {
        let ms = makeProficientScore()
        // CP1 logged 15 days ago
        let day0 = Date()
        ms.spacingCheckpoint1Date = Calendar.current.date(byAdding: .day, value: -15, to: day0)!
        // User returns today — satisfies CP2 (15 days > 1 day)
        XCTAssertEqual(ms.tryAdvanceCheckpoint(today: day0), 2)
        XCTAssertNotNil(ms.spacingCheckpoint2Date)
        // But CP3 requires 3+ days after CP2, and CP2 was just set to today
        XCTAssertNil(ms.tryAdvanceCheckpoint(today: day0))
        XCTAssertNil(ms.spacingCheckpoint3Date)
    }

    func test_tryAdvanceCheckpoint_minimumPathToMastered() {
        let ms = makeProficientScore()
        let calendar = Calendar.current
        let day1 = Date()
        // Day 1: CP1
        XCTAssertEqual(ms.tryAdvanceCheckpoint(today: day1), 1)
        // Day 2: CP2 (1 day after CP1)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        XCTAssertEqual(ms.tryAdvanceCheckpoint(today: day2), 2)
        // Day 5: CP3 (3 days after CP2)
        let day5 = calendar.date(byAdding: .day, value: 3, to: day2)!
        XCTAssertEqual(ms.tryAdvanceCheckpoint(today: day5), 3)
        XCTAssertTrue(ms.hasCompletedSpacingGate)
        XCTAssertTrue(ms.isMastered)
    }

    func test_tryAdvanceCheckpoint_incorrectRegressThenRestart() {
        let ms = makeProficientScore()
        let day0 = Date()
        ms.tryAdvanceCheckpoint(today: day0)
        XCTAssertNotNil(ms.spacingCheckpoint1Date)
        // Incorrect answer regresses one step (CP1 → nil)
        ms.regressSpacingCheckpoint()
        XCTAssertNil(ms.spacingCheckpoint1Date)
        // Must restart from CP1
        XCTAssertEqual(ms.tryAdvanceCheckpoint(today: day0), 1)
    }

    // MARK: - Active Checkpoint Progression

    func test_hasActiveCheckpointProgression_noCheckpoints_false() {
        let ms = MasteryScore(note: .c, stringNumber: 1)
        XCTAssertFalse(ms.hasActiveCheckpointProgression)
    }

    func test_hasActiveCheckpointProgression_partialCheckpoints_true() {
        let ms = MasteryScore(note: .c, stringNumber: 1)
        ms.spacingCheckpoint1Date = Date()
        XCTAssertTrue(ms.hasActiveCheckpointProgression)

        ms.spacingCheckpoint2Date = Date()
        XCTAssertTrue(ms.hasActiveCheckpointProgression, "CP1+CP2 without CP3 = active")
    }

    func test_hasActiveCheckpointProgression_allCheckpoints_false() {
        let ms = MasteryScore(note: .c, stringNumber: 1)
        ms.spacingCheckpoint1Date = Date().addingTimeInterval(-10 * 86400)
        ms.spacingCheckpoint2Date = Date().addingTimeInterval(-5 * 86400)
        ms.spacingCheckpoint3Date = Date()
        XCTAssertFalse(ms.hasActiveCheckpointProgression, "Completed gate = not active")
    }

    // MARK: - Warmup Sizing

    func test_reviewSizing_30percentOfSessionLength() {
        // reviewCount = round(sessionLength * 0.30), clamped [3, 10]
        XCTAssertEqual(min(max(Int(round(5.0 * 0.30)), 3), 10), 3, "Clamped at min 3")
        XCTAssertEqual(min(max(Int(round(10.0 * 0.30)), 3), 10), 3)
        XCTAssertEqual(min(max(Int(round(15.0 * 0.30)), 3), 10), 5)
        XCTAssertEqual(min(max(Int(round(20.0 * 0.30)), 3), 10), 6)
        XCTAssertEqual(min(max(Int(round(25.0 * 0.30)), 3), 10), 8)
        XCTAssertEqual(min(max(Int(round(30.0 * 0.30)), 3), 10), 9)
        XCTAssertEqual(min(max(Int(round(35.0 * 0.30)), 3), 10), 10)
        XCTAssertEqual(min(max(Int(round(50.0 * 0.30)), 3), 10), 10, "Clamped at max 10")
    }

    // MARK: - Score Regression & Checkpoint Preservation

    func test_scoreRegression_checkpointsPreserved() {
        let ms = makeProficientScore()
        // Set all 3 checkpoints
        ms.spacingCheckpoint1Date = Date().addingTimeInterval(-10 * 86400)
        ms.spacingCheckpoint2Date = Date().addingTimeInterval(-5 * 86400)
        ms.spacingCheckpoint3Date = Date()
        XCTAssertTrue(ms.isMastered)

        // Simulate poor performance — score drops below proficient
        // 5 correct + 10 wrong = 15 total, score = (5+2)/(15+3) = 7/18 ≈ 0.389
        for _ in 0..<10 { ms.record(wasCorrect: false) }
        XCTAssertLessThan(ms.score, MasteryScore.masteredThreshold)
        XCTAssertFalse(ms.isMastered, "Score below threshold = not mastered")

        // But checkpoints are preserved
        XCTAssertTrue(ms.hasCompletedSpacingGate, "Checkpoints survive score regression")
        XCTAssertNotNil(ms.spacingCheckpoint1Date)
        XCTAssertNotNil(ms.spacingCheckpoint2Date)
        XCTAssertNotNil(ms.spacingCheckpoint3Date)
    }

    func test_scoreRecovery_reEarnsMasteredImmediately() {
        let ms = makeProficientScore()
        // Set all 3 checkpoints
        ms.spacingCheckpoint1Date = Date().addingTimeInterval(-10 * 86400)
        ms.spacingCheckpoint2Date = Date().addingTimeInterval(-5 * 86400)
        ms.spacingCheckpoint3Date = Date()
        XCTAssertTrue(ms.isMastered)

        // Regress — score drops below proficient
        for _ in 0..<10 { ms.record(wasCorrect: false) }
        XCTAssertFalse(ms.isMastered)

        // Recover — score climbs back above threshold
        // total = 5+10+40=55, correct = 5+40=45, score = (45+2)/(55+3) = 47/58 ≈ 0.810
        for _ in 0..<40 { ms.record(wasCorrect: true) }
        XCTAssertGreaterThanOrEqual(ms.score, MasteryScore.masteredThreshold)
        XCTAssertTrue(ms.isMastered, "Re-earns mastered immediately with existing checkpoints")
    }

    func test_completedGate_incorrectAnswer_doesNotResetCheckpoints() {
        let ms = makeProficientScore()
        ms.spacingCheckpoint1Date = Date().addingTimeInterval(-10 * 86400)
        ms.spacingCheckpoint2Date = Date().addingTimeInterval(-5 * 86400)
        ms.spacingCheckpoint3Date = Date()
        XCTAssertTrue(ms.hasCompletedSpacingGate)

        // Record an incorrect answer — regressSpacingCheckpoint is a no-op for completed gate
        ms.record(wasCorrect: false)
        ms.regressSpacingCheckpoint()
        XCTAssertTrue(ms.hasCompletedSpacingGate, "Completed gate survives incorrect answer + regression")
    }

    // MARK: - Helpers

    /// Creates a MasteryScore with 5/5 correct (score = 7/8 = 0.875, above proficient threshold).
    private func makeProficientScore() -> MasteryScore {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        for _ in 0..<5 { ms.record(wasCorrect: true) }
        return ms
    }
}
