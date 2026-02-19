// ProgressViewModel.swift
// FretMaster — Presentation Layer (Phase 4)
//
// Drives the Progress tab: heatmap data, overall mastery, session history,
// and per-cell drill-down details. All data is loaded once on `.task` and
// refreshed whenever the view re-appears.

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretmaster", category: "ProgressViewModel")

// MARK: - CellDetail

/// All the data needed for the per-cell sheet.
public struct CellDetail: Identifiable {
    public let id: UUID = UUID()
    public let note: MusicalNote
    public let string: Int
    public let score: MasteryScore?          // nil → never attempted
    public let recentAttempts: [Attempt]
}

// MARK: - ProgressViewModel

@MainActor
@Observable
public final class ProgressViewModel {

    // MARK: - Public State

    /// Scores keyed by [stringNumber][noteRawValue]. Missing key → never attempted.
    public private(set) var scoreGrid: [[Int: MasteryScore]] = Array(
        repeating: [:], count: 7  // index 1–6; index 0 unused
    )

    /// Weighted overall mastery across all attempted cells (0–1).
    public private(set) var overallMastery: Double = 0

    /// Total cells that have been attempted at least once.
    public private(set) var attemptedCells: Int = 0

    /// Total cells that meet the "mastered" threshold.
    public private(set) var masteredCells: Int = 0

    /// Completed sessions, newest first.
    public private(set) var recentSessions: [Session] = []

    /// Whether a data load is in progress.
    public private(set) var isLoading: Bool = false

    /// Non-nil when a cell has been tapped and the detail sheet should show.
    public var selectedCell: CellDetail? = nil

    // MARK: - Private

    private let masteryRepository: any MasteryRepository
    private let sessionRepository: any SessionRepository
    private let attemptRepository: any AttemptRepository

    // MARK: - Init

    public init(
        masteryRepository: any MasteryRepository,
        sessionRepository: any SessionRepository,
        attemptRepository: any AttemptRepository
    ) {
        self.masteryRepository = masteryRepository
        self.sessionRepository = sessionRepository
        self.attemptRepository = attemptRepository
    }

    // MARK: - Load

    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Mastery scores → rebuild the grid
            let allScores = try masteryRepository.allScores()
            var grid: [[Int: MasteryScore]] = Array(repeating: [:], count: 7)
            for score in allScores {
                guard (1...6).contains(score.stringNumber) else { continue }
                grid[score.stringNumber][score.noteRaw] = score
            }
            scoreGrid = grid

            // 2. Summary statistics
            overallMastery = MasteryCalculator.overallScore(from: allScores)
            attemptedCells = allScores.filter { $0.totalAttempts > 0 }.count
            masteredCells  = allScores.filter { $0.isMastered }.count

            // 3. Recent sessions (last 20)
            recentSessions = try sessionRepository.recentSessions(limit: 20)

        } catch {
            logger.error("ProgressViewModel load failed: \(error)")
        }
    }

    // MARK: - Cell tap

    public func selectCell(note: MusicalNote, string: Int) async {
        let score = scoreGrid[string][note.rawValue]
        let attempts: [Attempt]
        do {
            attempts = try attemptRepository.attempts(forNote: note, string: string, limit: 10)
        } catch {
            logger.error("Failed to load attempts for cell: \(error)")
            attempts = []
        }
        selectedCell = CellDetail(note: note, string: string, score: score, recentAttempts: attempts)
    }

    // MARK: - Helpers

    /// The mastery score (0–1) for a given (note, string) cell, or the Bayesian prior if unplayed.
    public func masteryScore(note: MusicalNote, string: Int) -> Double {
        scoreGrid[string][note.rawValue]?.score
            ?? (MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta))
    }

    /// The `MasteryLevel` tier for a given cell.
    public func masteryLevel(note: MusicalNote, string: Int) -> MasteryLevel {
        MasteryLevel.from(score: masteryScore(note: note, string: string))
    }

    /// Total number of cells on the fretboard (12 notes × 6 strings).
    public static let totalCells: Int = 72
}
