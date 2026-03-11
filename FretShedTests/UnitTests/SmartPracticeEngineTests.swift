// SmartPracticeEngineTests.swift
// FretShedTests

import XCTest
import SwiftData
@testable import FretShed

@MainActor
final class SmartPracticeEngineTests: XCTestCase {

    var container: ModelContainer!
    var masteryRepo: SwiftDataMasteryRepository!
    var sessionRepo: SwiftDataSessionRepository!
    var engine: SmartPracticeEngine!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        masteryRepo = SwiftDataMasteryRepository(context: context)
        sessionRepo = SwiftDataSessionRepository(context: context)
        engine = SmartPracticeEngine(
            masteryRepository: masteryRepo,
            sessionRepository: sessionRepo,
            fretboardMap: FretboardMap()
        )
        // Clear any persisted mode from previous tests
        UserDefaults.standard.removeObject(forKey: "lastSmartPracticeMode")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "lastSmartPracticeMode")
        container = nil
        masteryRepo = nil
        sessionRepo = nil
        engine = nil
        try await super.tearDown()
    }

    // MARK: - Mode Rotation

    func test_firstSession_isFullFretboard() throws {
        let (session, description) = try engine.nextSession()
        XCTAssertEqual(session.focusMode, .fullFretboard)
        XCTAssertTrue(description.contains("Full Fretboard"))
    }

    func test_modeRotation_cyclesThrough() throws {
        // First call: nil → fullFretboard
        let (s1, _) = try engine.nextSession()
        XCTAssertEqual(s1.focusMode, .fullFretboard)

        // Second call: fullFretboard → singleString
        let (s2, _) = try engine.nextSession()
        XCTAssertEqual(s2.focusMode, .singleString)

        // Third call: singleString → sameNote (mapped to .singleNote)
        let (s3, _) = try engine.nextSession()
        XCTAssertEqual(s3.focusMode, .singleNote)

        // Fourth call: sameNote → fullFretboard (wraps around)
        let (s4, _) = try engine.nextSession()
        XCTAssertEqual(s4.focusMode, .fullFretboard)
    }

    func test_nextModeDescription_matchesRotation() {
        // nil → fullFretboard
        XCTAssertEqual(engine.nextModeDescription(), "Full Fretboard")
        // Note: nextModeDescription doesn't save, so calling again gives the same result
        XCTAssertEqual(engine.nextModeDescription(), "Full Fretboard")
    }

    // MARK: - Session Properties

    func test_allSessions_useFreeTierConstraints() throws {
        for _ in 0..<3 {
            let (session, _) = try engine.nextSession()
            XCTAssertEqual(session.fretRangeStart, 0)
            XCTAssertEqual(session.fretRangeEnd, 7)
            XCTAssertTrue(session.isAdaptive)
            XCTAssertEqual(session.gameMode, .untimed)
        }
    }

    func test_singleStringSession_targetsWeakestString() throws {
        // Seed string 5 as strong, strings 4 and 6 default (0.50)
        let score = MasteryScore(note: .a, stringNumber: 5)
        score.totalAttempts = 20
        score.correctAttempts = 19
        try masteryRepo.save(score)

        // Advance past fullFretboard to get to singleString
        _ = try engine.nextSession()
        let (session, description) = try engine.nextSession()

        XCTAssertEqual(session.focusMode, .singleString)
        // Should target string 4 or 6 (both at default 0.50, lower than string 5)
        XCTAssertTrue(session.targetStrings.count == 1)
        let targetString = session.targetStrings.first!
        XCTAssertTrue([4, 6].contains(targetString), "Expected string 4 or 6 but got \(targetString)")
        XCTAssertTrue(description.contains("Single String"))
    }

    func test_sameNoteSession_targetsWeakestNote() throws {
        // Seed some notes as strong on strings 4-6, frets 0-7
        // Make E notes strong across all free strings
        for string in [4, 5, 6] {
            let score = MasteryScore(note: .e, stringNumber: string)
            score.totalAttempts = 20
            score.correctAttempts = 19
            try masteryRepo.save(score)
        }

        // Advance past fullFretboard and singleString
        _ = try engine.nextSession()
        _ = try engine.nextSession()
        let (session, description) = try engine.nextSession()

        XCTAssertEqual(session.focusMode, .singleNote)
        XCTAssertEqual(session.notes.count, 1)
        // Should NOT be .e (the strong note)
        let targetNote = MusicalNote(rawValue: session.notes.first!)
        XCTAssertNotEqual(targetNote, .e)
        XCTAssertTrue(description.contains("Same Note"))
    }

    // MARK: - Weak Spot Count

    func test_weakSpotCount_allUnseen_returnsFullCount() throws {
        // No mastery data — all cells should be "weak" (below 0.50)
        let count = try engine.weakSpotCount()
        // 3 strings (4,5,6) × 8 frets (0-7) = 24 cells
        XCTAssertEqual(count, 24)
    }

    func test_weakSpotCount_withStrongScores_decreases() throws {
        // Mark one cell as strong (score > 0.50)
        let fretboardMap = FretboardMap()
        // String 4, fret 0 = D
        if let note = fretboardMap.map[4]?[0] {
            let score = MasteryScore(note: note, stringNumber: 4)
            score.totalAttempts = 10
            score.correctAttempts = 9  // score = (9+2)/(10+3) ≈ 0.846
            try masteryRepo.save(score)
        }

        let count = try engine.weakSpotCount()
        XCTAssertEqual(count, 23) // 24 - 1 strong cell
    }

    func test_weakSpotCount_borderline_scoreAt50_isNotWeak() throws {
        // Score exactly at 0.50 threshold boundary
        // score = (correct + 2) / (total + 3) = 0.50
        // correct + 2 = 0.50 * (total + 3)
        // For total=17: correct + 2 = 10, correct = 8 → score = 10/20 = 0.50
        let fretboardMap = FretboardMap()
        if let note = fretboardMap.map[4]?[0] {
            let score = MasteryScore(note: note, stringNumber: 4)
            score.totalAttempts = 17
            score.correctAttempts = 8  // score = (8+2)/(17+3) = 10/20 = 0.50
            try masteryRepo.save(score)
        }

        let count = try engine.weakSpotCount()
        // 0.50 is NOT < 0.50, so not counted as weak
        XCTAssertEqual(count, 23)
    }

    // MARK: - Alternative Sessions

    func test_alternativeSessions_returnsTwoOptions() throws {
        let alternatives = try engine.alternativeSessions()
        XCTAssertEqual(alternatives.count, 2)
    }

    func test_alternativeSessions_excludeCurrentMode() throws {
        // First call peek: mode would be fullFretboard
        let alternatives = try engine.alternativeSessions()
        let focusModes = alternatives.map(\.session.focusMode)
        // fullFretboard is the "current" mode, so alternatives should not include it
        XCTAssertFalse(focusModes.contains(.fullFretboard))
        // Should contain singleString and singleNote
        XCTAssertTrue(focusModes.contains(.singleString))
        XCTAssertTrue(focusModes.contains(.singleNote))
    }

    func test_alternativeSessions_haveCorrectMetadata() throws {
        let alternatives = try engine.alternativeSessions()
        for alt in alternatives {
            XCTAssertFalse(alt.title.isEmpty)
            XCTAssertFalse(alt.subtitle.isEmpty)
            XCTAssertFalse(alt.icon.isEmpty)
            XCTAssertEqual(alt.session.fretRangeStart, 0)
            XCTAssertEqual(alt.session.fretRangeEnd, 7)
            XCTAssertTrue(alt.session.isAdaptive)
        }
    }
}
