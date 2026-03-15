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
    var phaseManager: LearningPhaseManager!
    var engine: SmartPracticeEngine!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        masteryRepo = SwiftDataMasteryRepository(context: context)
        sessionRepo = SwiftDataSessionRepository(context: context)
        phaseManager = LearningPhaseManager(fretboardMap: FretboardMap())
        phaseManager.reset()
        engine = SmartPracticeEngine(
            masteryRepository: masteryRepo,
            sessionRepository: sessionRepo,
            fretboardMap: FretboardMap(),
            phaseManager: phaseManager
        )
        // Clear persisted state
        UserDefaults.standard.removeObject(forKey: "lastSmartPracticeMode")
        UserDefaults.standard.removeObject(forKey: "smartPractice_consecutivePoorSessions")
        UserDefaults.standard.removeObject(forKey: "smartPractice_isStruggling")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "lastSmartPracticeMode")
        UserDefaults.standard.removeObject(forKey: "smartPractice_consecutivePoorSessions")
        UserDefaults.standard.removeObject(forKey: "smartPractice_isStruggling")
        phaseManager.reset()
        container = nil
        masteryRepo = nil
        sessionRepo = nil
        phaseManager = nil
        engine = nil
        try await super.tearDown()
    }

    // MARK: - Phase 1 Session Generation

    func test_foundationSession_startingFresh_targetsHighE() throws {
        phaseManager.initializeForBaseline(.startingFresh)
        let (session, description) = try engine.nextSession()
        // Foundation targets natural notes on the starting string
        XCTAssertEqual(session.focusMode, .naturalNotes)
        XCTAssertTrue(session.targetStrings.contains(1)) // high E for starting fresh
        XCTAssertFalse(description.isEmpty)
    }

    func test_foundationSession_chordPlayer_targetsAString() throws {
        phaseManager.initializeForBaseline(.chordPlayer)
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.focusMode, .naturalNotes)
        XCTAssertTrue(session.targetStrings.contains(5)) // A string for chord player
    }

    func test_foundationSession_usesFreeTierConstraints() throws {
        phaseManager.initializeForBaseline(.startingFresh)
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.fretRangeStart, 0)
        XCTAssertEqual(session.fretRangeEnd, 7)
        XCTAssertTrue(session.isAdaptive)
        XCTAssertEqual(session.gameMode, .untimed)
    }

    // MARK: - Phase 2 Session Generation

    func test_connectionSession_usesNaturalNotes() throws {
        phaseManager.currentPhase = .connection
        phaseManager.phaseOneCompletedStrings = [4, 5, 6]
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.focusMode, .naturalNotes)
    }

    func test_connectionSession_targetsCompletedStrings() throws {
        phaseManager.currentPhase = .connection
        phaseManager.phaseOneCompletedStrings = [4, 5, 6]
        let (session, _) = try engine.nextSession()
        // Should target the completed strings
        for string in session.targetStrings {
            XCTAssertTrue([4, 5, 6].contains(string))
        }
    }

    // MARK: - Phase 3 Session Generation

    func test_expansionSession_usesSharpsAndFlats() throws {
        phaseManager.currentPhase = .expansion
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.focusMode, .sharpsAndFlats)
    }

    // MARK: - Phase 4 Session Generation

    func test_fluencySession_usesFullFretboard() throws {
        phaseManager.currentPhase = .fluency
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.focusMode, .fullFretboard)
    }

    // MARK: - Current Focus Description

    func test_currentFocusDescription_foundation() throws {
        phaseManager.initializeForBaseline(.startingFresh) // string 1
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("high E"), "Description should mention target string: \(desc)")
        XCTAssertTrue(desc.contains("Natural Notes"), "Description should mention natural notes: \(desc)")
    }

    func test_currentFocusDescription_connection() throws {
        phaseManager.currentPhase = .connection
        phaseManager.phaseOneCompletedStrings = [4, 5]
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("Cross-String"), "Description: \(desc)")
    }

    func test_currentFocusDescription_expansion() throws {
        phaseManager.currentPhase = .expansion
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("Sharps & Flats"), "Description: \(desc)")
    }

    func test_currentFocusDescription_fluency() throws {
        phaseManager.currentPhase = .fluency
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("Full Fretboard"), "Description: \(desc)")
    }

    func test_currentFocusDescription_diagnostic() throws {
        phaseManager.initializeForBaseline(.rustyEverywhere)
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("Diagnostic"), "Description: \(desc)")
    }

    func test_currentFocusDescription_confirmation() throws {
        phaseManager.initializeForBaseline(.lowStringsSolid)
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("Confirmation"), "Description: \(desc)")
    }

    func test_peekNextSessionDescription_matchesCurrentFocus() throws {
        phaseManager.initializeForBaseline(.startingFresh)
        let peek = try engine.peekNextSessionDescription()
        let scores = try masteryRepo.allScores()
        let focus = engine.currentFocusDescription(using: scores)
        XCTAssertEqual(peek, focus)
    }

    // MARK: - Weak Spot Count

    func test_weakSpotCount_allUnseen_returnsFullCount() throws {
        let count = try engine.weakSpotCount()
        // 3 strings (4,5,6) × 8 frets (0-7) = 24 cells
        XCTAssertEqual(count, 24)
    }

    func test_weakSpotCount_withStrongScores_decreases() throws {
        let fretboardMap = FretboardMap()
        if let note = fretboardMap.map[4]?[0] {
            let score = MasteryScore(note: note, stringNumber: 4)
            score.totalAttempts = 10
            score.correctAttempts = 9
            try masteryRepo.save(score)
        }
        let count = try engine.weakSpotCount()
        XCTAssertEqual(count, 23)
    }

    func test_weakSpotCount_borderline_scoreAt50_isNotWeak() throws {
        let fretboardMap = FretboardMap()
        if let note = fretboardMap.map[4]?[0] {
            let score = MasteryScore(note: note, stringNumber: 4)
            score.totalAttempts = 17
            score.correctAttempts = 8  // score = 10/20 = 0.50
            try masteryRepo.save(score)
        }
        let count = try engine.weakSpotCount()
        XCTAssertEqual(count, 23)
    }

    // MARK: - Alternative Sessions

    func test_alternativeSessions_returnsTwoOptions() throws {
        let alternatives = try engine.alternativeSessions()
        XCTAssertEqual(alternatives.count, 2)
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

    func test_alternativeSessions_includesFullFretboard() throws {
        let alternatives = try engine.alternativeSessions()
        let modes = alternatives.map(\.session.focusMode)
        XCTAssertTrue(modes.contains(.fullFretboard))
    }

    // MARK: - Struggling User Detection

    func test_struggling_triggersAfterThreePoorSessions() {
        XCTAssertFalse(engine.isStruggling)
        engine.recordSessionPerformance(accuracy: 40.0)
        engine.recordSessionPerformance(accuracy: 45.0)
        XCTAssertFalse(engine.isStruggling)
        engine.recordSessionPerformance(accuracy: 50.0) // 3rd poor session
        XCTAssertTrue(engine.isStruggling)
    }

    func test_struggling_recoversAfterGoodSessions() {
        // Trigger struggling
        for _ in 0..<3 {
            engine.recordSessionPerformance(accuracy: 40.0)
        }
        XCTAssertTrue(engine.isStruggling)

        // Recover with good sessions
        engine.recordSessionPerformance(accuracy: 80.0)
        engine.recordSessionPerformance(accuracy: 80.0)
        engine.recordSessionPerformance(accuracy: 80.0)
        XCTAssertFalse(engine.isStruggling)
    }

    func test_struggling_goodSessionResetsCount() {
        engine.recordSessionPerformance(accuracy: 40.0)
        engine.recordSessionPerformance(accuracy: 40.0)
        // Good session resets consecutive count
        engine.recordSessionPerformance(accuracy: 80.0)
        XCTAssertFalse(engine.isStruggling)
        // Need 3 more poor sessions to trigger
        engine.recordSessionPerformance(accuracy: 40.0)
        XCTAssertFalse(engine.isStruggling)
    }

    func test_struggling_descriptionMentionsShoringUp() throws {
        phaseManager.initializeForBaseline(.startingFresh)
        // Trigger struggling
        for _ in 0..<3 {
            engine.recordSessionPerformance(accuracy: 40.0)
        }
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("Shoring up"), "Description should mention shoring up: \(desc)")
    }

    // MARK: - Next Mode Description

    func test_nextModeDescription_foundation() {
        phaseManager.initializeForBaseline(.startingFresh)
        let desc = engine.nextModeDescription()
        XCTAssertTrue(desc.contains("high E"), "Should mention target string: \(desc)")
    }

    func test_nextModeDescription_connection() {
        phaseManager.currentPhase = .connection
        let desc = engine.nextModeDescription()
        XCTAssertEqual(desc, "Cross-String")
    }

    func test_nextModeDescription_fluency() {
        phaseManager.currentPhase = .fluency
        let desc = engine.nextModeDescription()
        XCTAssertEqual(desc, "Full Fretboard")
    }
}
