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
        XCTAssertEqual(session.focusMode, .naturalNotes)
        XCTAssertTrue(session.targetStrings.contains(1))
        XCTAssertFalse(description.isEmpty)
    }

    func test_foundationSession_chordPlayer_targetsAString() throws {
        phaseManager.initializeForBaseline(.chordPlayer)
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.focusMode, .naturalNotes)
        XCTAssertTrue(session.targetStrings.contains(5))
    }

    func test_foundationSession_usesFrets0to12() throws {
        phaseManager.initializeForBaseline(.startingFresh)
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.fretRangeStart, 0)
        XCTAssertEqual(session.fretRangeEnd, 12)
        XCTAssertTrue(session.isAdaptive)
        XCTAssertEqual(session.gameMode, .untimed)
    }

    // MARK: - Phase 2 (Expansion) Session Generation

    func test_expansionSession_usesSharpsAndFlats() throws {
        phaseManager.currentPhase = .expansion
        phaseManager.phaseOneCompletedStrings = Set(1...6)
        phaseManager.currentPhaseTwoTargetString = 6
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.focusMode, .sharpsAndFlats)
        XCTAssertTrue(session.targetStrings.contains(6))
    }

    func test_expansionSession_usesFrets0to12() throws {
        phaseManager.currentPhase = .expansion
        phaseManager.phaseOneCompletedStrings = Set(1...6)
        phaseManager.currentPhaseTwoTargetString = 4
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.fretRangeEnd, 12)
    }

    // MARK: - Phase 3 (Connection) Session Generation

    func test_connectionSession_usesFullFretboard() throws {
        phaseManager.currentPhase = .connection
        phaseManager.phaseOneCompletedStrings = Set(1...6)
        phaseManager.phaseTwoCompletedStrings = Set(1...6)
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.focusMode, .fullFretboard)
        XCTAssertEqual(session.fretRangeEnd, 12)
    }

    // MARK: - Phase 4 Session Generation

    func test_fluencySession_usesFullFretboard() throws {
        phaseManager.currentPhase = .fluency
        let (session, _) = try engine.nextSession()
        XCTAssertEqual(session.focusMode, .fullFretboard)
        XCTAssertEqual(session.fretRangeEnd, 12)
    }

    // MARK: - Current Focus Description

    func test_currentFocusDescription_foundation() throws {
        phaseManager.initializeForBaseline(.startingFresh)
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("high E"), "Description should mention target string: \(desc)")
        XCTAssertTrue(desc.contains("Natural Notes"), "Description should mention natural notes: \(desc)")
    }

    func test_currentFocusDescription_expansion() throws {
        phaseManager.currentPhase = .expansion
        phaseManager.currentPhaseTwoTargetString = 5
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("Sharps & Flats"), "Description: \(desc)")
        XCTAssertTrue(desc.contains("A"), "Should mention target string: \(desc)")
    }

    func test_currentFocusDescription_connection() throws {
        phaseManager.currentPhase = .connection
        let scores = try masteryRepo.allScores()
        let desc = engine.currentFocusDescription(using: scores)
        XCTAssertTrue(desc.contains("Cross-String"), "Description: \(desc)")
        XCTAssertTrue(desc.contains("all notes"), "Should mention all notes: \(desc)")
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
        // 6 strings × 13 frets (0-12) = 78 positions
        XCTAssertEqual(count, 78)
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
        XCTAssertEqual(count, 76) // note appears at both fret 0 and fret 12
    }

    func test_weakSpotCount_borderline_scoreAt50_isNotWeak() throws {
        let fretboardMap = FretboardMap()
        if let note = fretboardMap.map[4]?[0] {
            let score = MasteryScore(note: note, stringNumber: 4)
            score.totalAttempts = 17
            score.correctAttempts = 8
            try masteryRepo.save(score)
        }
        let count = try engine.weakSpotCount()
        XCTAssertEqual(count, 76) // note appears at both fret 0 and fret 12
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
            XCTAssertEqual(alt.session.fretRangeEnd, 12)
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
        engine.recordSessionPerformance(accuracy: 50.0)
        XCTAssertTrue(engine.isStruggling)
    }

    func test_struggling_recoversAfterGoodSessions() {
        for _ in 0..<3 {
            engine.recordSessionPerformance(accuracy: 40.0)
        }
        XCTAssertTrue(engine.isStruggling)

        engine.recordSessionPerformance(accuracy: 80.0)
        engine.recordSessionPerformance(accuracy: 80.0)
        engine.recordSessionPerformance(accuracy: 80.0)
        XCTAssertFalse(engine.isStruggling)
    }

    func test_struggling_goodSessionResetsCount() {
        engine.recordSessionPerformance(accuracy: 40.0)
        engine.recordSessionPerformance(accuracy: 40.0)
        engine.recordSessionPerformance(accuracy: 80.0)
        XCTAssertFalse(engine.isStruggling)
        engine.recordSessionPerformance(accuracy: 40.0)
        XCTAssertFalse(engine.isStruggling)
    }

    func test_struggling_descriptionMentionsShoringUp() throws {
        phaseManager.initializeForBaseline(.startingFresh)
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

    func test_nextModeDescription_expansion() {
        phaseManager.currentPhase = .expansion
        phaseManager.currentPhaseTwoTargetString = 5
        let desc = engine.nextModeDescription()
        XCTAssertTrue(desc.contains("Sharps & Flats"), "Should mention sharps & flats: \(desc)")
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
