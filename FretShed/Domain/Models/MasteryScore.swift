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
