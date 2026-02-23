// QuizViewModelTests.swift
// FretShed — Unit Tests
//
// Tests the QuizViewModel state machine, adaptive selection,
// streak tracking, and session finalisation.
// Uses in-memory repositories — no audio hardware needed.

import XCTest
import SwiftData
@testable import FretShed

// MARK: - Helpers

/// In-memory mastery repo that wraps the SwiftData implementation.
private func makeContainer() throws -> ModelContainer {
    try makeModelContainer(inMemory: true)
}

@MainActor
private func makeVM(
    focusMode: FocusMode = .fullFretboard,
    gameMode: GameMode = .untimed,
    container: ModelContainer
) -> QuizViewModel {
    let session = Session(focusMode: focusMode, gameMode: gameMode)
    let settings = UserSettings()
    return QuizViewModel(
        session: session,
        fretboardMap: FretboardMap(),
        settings: settings,
        masteryRepository: SwiftDataMasteryRepository(context: ModelContext(container)),
        sessionRepository: SwiftDataSessionRepository(context: ModelContext(container)),
        attemptRepository: SwiftDataAttemptRepository(context: ModelContext(container))
    )
}

// MARK: - QuizViewModelTests

@MainActor
final class QuizViewModelTests: XCTestCase {

    var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeContainer()
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialPhase_isIdle() throws {
        let vm = makeVM(container: container)
        XCTAssertEqual(vm.phase, .idle)
        XCTAssertNil(vm.currentQuestion)
        XCTAssertEqual(vm.attemptCount, 0)
        XCTAssertEqual(vm.correctCount, 0)
        XCTAssertEqual(vm.currentStreak, 0)
        XCTAssertEqual(vm.bestStreak, 0)
    }

    // MARK: - Start

    func test_start_transitionsToActive() async throws {
        let vm = makeVM(container: container)
        await vm.start()
        XCTAssertEqual(vm.phase, .active)
        XCTAssertNotNil(vm.currentQuestion)
    }

    func test_start_questionHasValidNoteAndString() async throws {
        let vm = makeVM(container: container)
        await vm.start()
        let q = try XCTUnwrap(vm.currentQuestion)
        XCTAssertNotNil(MusicalNote(rawValue: q.note.rawValue))
        XCTAssertGreaterThanOrEqual(q.string, 1)
        XCTAssertLessThanOrEqual(q.string, 6)
        XCTAssertGreaterThanOrEqual(q.fret, 0)
        XCTAssertLessThanOrEqual(q.fret, 24)
    }

    // MARK: - Correct Answer

    func test_submitCorrect_transitionsToFeedbackCorrect() async throws {
        let vm = makeVM(container: container)
        await vm.start()
        let q = try XCTUnwrap(vm.currentQuestion)
        vm.submit(detectedNote: q.note)
        XCTAssertEqual(vm.phase, .feedbackCorrect)
        XCTAssertEqual(vm.correctCount, 1)
        XCTAssertEqual(vm.attemptCount, 1)
        XCTAssertTrue(vm.lastAnswerWasCorrect)
    }

    func test_submitCorrect_incrementsStreak() async throws {
        let vm = makeVM(container: container)
        await vm.start()

        // Answer 3 correct in a row
        for _ in 0..<3 {
            let q = try XCTUnwrap(vm.currentQuestion)
            vm.submit(detectedNote: q.note)
            XCTAssertEqual(vm.phase, .feedbackCorrect)
            vm.advanceManually()
        }
        XCTAssertEqual(vm.currentStreak, 3)
        XCTAssertEqual(vm.bestStreak, 3)
    }

    // MARK: - Wrong Answer

    func test_submitWrong_transitionsToFeedbackWrong() async throws {
        let vm = makeVM(container: container)
        await vm.start()
        let q = try XCTUnwrap(vm.currentQuestion)
        let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
        vm.submit(detectedNote: wrong)
        XCTAssertEqual(vm.phase, .feedbackWrong)
        XCTAssertEqual(vm.correctCount, 0)
        XCTAssertEqual(vm.attemptCount, 1)
        XCTAssertFalse(vm.lastAnswerWasCorrect)
    }

    func test_submitWrong_resetsStreak() async throws {
        let vm = makeVM(container: container)
        await vm.start()

        // 2 correct, then 1 wrong
        for i in 0..<3 {
            let q = try XCTUnwrap(vm.currentQuestion)
            if i < 2 {
                vm.submit(detectedNote: q.note)
            } else {
                let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
                vm.submit(detectedNote: wrong)
            }
            if vm.attemptCount < 3 { vm.advanceManually() }
        }
        XCTAssertEqual(vm.currentStreak, 0)
        XCTAssertEqual(vm.bestStreak, 2)
    }

    // MARK: - Manual Advance

    func test_advanceManually_fromFeedback_returnsToActive() async throws {
        let vm = makeVM(container: container)
        await vm.start()
        let q = try XCTUnwrap(vm.currentQuestion)
        vm.submit(detectedNote: q.note)
        XCTAssertEqual(vm.phase, .feedbackCorrect)
        vm.advanceManually()
        // Should be either .active (next question) or .complete (if 20 done)
        XCTAssertTrue(vm.phase == .active || vm.phase == .complete)
    }

    func test_advanceManually_fromIdle_hasNoEffect() async throws {
        let vm = makeVM(container: container)
        XCTAssertEqual(vm.phase, .idle)
        vm.advanceManually()
        XCTAssertEqual(vm.phase, .idle)
    }

    // MARK: - Session Completion

    func test_after20Questions_phaseBecomesComplete() async throws {
        let vm = makeVM(container: container)
        await vm.start()

        for _ in 0..<20 {
            guard vm.phase == .active else { break }
            let q = try XCTUnwrap(vm.currentQuestion)
            vm.submit(detectedNote: q.note)
            if vm.phase == .feedbackCorrect || vm.phase == .feedbackWrong {
                vm.advanceManually()
            }
        }
        XCTAssertEqual(vm.phase, .complete)
        XCTAssertEqual(vm.attemptCount, 20)
    }

    // MARK: - End Session

    func test_endSession_immediatelyCompletesSession() async throws {
        let vm = makeVM(container: container)
        await vm.start()
        let q = try XCTUnwrap(vm.currentQuestion)
        vm.submit(detectedNote: q.note)
        await vm.endSession()
        XCTAssertEqual(vm.phase, .complete)
    }

    // MARK: - Focus Mode Filtering

    func test_singleStringMode_questionsOnlyOnSelectedString() async throws {
        let targetString = 3
        let session = Session(
            focusMode: .singleString,
            gameMode: .untimed,
            targetNotes: [],
            targetStrings: [targetString]
        )
        let settings = UserSettings()
        let vm = QuizViewModel(
            session: session,
            fretboardMap: FretboardMap(),
            settings: settings,
            masteryRepository: SwiftDataMasteryRepository(context: ModelContext(container)),
            sessionRepository: SwiftDataSessionRepository(context: ModelContext(container)),
            attemptRepository: SwiftDataAttemptRepository(context: ModelContext(container))
        )

        await vm.start()
        // Run 10 rounds and check all questions are on the right string
        for _ in 0..<10 {
            guard vm.phase == .active else { break }
            let q = try XCTUnwrap(vm.currentQuestion)
            XCTAssertEqual(q.string, targetString,
                "Expected string \(targetString), got \(q.string)")
            vm.submit(detectedNote: q.note)
            vm.advanceManually()
        }
    }

    func test_singleNoteMode_questionsUseCorrectNote() async throws {
        let targetNote = MusicalNote.a
        let session = Session(
            focusMode: .singleNote,
            gameMode: .untimed,
            targetNotes: [targetNote],
            targetStrings: []
        )
        let settings = UserSettings()
        let vm = QuizViewModel(
            session: session,
            fretboardMap: FretboardMap(),
            settings: settings,
            masteryRepository: SwiftDataMasteryRepository(context: ModelContext(container)),
            sessionRepository: SwiftDataSessionRepository(context: ModelContext(container)),
            attemptRepository: SwiftDataAttemptRepository(context: ModelContext(container))
        )

        await vm.start()
        for _ in 0..<6 {
            guard vm.phase == .active else { break }
            let q = try XCTUnwrap(vm.currentQuestion)
            XCTAssertEqual(q.note, targetNote,
                "Expected \(targetNote), got \(q.note)")
            vm.submit(detectedNote: q.note)
            vm.advanceManually()
        }
    }

    // MARK: - Detected Note

    func test_detectedNote_setOnSubmit() async throws {
        let vm = makeVM(container: container)
        await vm.start()
        let q = try XCTUnwrap(vm.currentQuestion)
        let wrong = MusicalNote(rawValue: (q.note.rawValue + 2) % 12)!
        vm.submit(detectedNote: wrong)
        XCTAssertEqual(vm.detectedNote, wrong)
    }

    // MARK: - Question Non-Repeat

    func test_consecutiveQuestions_differentNoteOrString() async throws {
        let vm = makeVM(container: container)
        await vm.start()

        var previousQuestion: QuizQuestion? = nil
        var repeatCount = 0
        var totalChecks = 0

        for _ in 0..<15 {
            guard vm.phase == .active else { break }
            let q = try XCTUnwrap(vm.currentQuestion)

            if let prev = previousQuestion {
                if prev.note == q.note && prev.string == q.string {
                    repeatCount += 1
                }
                totalChecks += 1
            }
            previousQuestion = q
            vm.submit(detectedNote: q.note)
            vm.advanceManually()
        }

        // Allow at most 10% immediate repeats
        let repeatRate = totalChecks > 0 ? Double(repeatCount) / Double(totalChecks) : 0
        XCTAssertLessThan(repeatRate, 0.10,
            "Too many immediate repeats: \(repeatCount)/\(totalChecks)")
    }

    // MARK: - Streak Mode

    func test_streakMode_endsSessionAfterOneWrongAnswer() async throws {
        let vm = makeVM(focusMode: .fullFretboard, gameMode: .streak, container: container)
        await vm.start()

        // Answer one correctly first to prove it doesn't end on correct
        let q1 = try XCTUnwrap(vm.currentQuestion)
        vm.submit(detectedNote: q1.note)
        XCTAssertEqual(vm.phase, .feedbackCorrect)
        vm.advanceManually()
        XCTAssertEqual(vm.phase, .active)

        // Now answer wrong
        let q2 = try XCTUnwrap(vm.currentQuestion)
        let wrong = MusicalNote(rawValue: (q2.note.rawValue + 1) % 12)!
        vm.submit(detectedNote: wrong)
        XCTAssertEqual(vm.phase, .feedbackWrong)

        // After feedback delay the session should complete; simulate by waiting
        // just past feedbackDuration using advanceManually which also forces completion
        // In streak mode advanceManually should not revert to .active
        // We validate phase becomes complete after the scheduled task fires.
        // Give the task a moment to run.
        try await Task.sleep(for: .seconds(1.7))
        XCTAssertEqual(vm.phase, .complete,
            "Streak mode should complete the session after one wrong answer")
    }

    func test_streakMode_bestStreakTrackedCorrectly() async throws {
        let vm = makeVM(focusMode: .fullFretboard, gameMode: .streak, container: container)
        await vm.start()

        // Answer 3 correct, then wrong
        for i in 0..<4 {
            guard vm.phase == .active else { break }
            let q = try XCTUnwrap(vm.currentQuestion)
            if i < 3 {
                vm.submit(detectedNote: q.note)
                vm.advanceManually()
            } else {
                let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
                vm.submit(detectedNote: wrong)
            }
        }
        XCTAssertEqual(vm.bestStreak, 3)
    }

    // MARK: - Tempo Mode

    func test_tempoMode_allowanceShrinkesAfterCorrectAnswers() async throws {
        let vm = makeVM(focusMode: .fullFretboard, gameMode: .tempo, container: container)
        await vm.start()
        let initialAllowance = vm.tempoTimeAllowance

        let q = try XCTUnwrap(vm.currentQuestion)
        vm.submit(detectedNote: q.note)
        XCTAssertLessThan(vm.tempoTimeAllowance, initialAllowance,
            "Allowance should shrink after a correct answer in tempo mode")
    }

    func test_tempoMode_allowanceDoesNotShrinkBelowFloor() async throws {
        let vm = makeVM(focusMode: .fullFretboard, gameMode: .tempo, container: container)
        await vm.start()

        // Answer 50 correct answers — floor should prevent going below 2.0
        for _ in 0..<50 {
            guard vm.phase == .active else { break }
            let q = try XCTUnwrap(vm.currentQuestion)
            vm.submit(detectedNote: q.note)
            vm.advanceManually()
        }
        XCTAssertGreaterThanOrEqual(vm.tempoTimeAllowance, 2.0,
            "Tempo allowance should never drop below the 2s floor")
    }

    func test_tempoMode_wrongAnswerDoesNotShrinkAllowance() async throws {
        let vm = makeVM(focusMode: .fullFretboard, gameMode: .tempo, container: container)
        await vm.start()
        let initialAllowance = vm.tempoTimeAllowance

        let q = try XCTUnwrap(vm.currentQuestion)
        let wrong = MusicalNote(rawValue: (q.note.rawValue + 1) % 12)!
        vm.submit(detectedNote: wrong)
        XCTAssertEqual(vm.tempoTimeAllowance, initialAllowance,
            "Allowance should not change on a wrong answer in tempo mode")
    }

    // MARK: - Circle of Fifths Mode

    func test_circleOfFifths_firstQuestionIsC() async throws {
        let vm = makeVM(focusMode: .circleOfFifths, gameMode: .untimed, container: container)
        await vm.start()
        let q = try XCTUnwrap(vm.currentQuestion)
        XCTAssertEqual(q.note, .c, "First question in circle-of-fifths mode should be C")
    }

    func test_circleOfFourths_firstQuestionIsC() async throws {
        let vm = makeVM(focusMode: .circleOfFourths, gameMode: .untimed, container: container)
        await vm.start()
        let q = try XCTUnwrap(vm.currentQuestion)
        XCTAssertEqual(q.note, .c, "First question in circle-of-fourths mode should be C")
    }

    func test_circleOfFifths_advancesToGAfterCorrectC() async throws {
        let vm = makeVM(focusMode: .circleOfFifths, gameMode: .untimed, container: container)
        await vm.start()

        let q = try XCTUnwrap(vm.currentQuestion)
        XCTAssertEqual(q.note, .c)
        vm.submit(detectedNote: .c)
        vm.advanceManually()

        let q2 = try XCTUnwrap(vm.currentQuestion)
        XCTAssertEqual(q2.note, .g, "Second note in circle-of-fifths should be G")
    }

    func test_circleOfFifths_staysOnSameNoteAfterWrongAnswer() async throws {
        let vm = makeVM(focusMode: .circleOfFifths, gameMode: .untimed, container: container)
        await vm.start()

        let q = try XCTUnwrap(vm.currentQuestion)
        XCTAssertEqual(q.note, .c)
        let wrong = MusicalNote(rawValue: (MusicalNote.c.rawValue + 1) % 12)!
        vm.submit(detectedNote: wrong)
        vm.advanceManually()

        let q2 = try XCTUnwrap(vm.currentQuestion)
        XCTAssertEqual(q2.note, .c,
            "Should stay on C after a wrong answer in circle-of-fifths mode")
    }

    // MARK: - Adaptive Mode (via isAdaptive flag)

    func test_adaptiveMode_avoidsAlreadyMasteredCells() async throws {
        // Seed every (note, string1) cell as mastered except A
        let masteryRepo = SwiftDataMasteryRepository(context: ModelContext(container))
        for note in MusicalNote.allCases where note != .a {
            let score = try masteryRepo.score(forNote: note, string: 1)
            for _ in 0..<20 { score.record(wasCorrect: true) }
            try masteryRepo.save(score)
        }
        // Also master all other strings for all notes except A on string 2
        for string in 2...6 {
            for note in MusicalNote.allCases where !(note == .a && string == 2) {
                let score = try masteryRepo.score(forNote: note, string: string)
                for _ in 0..<20 { score.record(wasCorrect: true) }
                try masteryRepo.save(score)
            }
        }

        let session = Session(focusMode: .fullFretboard, gameMode: .untimed, isAdaptive: true)
        let settings = UserSettings()
        let vm = QuizViewModel(
            session: session,
            fretboardMap: FretboardMap(),
            settings: settings,
            masteryRepository: masteryRepo,
            sessionRepository: SwiftDataSessionRepository(context: ModelContext(container)),
            attemptRepository: SwiftDataAttemptRepository(context: ModelContext(container))
        )
        await vm.start()

        // All 10 questions should be A (the only unmastered note)
        for _ in 0..<10 {
            guard vm.phase == .active else { break }
            let q = try XCTUnwrap(vm.currentQuestion)
            XCTAssertEqual(q.note, .a,
                "Adaptive mode should focus on the only unmastered note")
            vm.submit(detectedNote: q.note)
            vm.advanceManually()
        }
    }

    func test_adaptivePlusSingleString_restrictsCandidates() async throws {
        let targetString = 3
        let session = Session(
            focusMode: .singleString,
            gameMode: .untimed,
            targetNotes: [],
            targetStrings: [targetString],
            isAdaptive: true
        )
        let settings = UserSettings()
        let vm = QuizViewModel(
            session: session,
            fretboardMap: FretboardMap(),
            settings: settings,
            masteryRepository: SwiftDataMasteryRepository(context: ModelContext(container)),
            sessionRepository: SwiftDataSessionRepository(context: ModelContext(container)),
            attemptRepository: SwiftDataAttemptRepository(context: ModelContext(container))
        )
        await vm.start()

        // All questions should be on string 3 and adaptively weighted
        for _ in 0..<10 {
            guard vm.phase == .active else { break }
            let q = try XCTUnwrap(vm.currentQuestion)
            XCTAssertEqual(q.string, targetString,
                "Adaptive + Single String should restrict to string \(targetString)")
            vm.submit(detectedNote: q.note)
            vm.advanceManually()
        }
    }
}
