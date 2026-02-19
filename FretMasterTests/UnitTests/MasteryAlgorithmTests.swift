// MasteryAlgorithmTests.swift
// FretMaster — Unit Tests
//
// Tests the Bayesian mastery calculation including edge cases.

import XCTest
@testable import FretMaster

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
    }

    func test_masteryScore_isMastered_requiresBothThresholds() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        // Give it 15 correct attempts
        for _ in 0..<15 {
            ms.record(wasCorrect: true)
        }
        // Score = (15 + 2) / (15 + 2 + 1) = 17/18 ≈ 0.944 → should be mastered
        XCTAssertTrue(ms.isMastered)
    }

    func test_masteryScore_notMastered_insufficientAttempts() {
        let ms = MasteryScore(note: .a, stringNumber: 1)
        // Only 5 correct attempts (< required 15)
        for _ in 0..<5 {
            ms.record(wasCorrect: true)
        }
        XCTAssertFalse(ms.isMastered, "Need ≥15 attempts for mastered status")
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

    func test_masteredThreshold_is90Percent() {
        XCTAssertEqual(MasteryScore.masteredThreshold, 0.90)
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
}
