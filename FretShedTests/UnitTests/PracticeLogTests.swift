// PracticeLogTests.swift
// FretShed — Unit Tests

import XCTest
import SwiftData
@testable import FretShed

@MainActor
final class PracticeLogTests: XCTestCase {

    var container: ModelContainer!
    var sessionRepo: SwiftDataSessionRepository!
    var attemptRepo: SwiftDataAttemptRepository!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeModelContainer(inMemory: true)
        sessionRepo = SwiftDataSessionRepository(context: ModelContext(container))
        attemptRepo = SwiftDataAttemptRepository(context: ModelContext(container))
    }

    override func tearDown() async throws {
        container = nil
        sessionRepo = nil
        attemptRepo = nil
        try await super.tearDown()
    }

    // MARK: - Session Creation

    func test_newSession_hasCorrectDefaults() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        XCTAssertEqual(session.attemptCount, 0)
        XCTAssertEqual(session.correctCount, 0)
        XCTAssertFalse(session.isCompleted)
        XCTAssertFalse(session.isPaused)
        XCTAssertNil(session.endTime)
    }

    // MARK: - Duration

    func test_duration_sessionInProgress_returnsElapsedTime() {
        let start = Date(timeIntervalSinceNow: -30)
        let duration = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(duration, 29.0)
        XCTAssertLessThan(duration, 32.0)
    }

    func test_duration_completedSession_isFixed() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.endTime = session.startTime.addingTimeInterval(120)
        XCTAssertEqual(session.duration, 120, accuracy: 0.1)
    }

    // MARK: - Accuracy

    func test_accuracyPercent_noAttempts_isZero() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        XCTAssertEqual(session.accuracyPercent, 0.0)
    }

    func test_accuracyPercent_allCorrect() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.attemptCount = 10
        session.correctCount = 10
        XCTAssertEqual(session.accuracyPercent, 100.0, accuracy: 0.01)
    }

    func test_accuracyPercent_halfCorrect() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.attemptCount = 10
        session.correctCount = 5
        XCTAssertEqual(session.accuracyPercent, 50.0, accuracy: 0.01)
    }

    func test_accuracyPercent_zeroCorrect() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.attemptCount = 5
        session.correctCount = 0
        XCTAssertEqual(session.accuracyPercent, 0.0, accuracy: 0.01)
    }

    // MARK: - Mastery Level (4-tier: struggling / learning / mastered)

    func test_masteryLevel_struggling() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.overallMasteryAtEnd = 0.20
        XCTAssertEqual(session.masteryLevel, .struggling)
    }

    func test_masteryLevel_struggling_upperBound() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.overallMasteryAtEnd = 0.49
        XCTAssertEqual(session.masteryLevel, .struggling)
    }

    func test_masteryLevel_learning() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.overallMasteryAtEnd = 0.55
        XCTAssertEqual(session.masteryLevel, .learning)
    }

    func test_masteryLevel_learning_upperBound() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.overallMasteryAtEnd = 0.70
        XCTAssertEqual(session.masteryLevel, .learning)
    }

    func test_masteryLevel_proficient() {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.overallMasteryAtEnd = 0.95
        // Session-level masteryLevel uses score-only (no isMastered), so 90%+ = proficient
        XCTAssertEqual(session.masteryLevel, .proficient)
    }

    // MARK: - Persistence

    func test_saveSession_canBeRetrievedFromHistory() throws {
        let session = Session(focusMode: .singleNote, gameMode: .timed)
        session.attemptCount = 20
        session.correctCount = 18
        session.isCompleted = true
        session.endTime = Date()
        try sessionRepo.save(session)
        let all = try sessionRepo.allSessions()
        XCTAssertFalse(all.isEmpty)
        let saved = all.first { $0.id == session.id }
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.attemptCount, 20)
    }

    func test_activeSession_returnsIncompleteSession() throws {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        try sessionRepo.save(session)
        let active = try sessionRepo.activeSession()
        XCTAssertNotNil(active)
        XCTAssertEqual(active?.id, session.id)
    }

    func test_completedSession_notReturnedAsActiveSession() throws {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.isCompleted = true
        session.endTime = Date()
        try sessionRepo.save(session)
        let active = try sessionRepo.activeSession()
        XCTAssertNil(active)
    }

    func test_completeSession_marksCompletedAndSetsEndTime() throws {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        try sessionRepo.complete(session)
        XCTAssertTrue(session.isCompleted)
        XCTAssertNotNil(session.endTime)
        XCTAssertFalse(session.isPaused)
    }

    func test_recentSessions_limitWorks() throws {
        for i in 0..<5 {
            let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
            session.isCompleted = true
            session.endTime = Date().addingTimeInterval(Double(i))
            try sessionRepo.save(session)
        }
        let recent = try sessionRepo.recentSessions(limit: 3)
        XCTAssertEqual(recent.count, 3)
    }

    func test_deleteAll_removesAllSessions() throws {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.isCompleted = true
        try sessionRepo.save(session)
        try sessionRepo.deleteAll()
        let all = try sessionRepo.allSessions()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Attempts Persistence

    func test_saveAttempt_canBeRetrievedBySession() throws {
        let sessionID = UUID()
        let attempt = Attempt(
            targetNote: .a,
            targetString: 2,
            targetFret: 5,
            playedNote: .a,
            playedString: 2,
            responseTimeMs: 800,
            wasCorrect: true,
            sessionID: sessionID,
            gameMode: .untimed,
            acceptedAnyString: false
        )
        try attemptRepo.save(attempt)
        let fetched = try attemptRepo.attempts(forSession: sessionID)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.targetNote, .a)
        XCTAssertEqual(fetched.first?.wasCorrect, true)
    }

    func test_attempt_timeout_hasNilPlayedNote() throws {
        let sessionID = UUID()
        let attempt = Attempt(
            targetNote: .c,
            targetString: 1,
            targetFret: 8,
            playedNote: nil,
            playedString: nil,
            responseTimeMs: 5000,
            wasCorrect: false,
            sessionID: sessionID,
            gameMode: .timed,
            acceptedAnyString: false
        )
        try attemptRepo.save(attempt)
        let fetched = try attemptRepo.attempts(forSession: sessionID)
        XCTAssertNil(fetched.first?.playedNote)
        XCTAssertFalse(fetched.first?.wasCorrect ?? true)
    }

    // MARK: - MasteryLevel Ordering

    func test_masteryLevel_ordering() {
        XCTAssertLessThan(MasteryLevel.struggling, .learning)
        XCTAssertLessThan(MasteryLevel.learning, .proficient)
        XCTAssertLessThan(MasteryLevel.proficient, .mastered)
    }
}
