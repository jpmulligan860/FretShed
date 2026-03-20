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
/// - "Mastered"   : mastery ≥ 0.75 AND spacing gate complete (3 checkpoints across days)
/// - "Struggling" : mastery < 0.50 AND total ≥ 5
@Model
public final class MasteryScore {

    // MARK: Bayesian Prior Constants

    /// Prior correct count (α). Provides slight optimism on first attempts.
    public static let alpha: Double = 2
    /// Prior incorrect count (β).
    public static let beta: Double = 1

    // MARK: Thresholds

    public static let masteredThreshold: Double = 0.75
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

    // MARK: Spacing Gate Checkpoint Dates

    /// Date when proficient-level accuracy was first demonstrated (CP1).
    public var spacingCheckpoint1Date: Date?

    /// Date when proficient accuracy was demonstrated in a different session,
    /// 1+ calendar day after CP1 (CP2).
    public var spacingCheckpoint2Date: Date?

    /// Date when proficient accuracy was demonstrated in a different session,
    /// 3+ calendar days after CP2 (CP3).
    public var spacingCheckpoint3Date: Date?

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

    /// `true` when at least one spacing checkpoint has been set but not all three.
    /// These notes benefit most from being re-tested at a time gap.
    public var hasActiveCheckpointProgression: Bool {
        spacingCheckpoint1Date != nil && !hasCompletedSpacingGate
    }

    /// `true` when all 3 spacing checkpoints have been satisfied,
    /// proving durable long-term memory through spaced recall.
    public var hasCompletedSpacingGate: Bool {
        spacingCheckpoint1Date != nil
            && spacingCheckpoint2Date != nil
            && spacingCheckpoint3Date != nil
    }

    /// `true` when the mastery threshold has been sustainably reached
    /// AND all spacing checkpoints are complete.
    /// The spacing gate (3 successful recalls across 5+ days) replaces the
    /// old attempt-count gate — you can't luck your way through spaced repetition.
    public var isMastered: Bool {
        score >= Self.masteredThreshold && hasCompletedSpacingGate
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

    /// Minimum attempts on a cell before checkpoint advancement can begin.
    /// Ensures the Bayesian score has enough data to be meaningful (matches
    /// the phase advancement `minimumAttempts` threshold).
    public static let checkpointMinAttempts: Int = 3

    /// Attempts to advance the spacing gate checkpoint for this cell.
    /// Call after a session completes for each quizzed cell whose score is at proficient level.
    /// Uses calendar days (not raw hours) to enforce minimum gaps.
    /// - Parameter today: The current date (injectable for testing).
    /// - Returns: The checkpoint number advanced (1, 2, or 3), or nil if no advancement.
    @discardableResult
    public func tryAdvanceCheckpoint(today: Date = Date()) -> Int? {
        guard score >= Self.masteredThreshold else { return nil }
        guard totalAttempts >= Self.checkpointMinAttempts else { return nil }
        guard !hasCompletedSpacingGate else { return nil }

        let calendar = Calendar.current

        if spacingCheckpoint1Date == nil {
            spacingCheckpoint1Date = today
            return 1
        }

        if spacingCheckpoint2Date == nil, let cp1 = spacingCheckpoint1Date {
            let daysSinceCP1 = calendar.dateComponents([.day], from: cp1, to: today).day ?? 0
            if daysSinceCP1 >= 1 {
                spacingCheckpoint2Date = today
                return 2
            }
            return nil
        }

        if spacingCheckpoint3Date == nil, let cp2 = spacingCheckpoint2Date {
            let daysSinceCP2 = calendar.dateComponents([.day], from: cp2, to: today).day ?? 0
            if daysSinceCP2 >= 3 {
                spacingCheckpoint3Date = today
                return 3
            }
            return nil
        }

        return nil
    }

    /// Regresses spacing checkpoint progress by one step on incorrect answer.
    /// CP2 earned → drops to CP1 only. CP1 earned → drops to nil.
    /// Does nothing if the spacing gate is already complete (all 3 checkpoints met).
    /// Rationale: a single error after 2 successful spaced recalls is more likely
    /// a performance error than genuine forgetting — preserve prior evidence.
    public func regressSpacingCheckpoint() {
        guard !hasCompletedSpacingGate else { return }
        if spacingCheckpoint2Date != nil {
            // Had CP1 + CP2 → drop CP2, keep CP1
            spacingCheckpoint2Date = nil
        } else if spacingCheckpoint1Date != nil {
            // Had CP1 only → drop CP1
            spacingCheckpoint1Date = nil
        }
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
