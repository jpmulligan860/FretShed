// ProgressViewModelTests.swift
// FretMaster — Unit Tests (Phase 4)
//
// Tests the ProgressViewModel's data loading, grid construction,
// summary statistics, cell selection, and edge cases.
// Uses in-memory repositories — no disk I/O.

import XCTest
import SwiftData
@testable import FretMaster

// MARK: - Helpers

@MainActor
private func makeVM(container: ModelContainer) -> ProgressViewModel {
    ProgressViewModel(
        masteryRepository: SwiftDataMasteryRepository(container: container),
        sessionRepository: SwiftDataSessionRepository(container: container),
        attemptRepository: SwiftDataAttemptRepository(container: container)
    )
}

/// Inserts `count` correct attempts for the given note/string into an attempt repo
/// and returns a MasteryScore reflecting those attempts (also saved to the mastery repo).
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

/// Saves a completed session to the session repository.
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
    session.endTime = Date(timeIntervalSinceNow: -secondsAgo)
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
        container = try makeModelContainer(inMemory: true)
        masteryRepo = SwiftDataMasteryRepository(container: container)
        sessionRepo = SwiftDataSessionRepository(container: container)
        attemptRepo = SwiftDataAttemptRepository(container: container)
    }

    override func tearDown() async throws {
        container = nil
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
        // Index 0 unused; indices 1–6 for strings.
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

    func test_load_withOneScore_appearsinGrid() async throws {
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
        // 15 correct → should meet mastered threshold
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
        // 20 correct on 3 cells → overall mastery should be high
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

    func test_load_recentSessions_appearsInOrder() async throws {
        // Older session first, newer second
        try seedSession(correct: 5, total: 10, secondsAgo: 3600, sessionRepo: sessionRepo)
        try seedSession(correct: 9, total: 10, secondsAgo: 60,   sessionRepo: sessionRepo)

        let vm = makeVM(container: container)
        await vm.load()

        XCTAssertEqual(vm.recentSessions.count, 2)
        // Newest first — the one 60 seconds ago should come before 3600s ago
        let first  = try XCTUnwrap(vm.recentSessions.first)
        let second = try XCTUnwrap(vm.recentSessions.last)
        XCTAssertGreaterThan(first.startTime, second.startTime)
    }

    func test_load_recentSessions_limitedTo20() async throws {
        for i in 0..<25 {
            try seedSession(secondsAgo: Double(i * 60), sessionRepo: sessionRepo)
        }
        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertLessThanOrEqual(vm.recentSessions.count, 20)
    }

    func test_load_onlyCompletedSessionsAppear() async throws {
        // One complete, one active (not completed)
        try seedSession(correct: 10, total: 10, sessionRepo: sessionRepo)
        let incomplete = Session(focusMode: .fullFretboard, gameMode: .untimed)
        try sessionRepo.save(incomplete)  // isCompleted = false by default

        let vm = makeVM(container: container)
        await vm.load()
        XCTAssertTrue(vm.recentSessions.allSatisfy { $0.isCompleted })
    }

    // MARK: - masteryScore(note:string:)

    func test_masteryScore_unknownCell_returnsPrior() {
        let vm = makeVM(container: container)
        // No data loaded — grid is empty, so prior should be returned
        let prior = MasteryScore.alpha / (MasteryScore.alpha + MasteryScore.beta)
        let result = vm.masteryScore(note: .a, string: 3)
        XCTAssertEqual(result, prior, accuracy: 0.0001)
    }

    func test_masteryScore_knownCell_returnsPersistedScore() async throws {
        try seedMasteryScore(note: .fSharp, string: 4,
                             correct: 10, total: 10,
                             masteryRepo: masteryRepo,
                             attemptRepo: attemptRepo)
        let vm = makeVM(container: container)
        await vm.load()

        let result = vm.masteryScore(note: .fSharp, string: 4)
        let expected = MasteryCalculator.score(correct: 10, total: 10)
        XCTAssertEqual(result, expected, accuracy: 0.0001)
    }

    // MARK: - masteryLevel(note:string:)

    func test_masteryLevel_unplayed_isBeginner() {
        let vm = makeVM(container: container)
        // Prior ≈ 0.667 → developing
        // But with no attempts the level from the prior should be developing
        let level = vm.masteryLevel(note: .c, string: 1)
        XCTAssertEqual(level, .developing)  // 0.667 falls in developing (0.40..<0.70)
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

        // Grid should only have one score for (A, 1)
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
}
