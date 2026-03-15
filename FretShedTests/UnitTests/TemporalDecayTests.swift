// TemporalDecayTests.swift
// FretShedTests

import XCTest
import SwiftData
@testable import FretShed

@MainActor
final class TemporalDecayTests: XCTestCase {

    let tolerance = 0.05 // 5% tolerance for decay curve checks

    // MARK: - Decay Curve (base lambda, 0 correct)

    func test_decay_1day_approximately95percent() {
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-1 * 24 * 3600)
        let effective = MasteryCalculator.effectiveScore(
            rawScore: 0.90,
            correctAttempts: 0,
            lastAttemptDate: oneDayAgo,
            referenceDate: now
        )
        // Base prior = 2/3 ≈ 0.667. Raw = 0.90.
        // Retention at 1 day ≈ 0.961
        // effective = 0.667 + (0.90 - 0.667) * 0.961 ≈ 0.891
        let expected = MasteryCalculator.priorScore + (0.90 - MasteryCalculator.priorScore) * exp(-MasteryCalculator.baseLambda * 1)
        XCTAssertEqual(effective, expected, accuracy: 0.001)
    }

    func test_decay_7days_approximately76percent() {
        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)
        let effective = MasteryCalculator.effectiveScore(
            rawScore: 0.90,
            correctAttempts: 0,
            lastAttemptDate: sevenDaysAgo,
            referenceDate: now
        )
        let retention = exp(-MasteryCalculator.baseLambda * 7)
        let expected = MasteryCalculator.priorScore + (0.90 - MasteryCalculator.priorScore) * retention
        XCTAssertEqual(effective, expected, accuracy: 0.001)
        // Should be noticeably decayed from 0.90
        XCTAssertLessThan(effective, 0.90)
        XCTAssertGreaterThan(effective, MasteryCalculator.priorScore)
    }

    func test_decay_14days() {
        let now = Date()
        let fourteenDaysAgo = now.addingTimeInterval(-14 * 24 * 3600)
        let effective = MasteryCalculator.effectiveScore(
            rawScore: 0.90,
            correctAttempts: 0,
            lastAttemptDate: fourteenDaysAgo,
            referenceDate: now
        )
        let retention = exp(-MasteryCalculator.baseLambda * 14)
        let expected = MasteryCalculator.priorScore + (0.90 - MasteryCalculator.priorScore) * retention
        XCTAssertEqual(effective, expected, accuracy: 0.001)
    }

    func test_decay_30days_approximately30percent_retention() {
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 3600)
        let effective = MasteryCalculator.effectiveScore(
            rawScore: 0.90,
            correctAttempts: 0,
            lastAttemptDate: thirtyDaysAgo,
            referenceDate: now
        )
        // After 30 days with 0 correct, retention ≈ 0.30
        // effective ≈ prior + (raw - prior) * 0.30 ≈ 0.667 + 0.233 * 0.30 ≈ 0.737
        let retention = exp(-MasteryCalculator.baseLambda * 30)
        XCTAssertEqual(retention, 0.30, accuracy: 0.01) // Verify base retention
        let expected = MasteryCalculator.priorScore + (0.90 - MasteryCalculator.priorScore) * retention
        XCTAssertEqual(effective, expected, accuracy: 0.001)
    }

    // MARK: - Durability (more correct = slower decay)

    func test_moreCorrectDecaysSlower() {
        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)

        let few = MasteryCalculator.effectiveScore(
            rawScore: 0.90, correctAttempts: 3,
            lastAttemptDate: sevenDaysAgo, referenceDate: now
        )
        let many = MasteryCalculator.effectiveScore(
            rawScore: 0.90, correctAttempts: 20,
            lastAttemptDate: sevenDaysAgo, referenceDate: now
        )
        let lots = MasteryCalculator.effectiveScore(
            rawScore: 0.90, correctAttempts: 50,
            lastAttemptDate: sevenDaysAgo, referenceDate: now
        )

        XCTAssertLessThan(few, many, "More correct recalls should decay slower")
        XCTAssertLessThan(many, lots, "Even more correct recalls should decay even slower")
    }

    func test_highCorrectCount_retainsMoreAt30Days() {
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 3600)

        let baseline = MasteryCalculator.effectiveScore(
            rawScore: 0.90, correctAttempts: 0,
            lastAttemptDate: thirtyDaysAgo, referenceDate: now
        )
        let wellPracticed = MasteryCalculator.effectiveScore(
            rawScore: 0.90, correctAttempts: 50,
            lastAttemptDate: thirtyDaysAgo, referenceDate: now
        )

        XCTAssertGreaterThan(wellPracticed, baseline + 0.05,
                              "50 correct recalls should retain significantly more after 30 days")
    }

    // MARK: - Edge Cases

    func test_noLastAttemptDate_returnsPrior() {
        let effective = MasteryCalculator.effectiveScore(
            rawScore: 0.90, correctAttempts: 10,
            lastAttemptDate: nil, referenceDate: Date()
        )
        XCTAssertEqual(effective, MasteryCalculator.priorScore, accuracy: 0.001)
    }

    func test_justPracticed_returnsRawScore() {
        let now = Date()
        let effective = MasteryCalculator.effectiveScore(
            rawScore: 0.85, correctAttempts: 10,
            lastAttemptDate: now, referenceDate: now
        )
        XCTAssertEqual(effective, 0.85, accuracy: 0.001)
    }

    func test_decayNeverBelowPrior() {
        let now = Date()
        let veryOld = now.addingTimeInterval(-365 * 24 * 3600) // 1 year ago
        let effective = MasteryCalculator.effectiveScore(
            rawScore: 0.90, correctAttempts: 0,
            lastAttemptDate: veryOld, referenceDate: now
        )
        XCTAssertGreaterThanOrEqual(effective, MasteryCalculator.priorScore - 0.001,
                                     "Score should never decay below the Bayesian prior")
    }

    func test_lowRawScore_decaysTowardPrior() {
        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)
        // Raw score below prior — decay should push it TOWARD prior (up, not down)
        let effective = MasteryCalculator.effectiveScore(
            rawScore: 0.40, correctAttempts: 5,
            lastAttemptDate: sevenDaysAgo, referenceDate: now
        )
        // 0.40 is below prior (0.667), so decay toward prior means score goes UP
        XCTAssertGreaterThan(effective, 0.40,
                              "Score below prior should decay upward toward prior")
        XCTAssertLessThanOrEqual(effective, MasteryCalculator.priorScore,
                                  "Should not exceed prior")
    }

    // MARK: - MasteryScore.effectiveScore property

    func test_masteryScore_effectiveScore_property() {
        let score = MasteryScore(note: .c, stringNumber: 4)
        score.totalAttempts = 10
        score.correctAttempts = 8
        score.lastAttemptDate = Date().addingTimeInterval(-7 * 24 * 3600)

        let effective = score.effectiveScore
        let raw = score.score
        XCTAssertLessThan(effective, raw, "Effective score after 7 days should be less than raw")
        XCTAssertGreaterThan(effective, MasteryCalculator.priorScore, "Should be above prior")
    }

    func test_masteryScore_effectiveScore_nilDate() {
        let score = MasteryScore(note: .c, stringNumber: 4)
        score.totalAttempts = 10
        score.correctAttempts = 8
        // lastAttemptDate is nil
        XCTAssertEqual(score.effectiveScore, MasteryCalculator.priorScore, accuracy: 0.001)
    }
}
