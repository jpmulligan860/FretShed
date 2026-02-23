//
//  ProgressViewModelTests.swift
//  FretShed
//
//  Created by John Mulligan on 2/15/26.
//


// ProgressViewModelTests.swift
// FretShed — Unit Tests (Phase 4)
//
// Tests the ProgressViewModel's data loading, grid construction,
// summary statistics, cell selection, and edge cases.
// Uses in-memory repositories — no disk I/O.

import XCTest
import SwiftData
@testable import FretShed

// MARK: - Helpers

@MainActor
private func makeVM(container: ModelContainer) -> ProgressViewModel {
    ProgressViewModel(
        masteryRepository: SwiftDataMasteryRepository(context: ModelContext(container)),
        sessionRepository: SwiftDataSessionRepository(context: ModelContext(container)),
        attemptRepository: SwiftDataAttemptRepository(context: ModelContext(container))
    )
}

/// Seeds a MasteryScore and matching Attempt records into the in-memory store.
@discardableResult
@MainActor
private func seedMasteryScore(
    note: MusicalNote,
    string: Int,
    correct: Int,
    total: Int,
    masteryRepo: SwiftDataMasteryRepository,
    attemptRepo: SwiftDataAttemptRepository,
    sessionID: UUID = UUID()
) throws -> MasteryScore {
    let score = try masteryRepo.score(forNote: note, string: string)
    for i in 0..<total {
        let wasCorrect = i < correct
        score.record(wasCorrect: wasCorrect)
        let attempt = Attempt(
            targetNote: note,
            targetString: string,
            targetFret: 0,
            playedNote: wasCorrect ? note : note.transposed(by: 1),
            playedString: string,
            responseTimeMs: 500,
            wasCorrect: wasCorrect,
            sessionID: sessionID,
            gameMode: .untimed,
            acceptedAnyString: false
        )
        try attemptRepo.save(attempt)
    }
    try masteryRepo.save(score)
    return score
}

/// Saves a completed Session into the in-memory store.
@MainActor
private func seedSession(
    focusMode: FocusMode = .fullFretboard,
    correct: Int = 10,
    total: Int = 20,
    secondsAgo: Double = 0,
    sessionRepo: SwiftDataSessionRepository
) throws {
    let session = Session(focusMode: focusMode, gameMode: .untimed)
    session.attemptCount = total
    session.correctCount = correct
    session.isCompleted = true
    session.startTime = Date(timeIntervalSinceNow: -(secondsAgo + 60))
    session.endTime   = Date(timeIntervalSinceNow: -secondsAgo)
    session.overallMasteryAtEnd = total > 0 ? Double(correct) / Double(total) : 0
    try sessionRepo.save(session)
}

// MARK: - ProgressViewModelTests

@MainActor
final class ProgressViewModelTests: XCTestCase {

    var container: ModelContainer!
    var masteryRepo: SwiftDataMasteryRepository!
    var sessionRepo: SwiftDataSessionRepository!
    var attemptRepo: SwiftDataAttemptRepository!

    override func setUp() async throws {
        try await super.setUp()
        container   = try makeModelContainer(inMemory: true)
        masteryRepo = SwiftDataMasteryRepository(context: ModelContext(container))
        sessionRepo = SwiftDataSessionRepository(context: ModelContext(container))
        attemptRepo = SwiftDataAttemptRepository(context: ModelContext(container))
    }

    override func tearDown() async throws {
        container   = nil
        masteryRepo = nil
        sessionRepo = nil
        attemptRepo = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isNotLoading() {
        let vm = makeVM(container: container)
        XCTAssertFalse(vm.isLoading)
    }

    func test_initialState_overallMasteryIsZero() {
        let vm = makeVM(container: container)
        XCTAssertEqual(vm.overallMastery, 0)
    }

    func test_initialState_gridHasSevenSlots() {
        // Index 0 unused; indices 1–6 for the six strings.
        let vm = makeVM(container: container)
        XCTAssertEqual(vm.scoreGrid.count, 7)
    }

    func test_initialState_noSelectedCell() {
        let vm = makeVM(container: container)
        XCTAssertNil(vm.selectedCell)
    }

    // MARK: - Load: Empty Store

    func test_load_emptyStore_overallMasteryIsZero() async throws {
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.overallMastery, 0)
    }

    func test_load_emptyStore_attemptedCellsIsZero() async throws {
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.attemptedCells, 0)
    }

    func test_load_emptyStore_masteredCellsIsZero() async throws {
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.masteredCells, 0)
    }

    func test_load_emptyStore_recentSessionsIsEmpty() async throws {
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertTrue(vm.recentSessions.isEmpty)
    }

    // MARK: - Load: Populated Store

    func test_load_withOneScore_appearsInGrid() async throws {
        try seedMasteryScore(note: .a, string: 2,
                             correct: 8, total: 10,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()

        let gridScore = vm.scoreGrid[2][MusicalNote.a.rawValue]
        XCTAssertNotNil(gridScore, "Score for (A, string 2) should appear in the grid")
        XCTAssertEqual(gridScore?.correctAttempts, 8)
        XCTAssertEqual(gridScore?.totalAttempts, 10)
    }

    func test_load_withMultipleScores_allAppearInGrid() async throws {
        let pairs: [(MusicalNote, Int)] = [(.c, 1), (.e, 3), (.g, 6)]
        for (note, string) in pairs {
            try seedMasteryScore(note: note, string: string,
                                 correct: 5, total: 10,
                                 masteryRepo: masteryRepo,
                                 attemptRepo: attemptRepo)
        }
        let vm = makeVM(container: container)
        await vm.load()

        for (note, string) in pairs {
            XCTAssertNotNil(vm.scoreGrid[string][note.rawValue],
                            "Expected score for (\(note), string \(string)) in grid")
        }
    }

    func test_load_attemptedCellsCount_matchesSeededScores() async throws {
        let pairs: [(MusicalNote, Int)] = [(.a, 1), (.b, 2), (.c, 3)]
        for (note, string) in pairs {
            try seedMasteryScore(note: note, string: string,
                                 correct: 3, total: 5,
                                 masteryRepo: masteryRepo,
                                 attemptRepo: attemptRepo)
        }
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.attemptedCells, 3)
    }

    func test_load_masteredCellsCount_onlyCountsMastered() async throws {
        // 15 correct → meets mastered threshold (score ≈ 0.944, attempts = 15)
        try seedMasteryScore(note: .a, string: 1,
                             correct: 15, total: 15,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        // 3 correct out of 10 → not mastered
        try seedMasteryScore(note: .b, string: 2,
                             correct: 3, total: 10,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.masteredCells, 1)
    }

    func test_load_overallMastery_isNonZeroWhenDataExists() async throws {
        try seedMasteryScore(note: .a, string: 1,
                             correct: 10, total: 10,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertGreaterThan(vm.overallMastery, 0)
    }

    func test_load_overallMastery_perfectScoreApproachesOne() async throws {
        for (note, string) in [(MusicalNote.a, 1), (.b, 2), (.c, 3)] {
            try seedMasteryScore(note: note, string: string,
                                 correct: 20, total: 20,
                                 masteryRepo: masteryRepo,
                                 attemptRepo: attemptRepo)
        }
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertGreaterThan(vm.overallMastery, 0.9)
    }

    // MARK: - Load: Sessions

    func test_load_recentSessions_appearsNewestFirst() async throws {
        try seedSession(correct: 5, total: 10, secondsAgo: 3600, sessionRepo: sessionRepo)
        try seedSession(correct: 9, total: 10, secondsAgo: 60,   sessionRepo: sessionRepo)

        let vm = makeVM(container: container)
        await vm.load()

        XCTAssertEqual(vm.recentSessions.count, 2)
        let first  = try XCTUnwrap(vm.recentSessions.first)
        let second = try XCTUnwrap(vm.recentSessions.last)
        XCTAssertGreaterThan(first.startTime, second.startTime,
                             "Most recent session should come first")
    }

    func test_load_recentSessions_limitedTo50() async throws {
        for i in 0..<60 {
            try seedSession(secondsAgo: Double(i * 60), sessionRepo: sessionRepo)
        }
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertLessThanOrEqual(vm.recentSessions.count, 50)
    }

    func test_load_onlyCompletedSessionsAppear() async throws {
        try seedSession(correct: 10, total: 10, sessionRepo: sessionRepo)
        // An incomplete session — isCompleted defaults to false
        let incomplete = Session(focusMode: .fullFretboard, gameMode: .untimed)
        try sessionRepo.save(incomplete)

        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertTrue(vm.recentSessions.allSatisfy { $0.isCompleted })
    }

    // MARK: - masteryScore(note:string:)

    func test_masteryScore_unknownCell_returnsPrior() {
        let vm = makeVM(container: container)
        let prior = MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta)
        XCTAssertEqual(vm.masteryScore(note: .a, string: 3), prior, accuracy: 0.0001)
    }

    func test_masteryScore_knownCell_returnsPersistedScore() async throws {
        try seedMasteryScore(note: .fSharp, string: 4,
                             correct: 10, total: 10,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()

        let result   = vm.masteryScore(note: .fSharp, string: 4)
        let expected = MasteryCalculator.score(correct: 10, total: 10)
        XCTAssertEqual(result, expected, accuracy: 0.0001)
    }

    // MARK: - masteryLevel(note:string:)

    func test_masteryLevel_unplayed_isDeveloping() {
        // Prior ≈ 0.667, which sits in the developing band (0.40 ..< 0.70)
        let vm = makeVM(container: container)
        XCTAssertEqual(vm.masteryLevel(note: .c, string: 1), .developing)
    }

    func test_masteryLevel_masteredData_returnsMastered() async throws {
        try seedMasteryScore(note: .e, string: 1,
                             correct: 20, total: 20,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.masteryLevel(note: .e, string: 1), .mastered)
    }

    func test_masteryLevel_beginnerData_returnsBeginner() async throws {
        try seedMasteryScore(note: .g, string: 3,
                             correct: 0, total: 10,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.masteryLevel(note: .g, string: 3), .beginner)
    }

    // MARK: - selectCell

    func test_selectCell_setsSelectedCell() async throws {
        try seedMasteryScore(note: .a, string: 2,
                             correct: 5, total: 8,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()
        await vm.selectCell(note: .a, string: 2)

        let detail = try XCTUnwrap(vm.selectedCell)
        XCTAssertEqual(detail.note, .a)
        XCTAssertEqual(detail.string, 2)
    }

    func test_selectCell_populatesRecentAttempts() async throws {
        let sessionID = UUID()
        try seedMasteryScore(note: .b, string: 3,
                             correct: 4, total: 6,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo,
                             sessionID: sessionID)
        let vm = makeVM(container: container)
        await vm.load()
        await vm.selectCell(note: .b, string: 3)

        let detail = try XCTUnwrap(vm.selectedCell)
        // seedMasteryScore saved 6 attempts; selectCell fetches up to 10
        XCTAssertEqual(detail.recentAttempts.count, 6)
    }

    func test_selectCell_neverAttempted_hasNilScore() async throws {
        let vm = makeVM(container: container)
        await vm.load()
        await vm.selectCell(note: .dSharp, string: 5)

        let detail = try XCTUnwrap(vm.selectedCell)
        XCTAssertNil(detail.score, "Score should be nil for a never-attempted cell")
        XCTAssertTrue(detail.recentAttempts.isEmpty)
    }

    func test_selectCell_replacesExistingSelection() async throws {
        try seedMasteryScore(note: .a, string: 1,
                             correct: 5, total: 5,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        try seedMasteryScore(note: .b, string: 2,
                             correct: 3, total: 5,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()

        await vm.selectCell(note: .a, string: 1)
        await vm.selectCell(note: .b, string: 2)

        let detail = try XCTUnwrap(vm.selectedCell)
        XCTAssertEqual(detail.note, .b)
        XCTAssertEqual(detail.string, 2)
    }

    // MARK: - Grid Boundary

    func test_grid_allSixStringsAccessible() async throws {
        for string in 1...6 {
            try seedMasteryScore(note: .c, string: string,
                                 correct: 1, total: 2,
                                 masteryRepo: masteryRepo,
                                 attemptRepo: attemptRepo)
        }
        let vm = makeVM(container: container)
        await vm.load()

        for string in 1...6 {
            XCTAssertNotNil(vm.scoreGrid[string][MusicalNote.c.rawValue],
                            "Expected score on string \(string)")
        }
    }

    func test_grid_allTwelveNotesAccessible() async throws {
        for note in MusicalNote.allCases {
            try seedMasteryScore(note: note, string: 1,
                                 correct: 1, total: 2,
                                 masteryRepo: masteryRepo,
                                 attemptRepo: attemptRepo)
        }
        let vm = makeVM(container: container)
        await vm.load()

        for note in MusicalNote.allCases {
            XCTAssertNotNil(vm.scoreGrid[1][note.rawValue],
                            "Expected score for note \(note) on string 1")
        }
    }

    // MARK: - Total Cells Constant

    func test_totalCells_is72() {
        XCTAssertEqual(ProgressViewModel.totalCells, 72)
    }

    // MARK: - Reload / Idempotency

    func test_load_calledTwice_doesNotDuplicateData() async throws {
        try seedMasteryScore(note: .a, string: 1,
                             correct: 5, total: 10,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()
        await vm.load()

        XCTAssertEqual(vm.scoreGrid[1][MusicalNote.a.rawValue]?.totalAttempts, 10)
        XCTAssertEqual(vm.attemptedCells, 1)
    }

    func test_load_afterNewSessionCompleted_reflectsUpdatedData() async throws {
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.recentSessions.count, 0)

        try seedSession(correct: 10, total: 20, sessionRepo: sessionRepo)
        await vm.load()
        XCTAssertEqual(vm.recentSessions.count, 1)
    }
    // MARK: - Accuracy Trend

    func test_accuracyTrend_emptyStore_isEmpty() async throws {
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertTrue(vm.accuracyTrend.isEmpty)
    }

    func test_accuracyTrend_singleSession_producesOnePoint() async throws {
        try seedSession(correct: 8, total: 10, secondsAgo: 0, sessionRepo: sessionRepo)
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.accuracyTrend.count, 1)
    }

    func test_accuracyTrend_accuracy_isCorrectForSingleSession() async throws {
        try seedSession(correct: 8, total: 10, secondsAgo: 0, sessionRepo: sessionRepo)
        let vm = makeVM(container: container)
        await vm.load()
        let point = try XCTUnwrap(vm.accuracyTrend.first)
        XCTAssertEqual(point.accuracy, 0.8, accuracy: 0.001)
    }

    func test_accuracyTrend_twoSessionsSameDay_averagedIntoOnePoint() async throws {
        // Both sessions end "now" so they always land on the same calendar day,
        // even when tests run near midnight.
        try seedSession(correct: 10, total: 10, secondsAgo: 0, sessionRepo: sessionRepo)
        try seedSession(correct: 0,  total: 10, secondsAgo: 0, sessionRepo: sessionRepo)
        let vm = makeVM(container: container)
        await vm.load()
        // Two sessions on the same day → one data point with averaged accuracy (50%)
        XCTAssertEqual(vm.accuracyTrend.count, 1)
        let point = try XCTUnwrap(vm.accuracyTrend.first)
        XCTAssertEqual(point.accuracy, 0.5, accuracy: 0.001)
        XCTAssertEqual(point.sessionCount, 2)
    }

    func test_accuracyTrend_twoSessionsDifferentDays_produceTwoPoints() async throws {
        try seedSession(correct: 8, total: 10, secondsAgo: 0,     sessionRepo: sessionRepo)
        try seedSession(correct: 6, total: 10, secondsAgo: 86500, sessionRepo: sessionRepo) // ~1 day ago
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertEqual(vm.accuracyTrend.count, 2)
    }

    func test_accuracyTrend_isSortedByDateAscending() async throws {
        for i in stride(from: 4, through: 0, by: -1) {
            try seedSession(correct: 5, total: 10,
                            secondsAgo: Double(i) * 86500,
                            sessionRepo: sessionRepo)
        }
        let vm = makeVM(container: container)
        await vm.load()
        let dates = vm.accuracyTrend.map(\.date)
        XCTAssertEqual(dates, dates.sorted())
    }

    func test_accuracyTrend_cappedAt30Days() async throws {
        // Seed 35 sessions on different days
        for i in 0..<35 {
            try seedSession(correct: 5, total: 10,
                            secondsAgo: Double(i) * 86500,
                            sessionRepo: sessionRepo)
        }
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertLessThanOrEqual(vm.accuracyTrend.count, 30)
    }

    func test_buildAccuracyTrend_zeroAttemptSessions_areExcluded() {
        let zeroAttempt = Session(focusMode: .fullFretboard, gameMode: .untimed)
        zeroAttempt.isCompleted = true
        zeroAttempt.attemptCount = 0
        let result = ProgressViewModel.buildAccuracyTrend(from: [zeroAttempt])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - UserSettings: defaultSessionLength

    func test_userSettings_defaultSessionLength_isCorrect() {
        let settings = UserSettings()
        XCTAssertEqual(settings.defaultSessionLength, 20)
    }

    func test_userSettings_defaultSessionLength_canBeChanged() {
        let settings = UserSettings()
        settings.defaultSessionLength = 40
        XCTAssertEqual(settings.defaultSessionLength, 40)
    }

    // MARK: - UserSettings: hapticFeedbackEnabled

    func test_userSettings_hapticFeedback_defaultsToTrue() {
        let settings = UserSettings()
        XCTAssertTrue(settings.hapticFeedbackEnabled)
    }
}
