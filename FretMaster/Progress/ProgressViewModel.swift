// ProgressViewModel.swift
// FretMaster — Presentation Layer (Phase 4)

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretmaster", category: "ProgressViewModel")

// MARK: - AccuracyDataPoint

public struct AccuracyDataPoint: Identifiable {
    public let id: UUID = UUID()
    public let date: Date
    public let accuracy: Double   // 0.0 – 1.0
    public let sessionCount: Int
}

// MARK: - CellDetail

public struct CellDetail: Identifiable {
    public let id: UUID = UUID()
    public let note: MusicalNote
    public let string: Int
    public let score: MasteryScore?
    public let recentAttempts: [Attempt]
}

// MARK: - SessionDetail

public struct SessionDetail: Identifiable {
    public let id: UUID
    public let session: Session
    public let attempts: [Attempt]
}

// MARK: - ProgressViewModel

@MainActor
@Observable
public final class ProgressViewModel {

    public private(set) var scoreGrid: [[Int: MasteryScore]] = Array(repeating: [:], count: 7)
    public private(set) var overallMastery: Double = 0
    public private(set) var attemptedCells: Int = 0
    public private(set) var masteredCells: Int = 0
    public private(set) var recentSessions: [Session] = []
    public private(set) var accuracyTrend: [AccuracyDataPoint] = []
    public private(set) var isLoading: Bool = false
    public var selectedCell: CellDetail? = nil
    public var selectedSession: SessionDetail? = nil

    private let masteryRepository: any MasteryRepository
    private let sessionRepository: any SessionRepository
    private let attemptRepository: any AttemptRepository

    public init(
        masteryRepository: any MasteryRepository,
        sessionRepository: any SessionRepository,
        attemptRepository: any AttemptRepository
    ) {
        self.masteryRepository = masteryRepository
        self.sessionRepository = sessionRepository
        self.attemptRepository = attemptRepository
    }

    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let allScores = try masteryRepository.allScores()
            var grid: [[Int: MasteryScore]] = Array(repeating: [:], count: 7)
            for score in allScores {
                guard (1...6).contains(score.stringNumber) else { continue }
                grid[score.stringNumber][score.noteRaw] = score
            }
            scoreGrid = grid
            overallMastery = MasteryCalculator.overallScore(from: allScores)
            attemptedCells = allScores.filter { $0.totalAttempts > 0 }.count
            masteredCells  = allScores.filter { $0.isMastered }.count
            recentSessions = try sessionRepository.recentSessions(limit: 20)
            accuracyTrend  = Self.buildAccuracyTrend(from: recentSessions)
        } catch {
            logger.error("ProgressViewModel load failed: \(error)")
        }
    }

    // MARK: - Accuracy Trend Builder

    /// Groups completed sessions by calendar day and averages accuracy per day,
    /// returning the most recent 30 days that have at least one session.
    static func buildAccuracyTrend(from sessions: [Session]) -> [AccuracyDataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions.filter { $0.isCompleted && $0.attemptCount > 0 }) { session in
            calendar.startOfDay(for: session.startTime)
        }
        let points = grouped.map { (day, daySessions) -> AccuracyDataPoint in
            let totalAttempts = daySessions.reduce(0) { $0 + $1.attemptCount }
            let totalCorrect  = daySessions.reduce(0) { $0 + $1.correctCount }
            let accuracy = totalAttempts > 0 ? Double(totalCorrect) / Double(totalAttempts) : 0
            return AccuracyDataPoint(date: day, accuracy: accuracy, sessionCount: daySessions.count)
        }
        return points
            .sorted { $0.date < $1.date }
            .suffix(30)
    }

    public func selectSession(_ session: Session) {
        let attempts = (try? attemptRepository.attempts(forSession: session.id)) ?? []
        selectedSession = SessionDetail(id: session.id, session: session, attempts: attempts)
    }

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

    public func masteryScore(note: MusicalNote, string: Int) -> Double {
        scoreGrid[string][note.rawValue]?.score
            ?? (MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta))
    }

    public func masteryLevel(note: MusicalNote, string: Int) -> MasteryLevel {
        MasteryLevel.from(score: masteryScore(note: note, string: string))
    }

    // MARK: - Deletion

    /// Deletes a single session, removes its attempts, rebuilds mastery from
    /// all remaining attempts, then refreshes the displayed data.
    public func deleteSession(_ session: Session) async {
        do {
            // 1. Remove the session's attempts.
            try attemptRepository.deleteAttempts(forSession: session.id)
            // 2. Remove the session itself.
            try sessionRepository.delete(session)
            // 3. Rebuild mastery scores from all remaining attempts.
            let allAttempts = try fetchAllAttempts()
            try masteryRepository.rebuild(from: allAttempts)
            // 4. Reload the UI.
            await load()
        } catch {
            logger.error("Failed to delete session: \(error)")
        }
    }

    /// Deletes all sessions and their attempts, rebuilds mastery (will be empty),
    /// then refreshes.
    public func deleteAllSessions() async {
        do {
            try sessionRepository.deleteAll()
            try attemptRepository.deleteAll()
            try masteryRepository.rebuild(from: [])
            await load()
        } catch {
            logger.error("Failed to delete all sessions: \(error)")
        }
    }

    /// Deletes all sessions, attempts, and mastery scores outright (full reset).
    public func deleteAllSessionsAndScores() async {
        do {
            try sessionRepository.deleteAll()
            try attemptRepository.deleteAll()
            try masteryRepository.deleteAll()
            await load()
        } catch {
            logger.error("Failed to reset all data: \(error)")
        }
    }

    /// Fetches every Attempt record across all notes and strings.
    /// Used when we need the full corpus to rebuild mastery after a deletion.
    private func fetchAllAttempts() throws -> [Attempt] {
        // Fetch all 12 notes × 6 strings = up to 72 cells; union the results.
        var all: [Attempt] = []
        for note in MusicalNote.allCases {
            let batch = try attemptRepository.attempts(forNote: note, limit: nil)
            all.append(contentsOf: batch)
        }
        return all
    }

    public static let totalCells: Int = 72
}
