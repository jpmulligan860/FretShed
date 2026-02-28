// ProgressViewModel.swift
// FretShed — Presentation Layer (Phase 4)

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "ProgressViewModel")

// MARK: - AccuracyDataPoint

public struct AccuracyDataPoint: Identifiable {
    public let id: UUID = UUID()
    public let date: Date
    public let accuracy: Double   // 0.0 – 1.0
    public let sessionCount: Int
}

// MARK: - ResponseTimeDataPoint

public struct ResponseTimeDataPoint: Identifiable {
    public let id: UUID = UUID()
    public let date: Date
    public let avgTimeMs: Double   // average response time in ms
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

    /// Unique mastered note+string pairs from scoreGrid.
    public var masteredCells: Int {
        scoreGrid.reduce(0) { total, stringScores in
            total + stringScores.values.filter { $0.isMastered }.count
        }
    }

    /// Counts mastered cells as they appear on the visible heatmap, walking
    /// every fret so that octave-repeat frets are counted (matches what the user sees).
    public func visibleMasteredCells(fretboardMap: FretboardMap, fretCount: Int) -> Int {
        var count = 0
        for string in 1...6 {
            for fret in 0...fretCount {
                guard let note = fretboardMap.note(string: string, fret: fret),
                      let score = scoreGrid[string][note.rawValue],
                      score.isMastered else { continue }
                count += 1
            }
        }
        return count
    }
    public private(set) var recentSessions: [Session] = []
    public private(set) var accuracyTrend: [AccuracyDataPoint] = []
    public private(set) var responseTimeTrend: [ResponseTimeDataPoint] = []
    public private(set) var currentStreak: Int = 0
    public private(set) var isLoading: Bool = false
    public private(set) var loadFailed: Bool = false
    public var selectedCell: CellDetail? = nil
    public var selectedSession: SessionDetail? = nil
    public var todayFilter: Bool = false {
        didSet { recalculateForFilter() }
    }
    public var focusModeFilter: FocusMode? = nil {
        didSet { recalculateForFilter() }
    }
    public var gameModeFilter: GameMode? = nil {
        didSet { recalculateForFilter() }
    }

    public var isAnyFilterActive: Bool {
        todayFilter || focusModeFilter != nil || gameModeFilter != nil
    }

    public var filteredSessions: [Session] {
        var result = recentSessions
        if todayFilter {
            let startOfToday = Calendar.current.startOfDay(for: Date())
            result = result.filter { $0.startTime >= startOfToday }
        }
        if let focus = focusModeFilter {
            result = result.filter { $0.focusMode == focus }
        }
        if let game = gameModeFilter {
            result = result.filter { $0.gameMode == game }
        }
        return result
    }

    // Base (unfiltered) cache — restored when filter is cleared
    private var baseScoreGrid: [[Int: MasteryScore]] = Array(repeating: [:], count: 7)
    private var baseOverallMastery: Double = 0
    private var baseAttemptedCells: Int = 0
    private var baseAccuracyTrend: [AccuracyDataPoint] = []
    private var baseResponseTimeTrend: [ResponseTimeDataPoint] = []
    private var baseCurrentStreak: Int = 0

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
        loadFailed = false
        defer { isLoading = false }
        do {
            let allScores = try masteryRepository.allScores()
            var grid: [[Int: MasteryScore]] = Array(repeating: [:], count: 7)
            for score in allScores {
                guard (1...6).contains(score.stringNumber) else { continue }
                grid[score.stringNumber][score.noteRaw] = score
            }
            scoreGrid = grid
            baseScoreGrid = grid
            overallMastery = MasteryCalculator.overallScore(from: allScores)
            baseOverallMastery = overallMastery
            attemptedCells = allScores.filter { $0.totalAttempts > 0 }.count
            baseAttemptedCells = attemptedCells
            recentSessions = try sessionRepository.recentSessions(limit: 50)
            accuracyTrend  = Self.buildAccuracyTrend(from: recentSessions)
            baseAccuracyTrend = accuracyTrend
            responseTimeTrend = buildResponseTimeTrend(from: recentSessions)
            baseResponseTimeTrend = responseTimeTrend
            currentStreak = Self.calculateStreak(from: recentSessions)
            baseCurrentStreak = currentStreak

            // Re-apply active filter if one exists
            if isAnyFilterActive {
                recalculateForFilter()
            }
        } catch {
            loadFailed = true
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

    // MARK: - Streak Calculation

    /// Counts consecutive calendar days with at least one completed session,
    /// walking backwards from today. If no session exists today, checks from
    /// yesterday (user may not have practiced yet today).
    static func calculateStreak(from sessions: [Session]) -> Int {
        let calendar = Calendar.current
        let practiceDays: Set<Date> = Set(
            sessions
                .filter { $0.isCompleted }
                .map { calendar.startOfDay(for: $0.startTime) }
        )
        guard !practiceDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        var checkDate = today

        // If no session today, try starting from yesterday
        if !practiceDays.contains(today) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if practiceDays.contains(yesterday) {
                checkDate = yesterday
            } else {
                return 0
            }
        }

        var streak = 0
        while practiceDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    // MARK: - Response Time Trend Builder

    /// Groups completed *timed* sessions by calendar day and averages the
    /// per-session mean response time (correct answers only) per day.
    /// Returns the most recent 30 days that have at least one qualifying session.
    func buildResponseTimeTrend(from sessions: [Session]) -> [ResponseTimeDataPoint] {
        let calendar = Calendar.current
        let timedSessions = sessions.filter { $0.isCompleted && $0.gameMode == .timed }
        guard !timedSessions.isEmpty else { return [] }

        // Compute per-session average response time (correct answers only).
        struct SessionAvg {
            let date: Date
            let avgMs: Double
        }
        var sessionAverages: [SessionAvg] = []
        for session in timedSessions {
            guard let attempts = try? attemptRepository.attempts(forSession: session.id) else { continue }
            let correctTimes = attempts.filter { $0.wasCorrect }.map { $0.responseTimeMs }
            guard !correctTimes.isEmpty else { continue }
            let avg = Double(correctTimes.reduce(0, +)) / Double(correctTimes.count)
            sessionAverages.append(SessionAvg(date: session.startTime, avgMs: avg))
        }

        // Group by calendar day and average the per-session averages.
        let grouped = Dictionary(grouping: sessionAverages) { avg in
            calendar.startOfDay(for: avg.date)
        }
        let points = grouped.map { (day, dayAverages) -> ResponseTimeDataPoint in
            let mean = dayAverages.map(\.avgMs).reduce(0, +) / Double(dayAverages.count)
            return ResponseTimeDataPoint(date: day, avgTimeMs: mean, sessionCount: dayAverages.count)
        }
        return points
            .sorted { $0.date < $1.date }
            .suffix(30)
    }

    // MARK: - Filter Recalculation

    /// Recalculates charts, heatmap, and overall stats from filtered sessions.
    /// When the filter is cleared, restores base (unfiltered) data.
    private func recalculateForFilter() {
        // Streak always reflects all sessions regardless of filter
        currentStreak = baseCurrentStreak

        guard isAnyFilterActive else {
            // No filter — restore base data
            scoreGrid = baseScoreGrid
            overallMastery = baseOverallMastery
            attemptedCells = baseAttemptedCells
            accuracyTrend = baseAccuracyTrend
            responseTimeTrend = baseResponseTimeTrend
            return
        }

        let sessions = filteredSessions
        accuracyTrend = Self.buildAccuracyTrend(from: sessions)
        responseTimeTrend = buildResponseTimeTrend(from: sessions)

        // Rebuild scoreGrid from filtered session attempts
        let (grid, scores) = buildFilteredScoreGrid(from: sessions)
        scoreGrid = grid
        overallMastery = MasteryCalculator.overallScore(from: scores)
        attemptedCells = scores.filter { $0.totalAttempts > 0 }.count
    }

    /// Builds a transient scoreGrid from attempts in the given sessions only.
    private func buildFilteredScoreGrid(from sessions: [Session]) -> ([[Int: MasteryScore]], [MasteryScore]) {
        var allAttempts: [Attempt] = []
        for session in sessions where session.isCompleted {
            if let attempts = try? attemptRepository.attempts(forSession: session.id) {
                allAttempts.append(contentsOf: attempts)
            }
        }

        struct Key: Hashable { let noteRaw: Int; let stringNumber: Int }
        var totals: [Key: Int] = [:]
        var corrects: [Key: Int] = [:]
        for attempt in allAttempts {
            let key = Key(noteRaw: attempt.targetNoteRaw, stringNumber: attempt.targetString)
            totals[key, default: 0] += 1
            if attempt.wasCorrect { corrects[key, default: 0] += 1 }
        }

        var grid: [[Int: MasteryScore]] = Array(repeating: [:], count: 7)
        var scores: [MasteryScore] = []
        for (key, total) in totals {
            guard let note = MusicalNote(rawValue: key.noteRaw),
                  (1...6).contains(key.stringNumber) else { continue }
            let score = MasteryScore(note: note, stringNumber: key.stringNumber)
            score.totalAttempts = total
            score.correctAttempts = corrects[key, default: 0]
            grid[key.stringNumber][key.noteRaw] = score
            scores.append(score)
        }
        return (grid, scores)
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
        let score = scoreGrid[string][note.rawValue]
        let value = score?.score ?? (MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta))
        return MasteryLevel.from(score: value, isMastered: score?.isMastered ?? false)
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
