// MasteryScore.swift
// FretShed — Domain Layer
//
// Tracks the Bayesian mastery score for a single (note, string) cell.

import Foundation
import SwiftData

// MARK: - MasteryScore

/// Tracks the Bayesian-smoothed accuracy for a single `(note, string)` combination.
///
/// Uses the formula:  mastery = (correct + α) / (total + α + β)
/// where α = 2 (slight optimism prior) and β = 1.
///
/// Thresholds:
/// - "Mastered"   : mastery ≥ 0.90 AND total ≥ 15
/// - "Struggling" : mastery < 0.50 AND total ≥ 5
@Model
public final class MasteryScore {

    // MARK: Bayesian Prior Constants

    /// Prior correct count (α). Provides slight optimism on first attempts.
    public static let alpha: Double = 2
    /// Prior incorrect count (β).
    public static let beta: Double = 1

    // MARK: Thresholds

    public static let masteredThreshold: Double = 0.90
    public static let masteredMinAttempts: Int = 15
    public static let strugglingThreshold: Double = 0.50
    public static let strugglingMinAttempts: Int = 5

    // MARK: Stored Properties

    @Attribute(.unique) public var id: UUID
    public var noteRaw: Int               // MusicalNote.rawValue
    public var stringNumber: Int          // 1–6
    public var totalAttempts: Int
    public var correctAttempts: Int
    public var lastAttemptDate: Date?
    public var bestStreakCount: Int

    // MARK: Computed Properties

    /// The note this score tracks.
    public var note: MusicalNote {
        get { MusicalNote(rawValue: noteRaw) ?? .c }
        set { noteRaw = newValue.rawValue }
    }

    /// Bayesian-smoothed mastery score in the range [0, 1].
    public var score: Double {
        let numerator = Double(correctAttempts) + Self.alpha
        let denominator = Double(totalAttempts) + Self.alpha + Self.beta
        return numerator / denominator
    }

    /// Effective mastery score with temporal decay applied.
    /// Cells practiced recently retain their score; cells not practiced decay toward the prior.
    /// Cells with more correct recalls decay slower (stronger memories are more durable).
    public var effectiveScore: Double {
        MasteryCalculator.effectiveScore(
            rawScore: score,
            correctAttempts: correctAttempts,
            lastAttemptDate: lastAttemptDate
        )
    }

    /// `true` when the mastery threshold has been sustainably reached.
    public var isMastered: Bool {
        score >= Self.masteredThreshold && totalAttempts >= Self.masteredMinAttempts
    }

    /// `true` when the user appears to be struggling with this cell.
    public var isStruggling: Bool {
        score < Self.strugglingThreshold && totalAttempts >= Self.strugglingMinAttempts
    }

    // MARK: Initializer

    public init(
        id: UUID = UUID(),
        note: MusicalNote,
        stringNumber: Int
    ) {
        self.id = id
        self.noteRaw = note.rawValue
        self.stringNumber = stringNumber
        self.totalAttempts = 0
        self.correctAttempts = 0
        self.lastAttemptDate = nil
        self.bestStreakCount = 0
    }

    // MARK: Mutation

    /// Records one more attempt for this cell.
    /// - Parameter wasCorrect: Whether the user identified the note correctly.
    public func record(wasCorrect: Bool) {
        totalAttempts += 1
        if wasCorrect { correctAttempts += 1 }
        lastAttemptDate = Date()
    }

    /// Updates the best streak if `streakCount` exceeds the previous record.
    public func updateBestStreak(_ streakCount: Int) {
        bestStreakCount = max(bestStreakCount, streakCount)
    }
}

// MARK: - MasteryCalculator

/// Pure computation helper for Bayesian mastery scores.
/// All methods are static and free of side effects for easy unit testing.
public enum MasteryCalculator {

    /// Computes the Bayesian mastery score from raw counts.
    /// - Parameters:
    ///   - correct: Number of correct attempts.
    ///   - total: Total number of attempts.
    /// - Returns: Smoothed score in [0, 1].
    public static func score(correct: Int, total: Int) -> Double {
        let numerator = Double(correct) + MasteryScore.alpha
        let denominator = Double(total) + MasteryScore.alpha + MasteryScore.beta
        return numerator / denominator
    }

    // MARK: - Temporal Decay

    /// Base decay rate (lambda). Tuned so that after 30 days with no practice,
    /// a baseline cell retains ~30% of its score.
    /// Decay curve: retention = exp(-lambda * days)
    ///   1 day: ~96%,  3 days: ~89%,  7 days: ~76%,  14 days: ~57%,  30 days: ~30%
    public static let baseLambda: Double = 0.0401

    /// Durability modifier scale. Higher correct count → slower decay.
    /// effectiveLambda = baseLambda / (1 + durabilityScale * correctCount)
    public static let durabilityScale: Double = 0.05

    /// The prior score for a cell with no data (alpha / (alpha + beta)).
    public static let priorScore: Double = MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta)

    /// Computes the effective (decayed) mastery score.
    /// - Parameters:
    ///   - rawScore: The stored Bayesian mastery score (0–1).
    ///   - correctAttempts: Total correct answers for this cell (modifies decay rate).
    ///   - lastAttemptDate: When the cell was last practiced. Nil = use prior.
    ///   - referenceDate: The current date (injectable for testing).
    /// - Returns: Effective score in [0, 1], decayed toward the prior.
    public static func effectiveScore(
        rawScore: Double,
        correctAttempts: Int,
        lastAttemptDate: Date?,
        referenceDate: Date = Date()
    ) -> Double {
        guard let lastDate = lastAttemptDate else {
            // Never practiced — return the prior
            return priorScore
        }

        let daysSince = referenceDate.timeIntervalSince(lastDate) / (24 * 3600)
        guard daysSince > 0 else { return rawScore }

        // More correct recalls = slower decay
        let effectiveLambda = baseLambda / (1.0 + durabilityScale * Double(max(0, correctAttempts)))
        let retention = exp(-effectiveLambda * daysSince)

        // Decay toward the prior, not toward zero
        return priorScore + (rawScore - priorScore) * retention
    }

    /// Weighted average mastery across multiple cells.
    /// Cells with more attempts carry more weight.
    /// - Parameter scores: Array of `MasteryScore` objects.
    /// - Returns: Weighted average in [0, 1], or 0 for an empty array.
    public static func overallScore(from scores: [MasteryScore]) -> Double {
        guard !scores.isEmpty else { return 0 }
        let totalWeight = scores.reduce(0) { $0 + Double($1.totalAttempts) }
        guard totalWeight > 0 else {
            // No attempts yet — return the prior (α / (α + β))
            return MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta)
        }
        let weightedSum = scores.reduce(0.0) { acc, ms in
            acc + ms.score * Double(ms.totalAttempts)
        }
        return weightedSum / totalWeight
    }
}
