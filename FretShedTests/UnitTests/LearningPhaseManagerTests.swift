// LearningPhaseManagerTests.swift
// FretShedTests

import XCTest
import SwiftData
@testable import FretShed

@MainActor
final class LearningPhaseManagerTests: XCTestCase {

    var container: ModelContainer!
    var masteryRepo: SwiftDataMasteryRepository!
    var manager: LearningPhaseManager!
    var fretboardMap: FretboardMap!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        masteryRepo = SwiftDataMasteryRepository(context: context)
        fretboardMap = FretboardMap()
        manager = LearningPhaseManager(fretboardMap: fretboardMap)
        manager.reset()
    }

    override func tearDown() async throws {
        manager.reset()
        container = nil
        masteryRepo = nil
        manager = nil
        fretboardMap = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a MasteryScore with lastAttemptDate set to now (so effectiveScore == score).
    private func makeScore(note: MusicalNote, string: Int, total: Int, correct: Int) -> MasteryScore {
        let score = MasteryScore(note: note, stringNumber: string)
        score.totalAttempts = total
        score.correctAttempts = correct
        score.lastAttemptDate = Date()
        return score
    }

    // MARK: - LearningPhase Enum

    func test_phaseOrder() {
        XCTAssertEqual(LearningPhase.foundation.rawValue, 1)
        XCTAssertEqual(LearningPhase.connection.rawValue, 2)
        XCTAssertEqual(LearningPhase.expansion.rawValue, 3)
        XCTAssertEqual(LearningPhase.fluency.rawValue, 4)
    }

    func test_phaseNext() {
        XCTAssertEqual(LearningPhase.foundation.next, .connection)
        XCTAssertEqual(LearningPhase.connection.next, .expansion)
        XCTAssertEqual(LearningPhase.expansion.next, .fluency)
        XCTAssertNil(LearningPhase.fluency.next)
    }

    func test_phaseDisplayNames() {
        XCTAssertEqual(LearningPhase.foundation.displayName, "Foundation")
        XCTAssertEqual(LearningPhase.fluency.displayName, "Fluency")
    }

    // MARK: - Cold Start / Initialization

    func test_initializeForBaseline_startingFresh() {
        manager.initializeForBaseline(.startingFresh)
        XCTAssertEqual(manager.currentPhase, .foundation)
        XCTAssertEqual(manager.currentTargetString, 1) // high E
        XCTAssertFalse(manager.isInDiagnosticMode)
        XCTAssertFalse(manager.isInConfirmationMode)
        XCTAssertTrue(manager.phaseOneCompletedStrings.isEmpty)
    }

    func test_initializeForBaseline_chordPlayer() {
        manager.initializeForBaseline(.chordPlayer)
        XCTAssertEqual(manager.currentTargetString, 5) // A string
        XCTAssertFalse(manager.isInConfirmationMode)
    }

    func test_initializeForBaseline_openPosition_triggersConfirmation() {
        manager.initializeForBaseline(.openPosition)
        XCTAssertTrue(manager.isInConfirmationMode)
        XCTAssertFalse(manager.isInDiagnosticMode)
        XCTAssertEqual(manager.currentTargetString, 1) // high E (highest prior)
    }

    func test_initializeForBaseline_lowStringsSolid_triggersConfirmation() {
        manager.initializeForBaseline(.lowStringsSolid)
        XCTAssertTrue(manager.isInConfirmationMode)
        XCTAssertEqual(manager.currentTargetString, 5) // A string
    }

    func test_initializeForBaseline_rustyEverywhere_triggersDiagnostic() {
        manager.initializeForBaseline(.rustyEverywhere)
        XCTAssertTrue(manager.isInDiagnosticMode)
        XCTAssertFalse(manager.isInConfirmationMode)
        XCTAssertNil(manager.currentTargetString)
    }

    // MARK: - Natural Note Cells

    func test_naturalNoteCells_highEString() {
        // String 1 (high E): open notes in frets 0-7
        // E(0), F(1), G(3), A(5), B(7) = 5 natural notes
        let cells = manager.naturalNoteCells(onString: 1)
        let noteNames = cells.map { $0.note.sharpName }
        XCTAssertEqual(cells.count, 5)
        XCTAssertTrue(noteNames.contains("E"))
        XCTAssertTrue(noteNames.contains("F"))
        XCTAssertTrue(noteNames.contains("G"))
        XCTAssertTrue(noteNames.contains("A"))
        XCTAssertTrue(noteNames.contains("B"))
    }

    func test_naturalNoteCells_aString() {
        // String 5 (A): A(0), B(2), C(3), D(5), E(7) = 5 natural notes
        let cells = manager.naturalNoteCells(onString: 5)
        let noteNames = cells.map { $0.note.sharpName }
        XCTAssertEqual(cells.count, 5)
        XCTAssertTrue(noteNames.contains("A"))
        XCTAssertTrue(noteNames.contains("B"))
        XCTAssertTrue(noteNames.contains("C"))
        XCTAssertTrue(noteNames.contains("D"))
        XCTAssertTrue(noteNames.contains("E"))
    }

    func test_naturalNoteCells_deduplicates() {
        // Each string should have unique notes — no duplicates in frets 0-7
        for string in 1...6 {
            let cells = manager.naturalNoteCells(onString: string)
            let noteRaws = cells.map { $0.note.rawValue }
            XCTAssertEqual(noteRaws.count, Set(noteRaws).count,
                           "Duplicate notes found on string \(string)")
        }
    }

    // MARK: - Phase 1 Advancement

    func test_advancement_allNaturalNotesMastered_advances() throws {
        manager.initializeForBaseline(.startingFresh) // string 1
        let targetString = 1

        // Seed all natural notes on string 1 above threshold
        let naturalCells = manager.naturalNoteCells(onString: targetString)
        for (note, _) in naturalCells {
            try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 9))
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertTrue(advanced)
        XCTAssertTrue(manager.phaseOneCompletedStrings.contains(targetString))
    }

    func test_advancement_graceThreshold_oneStuckNote_advances() throws {
        manager.initializeForBaseline(.startingFresh) // string 1
        let targetString = 1
        let naturalCells = manager.naturalNoteCells(onString: targetString)

        for (index, (note, fret)) in naturalCells.enumerated() {
            if index == naturalCells.count - 1 && fret != 0 {
                // Last non-open note: stuck at grace floor
                try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 4))
            } else {
                // All others: above threshold
                try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 9))
            }
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertTrue(advanced, "Should advance with 1 stuck note at grace floor")
        XCTAssertEqual(manager.stuckNotes.count, 1)
    }

    func test_advancement_graceThreshold_openStringExempt() throws {
        manager.initializeForBaseline(.startingFresh) // string 1
        let targetString = 1
        let naturalCells = manager.naturalNoteCells(onString: targetString)

        // Open string (fret 0) is the first cell — make it the stuck note
        for (index, (note, _)) in naturalCells.enumerated() {
            if index == 0 {
                // Open string at grace floor — NOT eligible for grace
                try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 4))
            } else {
                try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 9))
            }
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertFalse(advanced, "Open string at grace floor should NOT qualify for grace threshold")
    }

    func test_advancement_twoStuckNotes_doesNotAdvance() throws {
        manager.initializeForBaseline(.chordPlayer) // string 5
        let targetString = 5
        let naturalCells = manager.naturalNoteCells(onString: targetString)

        var stuckCount = 0
        for (note, fret) in naturalCells {
            if fret != 0 && stuckCount < 2 {
                // Two non-open notes stuck at grace floor
                try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 4))
                stuckCount += 1
            } else {
                try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 9))
            }
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertFalse(advanced, "Two stuck notes should block advancement")
    }

    func test_advancement_cellsWithZeroAttempts_blockAdvancement() throws {
        manager.initializeForBaseline(.startingFresh) // string 1
        let targetString = 1
        let naturalCells = manager.naturalNoteCells(onString: targetString)

        // Seed all but one natural note
        for (index, (note, _)) in naturalCells.enumerated() {
            if index == naturalCells.count - 1 { continue } // Skip last — 0 attempts
            try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 9))
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertFalse(advanced, "Cells with 0 attempts should not count as passed")
    }

    func test_advancement_threeStringsCompleted_advancesToPhase2() throws {
        manager.initializeForBaseline(.startingFresh)

        // Complete strings 6, 5, 4 (all free-tier strings)
        for string in [6, 5, 4] {
            manager.currentTargetString = string
            let naturalCells = manager.naturalNoteCells(onString: string)
            for (note, _) in naturalCells {
                try masteryRepo.save(makeScore(note: note, string: string, total: 10, correct: 9))
            }
            let scores = try masteryRepo.allScores()
            manager.evaluateAdvancement(using: scores)
        }

        XCTAssertEqual(manager.currentPhase, .connection)
        XCTAssertNil(manager.currentTargetString)
        XCTAssertEqual(manager.phaseOneCompletedStrings.count, 3)
    }

    // MARK: - Phase Never Regresses

    func test_phaseNeverRegresses() throws {
        manager.initializeForBaseline(.startingFresh)

        // Manually advance to connection
        manager.phaseOneCompletedStrings = [4, 5, 6]
        manager.currentPhase = .connection
        manager.currentTargetString = nil

        // Try to evaluate with empty scores (everything below threshold)
        let scores: [MasteryScore] = []
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertFalse(advanced)
        XCTAssertEqual(manager.currentPhase, .connection, "Phase should never regress")
    }

    // MARK: - Phase 2 → Phase 3 Advancement

    func test_connectionToExpansion_requiresAllStringsNaturals() throws {
        // Set up at Phase 2 with enough sessions to be eligible for advancement
        manager.currentPhase = .connection
        manager.currentTargetString = nil
        manager.phaseOneCompletedStrings = [4, 5, 6]
        manager.sessionsInCurrentPhase = LearningPhaseManager.minimumSessionsBeforeAdvancement - 1

        // Seed natural notes for all 6 strings above threshold
        for string in 1...6 {
            let naturalCells = manager.naturalNoteCells(onString: string)
            for (note, _) in naturalCells {
                try masteryRepo.save(makeScore(note: note, string: string, total: 10, correct: 9))
            }
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertTrue(advanced)
        XCTAssertEqual(manager.currentPhase, .expansion)
    }

    // MARK: - Diagnostic Mode

    func test_completeDiagnostic_placesOnWeakestString() throws {
        manager.initializeForBaseline(.rustyEverywhere)
        XCTAssertTrue(manager.isInDiagnosticMode)

        // Seed string 5 as strong, strings 4 and 6 weak
        let noteOnStr5 = fretboardMap.note(string: 5, fret: 0)!
        try masteryRepo.save(makeScore(note: noteOnStr5, string: 5, total: 10, correct: 9))

        let scores = try masteryRepo.allScores()
        manager.completeDiagnostic(using: scores)

        XCTAssertFalse(manager.isInDiagnosticMode)
        // Should pick string 4 or 6 (both have no data = 0.5 avg)
        XCTAssertTrue([4, 6].contains(manager.currentTargetString ?? 0))
    }

    // MARK: - Confirmation Mode

    func test_confirmationPassed_addsToCompleted() throws {
        manager.initializeForBaseline(.lowStringsSolid) // string 5, confirmation mode
        XCTAssertTrue(manager.isInConfirmationMode)

        let scores = try masteryRepo.allScores()
        manager.completeConfirmation(passed: true, using: scores)

        XCTAssertFalse(manager.isInConfirmationMode)
        XCTAssertTrue(manager.phaseOneCompletedStrings.contains(5))
    }

    func test_confirmationFailed_staysOnSameString() throws {
        manager.initializeForBaseline(.lowStringsSolid) // string 5
        let originalTarget = manager.currentTargetString

        let scores = try masteryRepo.allScores()
        manager.completeConfirmation(passed: false, using: scores)

        XCTAssertFalse(manager.isInConfirmationMode)
        XCTAssertEqual(manager.currentTargetString, originalTarget)
        XCTAssertFalse(manager.phaseOneCompletedStrings.contains(5))
    }

    // MARK: - Persistence

    func test_persistence_roundTrip() {
        manager.initializeForBaseline(.startingFresh)
        manager.phaseOneCompletedStrings = [4, 6]
        manager.stuckNotes = [StuckNote(noteRaw: 5, stringNumber: 1, phaseWhenStuck: 1)]

        // Create a new manager that loads from the same UserDefaults
        // Note: we need to trigger persistence first
        manager.evaluateAdvancement(using: []) // triggers persist via initializeForBaseline

        let manager2 = LearningPhaseManager(fretboardMap: fretboardMap)
        XCTAssertEqual(manager2.currentPhase, .foundation)
        XCTAssertEqual(manager2.currentTargetString, 1)
    }

    func test_reset_clearsAllState() {
        manager.initializeForBaseline(.startingFresh)
        manager.reset()

        XCTAssertEqual(manager.currentPhase, .foundation)
        XCTAssertNil(manager.currentTargetString)
        XCTAssertTrue(manager.phaseOneCompletedStrings.isEmpty)
        XCTAssertFalse(manager.isInDiagnosticMode)
        XCTAssertFalse(manager.isInConfirmationMode)
        XCTAssertTrue(manager.stuckNotes.isEmpty)
    }

    // MARK: - String Progress

    func test_currentStringProgress() throws {
        manager.initializeForBaseline(.startingFresh) // string 1
        let naturalCells = manager.naturalNoteCells(onString: 1)

        // Seed 3 of 5 natural notes above threshold
        for (index, (note, _)) in naturalCells.enumerated() {
            if index >= 3 { break }
            try masteryRepo.save(makeScore(note: note, string: 1, total: 10, correct: 9))
        }

        let scores = try masteryRepo.allScores()
        let progress = manager.currentStringProgress(using: scores)
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.mastered, 3)
        XCTAssertEqual(progress?.total, 5)
    }

    func test_currentStringProgress_nilForNonFoundation() {
        manager.currentPhase = .connection
        let progress = manager.currentStringProgress(using: [])
        XCTAssertNil(progress)
    }
}
