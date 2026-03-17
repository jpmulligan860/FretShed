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

    /// Seeds all natural notes on frets 0-12 for a given string above advancement threshold.
    private func seedNaturalsAboveThreshold(string: Int) throws {
        let naturalCells = manager.naturalNoteCells(onString: string, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)
        for (note, _) in naturalCells {
            try masteryRepo.save(makeScore(note: note, string: string, total: 10, correct: 9))
        }
    }

    /// Seeds ALL chromatic notes on frets 0-12 for a given string above advancement threshold.
    private func seedChromaticAboveThreshold(string: Int) throws {
        let cells = manager.chromaticCells(onString: string, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)
        for (note, _) in cells {
            try masteryRepo.save(makeScore(note: note, string: string, total: 10, correct: 9))
        }
    }

    // MARK: - LearningPhase Enum (v2 ordering)

    func test_phaseOrder_v2() {
        XCTAssertEqual(LearningPhase.foundation.rawValue, 1)
        XCTAssertEqual(LearningPhase.expansion.rawValue, 2)
        XCTAssertEqual(LearningPhase.connection.rawValue, 3)
        XCTAssertEqual(LearningPhase.fluency.rawValue, 4)
    }

    func test_phaseNext_v2() {
        XCTAssertEqual(LearningPhase.foundation.next, .expansion)
        XCTAssertEqual(LearningPhase.expansion.next, .connection)
        XCTAssertEqual(LearningPhase.connection.next, .fluency)
        XCTAssertNil(LearningPhase.fluency.next)
    }

    func test_phaseDisplayNames() {
        XCTAssertEqual(LearningPhase.foundation.displayName, "Foundation")
        XCTAssertEqual(LearningPhase.expansion.displayName, "Expansion")
        XCTAssertEqual(LearningPhase.connection.displayName, "Connection")
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
        XCTAssertTrue(manager.phaseTwoCompletedStrings.isEmpty)
        XCTAssertNil(manager.currentPhaseTwoTargetString)
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

    // MARK: - Natural Note Cells (frets 0-12)

    func test_naturalNoteCells_highEString_frets0to12() {
        // String 1 (high E) frets 0-12: E(0), F(1), G(3), A(5), B(7), C(8), D(10), E(12 — dupe)
        // = 7 unique natural notes
        let cells = manager.naturalNoteCells(onString: 1, fretEnd: 12)
        let noteNames = cells.map { $0.note.sharpName }
        XCTAssertEqual(cells.count, 7)
        XCTAssertTrue(noteNames.contains("E"))
        XCTAssertTrue(noteNames.contains("F"))
        XCTAssertTrue(noteNames.contains("G"))
        XCTAssertTrue(noteNames.contains("A"))
        XCTAssertTrue(noteNames.contains("B"))
        XCTAssertTrue(noteNames.contains("C"))
        XCTAssertTrue(noteNames.contains("D"))
    }

    func test_naturalNoteCells_deduplicates() {
        for string in 1...6 {
            let cells = manager.naturalNoteCells(onString: string, fretEnd: 12)
            let noteRaws = cells.map { $0.note.rawValue }
            XCTAssertEqual(noteRaws.count, Set(noteRaws).count,
                           "Duplicate notes found on string \(string)")
        }
    }

    // MARK: - Chromatic Cells

    func test_chromaticCells_highEString_frets0to12() {
        // String 1 (high E) frets 0-12: 12 unique notes (E repeats at fret 12)
        let cells = manager.chromaticCells(onString: 1, fretEnd: 12)
        XCTAssertEqual(cells.count, 12) // All 12 chromatic notes
    }

    func test_chromaticCells_deduplicates() {
        for string in 1...6 {
            let cells = manager.chromaticCells(onString: string, fretEnd: 12)
            let noteRaws = cells.map { $0.note.rawValue }
            XCTAssertEqual(noteRaws.count, Set(noteRaws).count,
                           "Duplicate notes found on string \(string)")
        }
    }

    // MARK: - Phase 1 Advancement (requires all 6 strings, frets 0-12)

    func test_advancement_allNaturalNotesMastered_advances() throws {
        manager.initializeForBaseline(.startingFresh) // string 1
        let targetString = 1

        let naturalCells = manager.naturalNoteCells(onString: targetString, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)
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
        let naturalCells = manager.naturalNoteCells(onString: targetString, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)

        for (index, (note, fret)) in naturalCells.enumerated() {
            if index == naturalCells.count - 1 && fret != 0 {
                try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 4))
            } else {
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
        let naturalCells = manager.naturalNoteCells(onString: targetString, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)

        for (index, (note, _)) in naturalCells.enumerated() {
            if index == 0 {
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
        let naturalCells = manager.naturalNoteCells(onString: targetString, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)

        var stuckCount = 0
        for (note, fret) in naturalCells {
            if fret != 0 && stuckCount < 2 {
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
        manager.initializeForBaseline(.startingFresh)
        let targetString = 1
        let naturalCells = manager.naturalNoteCells(onString: targetString, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)

        for (index, (note, _)) in naturalCells.enumerated() {
            if index == naturalCells.count - 1 { continue }
            try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 9))
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertFalse(advanced, "Cells with 0 attempts should not count as passed")
    }

    func test_advancement_allSixStringsCompleted_advancesToExpansion() throws {
        manager.initializeForBaseline(.startingFresh)

        // Complete all 6 strings
        for string in [6, 5, 4, 3, 2, 1] {
            manager.currentTargetString = string
            try seedNaturalsAboveThreshold(string: string)
            let scores = try masteryRepo.allScores()
            manager.evaluateAdvancement(using: scores)
        }

        XCTAssertEqual(manager.currentPhase, .expansion, "Should advance to Expansion after 6 strings")
        XCTAssertNil(manager.currentTargetString)
        XCTAssertNotNil(manager.currentPhaseTwoTargetString, "Should assign Phase 2 target string")
        XCTAssertEqual(manager.phaseOneCompletedStrings.count, 6)
    }

    func test_advancement_threeStringsCompleted_doesNotAdvance() throws {
        manager.initializeForBaseline(.startingFresh)

        // Complete only 3 strings (was enough in v1, not in v2)
        for string in [6, 5, 4] {
            manager.currentTargetString = string
            try seedNaturalsAboveThreshold(string: string)
            let scores = try masteryRepo.allScores()
            manager.evaluateAdvancement(using: scores)
        }

        XCTAssertEqual(manager.currentPhase, .foundation, "Should NOT advance with only 3 strings")
        XCTAssertEqual(manager.phaseOneCompletedStrings.count, 3)
        XCTAssertNotNil(manager.currentTargetString, "Should move to next uncompleted string")
    }

    // MARK: - Phase 1 uses frets 0-12 (not 0-7)

    func test_advancement_frets0to7only_doesNotAdvance() throws {
        manager.initializeForBaseline(.startingFresh)
        let targetString = 1

        // Only seed natural notes for frets 0-7 (the old range)
        let partialCells = manager.naturalNoteCells(onString: targetString, fretEnd: 7)
        for (note, _) in partialCells {
            try masteryRepo.save(makeScore(note: note, string: targetString, total: 10, correct: 9))
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        // Should NOT advance because frets 8-12 naturals are not covered
        let fullCells = manager.naturalNoteCells(onString: targetString, fretEnd: 12)
        if fullCells.count > partialCells.count {
            XCTAssertFalse(advanced, "Should not advance with only frets 0-7 mastered")
        }
    }

    // MARK: - Phase 2 (Expansion) Advancement

    func test_expansionAdvancement_perStringTracking() throws {
        // Set up at Phase 2
        manager.currentPhase = .expansion
        manager.phaseOneCompletedStrings = Set(1...6)
        manager.currentPhaseTwoTargetString = 6
        manager.sessionsInCurrentPhase = LearningPhaseManager.minimumSessionsBeforeAdvancement - 1

        // Seed all chromatic notes on string 6
        try seedChromaticAboveThreshold(string: 6)

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertTrue(advanced, "Should complete string 6 in Phase 2")
        XCTAssertTrue(manager.phaseTwoCompletedStrings.contains(6))
        // Shouldn't advance to Connection yet (only 1 of 6 strings done)
        XCTAssertEqual(manager.currentPhase, .expansion)
    }

    func test_expansionAdvancement_allSixStrings_advancesToConnection() throws {
        manager.currentPhase = .expansion
        manager.phaseOneCompletedStrings = Set(1...6)
        manager.sessionsInCurrentPhase = LearningPhaseManager.minimumSessionsBeforeAdvancement - 1

        // Complete all 6 strings chromatically
        for string in [6, 5, 4, 3, 2, 1] {
            manager.currentPhaseTwoTargetString = string
            try seedChromaticAboveThreshold(string: string)
            let scores = try masteryRepo.allScores()
            manager.evaluateAdvancement(using: scores)
        }

        XCTAssertEqual(manager.currentPhase, .connection, "Should advance to Connection after all 6 strings chromatic")
        XCTAssertEqual(manager.phaseTwoCompletedStrings.count, 6)
    }

    func test_expansionAdvancement_graceThreshold() throws {
        manager.currentPhase = .expansion
        manager.phaseOneCompletedStrings = Set(1...6)
        manager.currentPhaseTwoTargetString = 1
        manager.sessionsInCurrentPhase = LearningPhaseManager.minimumSessionsBeforeAdvancement - 1

        let cells = manager.chromaticCells(onString: 1, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)
        for (index, (note, _)) in cells.enumerated() {
            if index == cells.count - 1 {
                // Last note at grace floor
                try masteryRepo.save(makeScore(note: note, string: 1, total: 10, correct: 4))
            } else {
                try masteryRepo.save(makeScore(note: note, string: 1, total: 10, correct: 9))
            }
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertTrue(advanced, "Should advance with 1 grace note in Phase 2")
        XCTAssertTrue(manager.phaseTwoCompletedStrings.contains(1))
        XCTAssertEqual(manager.stuckNotes.count, 1)
    }

    // MARK: - Phase 2 String Progress

    func test_currentPhaseTwoStringProgress() throws {
        manager.currentPhase = .expansion
        manager.currentPhaseTwoTargetString = 1

        let cells = manager.chromaticCells(onString: 1, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)
        // Seed half the chromatic notes above threshold
        let halfCount = cells.count / 2
        for (index, (note, _)) in cells.enumerated() {
            if index >= halfCount { break }
            try masteryRepo.save(makeScore(note: note, string: 1, total: 10, correct: 9))
        }

        let scores = try masteryRepo.allScores()
        let progress = manager.currentPhaseTwoStringProgress(using: scores)
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.mastered, halfCount)
        XCTAssertEqual(progress?.total, cells.count)
    }

    // MARK: - Phase 3 (Connection) → Phase 4 Advancement

    func test_connectionToFluency_requiresAllChromaticCrossString() throws {
        manager.currentPhase = .connection
        manager.phaseOneCompletedStrings = Set(1...6)
        manager.phaseTwoCompletedStrings = Set(1...6)
        manager.sessionsInCurrentPhase = LearningPhaseManager.minimumSessionsBeforeAdvancement - 1

        // Seed all chromatic notes on all 6 strings
        for string in 1...6 {
            try seedChromaticAboveThreshold(string: string)
        }

        let scores = try masteryRepo.allScores()
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertTrue(advanced)
        XCTAssertEqual(manager.currentPhase, .fluency)
    }

    // MARK: - Phase Never Regresses

    func test_phaseNeverRegresses() throws {
        manager.currentPhase = .expansion
        manager.phaseOneCompletedStrings = Set(1...6)

        let scores: [MasteryScore] = []
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertFalse(advanced)
        XCTAssertEqual(manager.currentPhase, .expansion, "Phase should never regress")
    }

    // MARK: - Minimum Sessions Before Advancement

    func test_expansionAdvancement_blockedByMinimumSessions() throws {
        manager.currentPhase = .expansion
        manager.phaseOneCompletedStrings = Set(1...6)
        manager.sessionsInCurrentPhase = 0 // Not enough sessions yet

        // Complete all 6 strings chromatically
        for string in 1...6 {
            try seedChromaticAboveThreshold(string: string)
        }

        let scores = try masteryRepo.allScores()
        // First evaluation: sessionsInCurrentPhase becomes 1, still below minimum
        let advanced = manager.evaluateAdvancement(using: scores)
        XCTAssertFalse(advanced, "Should be blocked by minimum sessions requirement")
    }

    // MARK: - v2 Migration

    func test_v2Migration_defensive() {
        // Simulate pre-v2 state where connection=2
        UserDefaults.standard.removeObject(forKey: "learningPhase_v2Migrated")
        UserDefaults.standard.set(2, forKey: "learningPhase_current") // was connection

        let migrated = LearningPhaseManager(fretboardMap: fretboardMap)
        // After migration, raw value 2 = expansion (the new Phase 2)
        XCTAssertEqual(migrated.currentPhase, .expansion)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "learningPhase_v2Migrated"))
        migrated.reset()
    }

    func test_v2Migration_runsOnlyOnce() {
        UserDefaults.standard.removeObject(forKey: "learningPhase_v2Migrated")
        UserDefaults.standard.set(2, forKey: "learningPhase_current")

        let _ = LearningPhaseManager(fretboardMap: fretboardMap)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "learningPhase_v2Migrated"))

        // Set to a different value and create again — migration should not run
        UserDefaults.standard.set(3, forKey: "learningPhase_current")
        let second = LearningPhaseManager(fretboardMap: fretboardMap)
        XCTAssertEqual(second.currentPhase, .connection) // raw 3 = connection, not re-migrated
        second.reset()
    }

    // MARK: - Diagnostic Mode

    func test_completeDiagnostic_placesOnWeakestString() throws {
        manager.initializeForBaseline(.rustyEverywhere)
        XCTAssertTrue(manager.isInDiagnosticMode)

        let noteOnStr5 = fretboardMap.note(string: 5, fret: 0)!
        try masteryRepo.save(makeScore(note: noteOnStr5, string: 5, total: 10, correct: 9))

        let scores = try masteryRepo.allScores()
        manager.completeDiagnostic(using: scores)

        XCTAssertFalse(manager.isInDiagnosticMode)
        // Should pick any string that's weaker than string 5
        XCTAssertNotEqual(manager.currentTargetString, 5)
    }

    // MARK: - Confirmation Mode

    func test_confirmationPassed_addsToCompleted() throws {
        manager.initializeForBaseline(.lowStringsSolid)
        XCTAssertTrue(manager.isInConfirmationMode)

        let scores = try masteryRepo.allScores()
        manager.completeConfirmation(passed: true, using: scores)

        XCTAssertFalse(manager.isInConfirmationMode)
        XCTAssertTrue(manager.phaseOneCompletedStrings.contains(5))
    }

    func test_confirmationFailed_staysOnSameString() throws {
        manager.initializeForBaseline(.lowStringsSolid)
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

        manager.evaluateAdvancement(using: []) // triggers persist

        let manager2 = LearningPhaseManager(fretboardMap: fretboardMap)
        XCTAssertEqual(manager2.currentPhase, .foundation)
        XCTAssertEqual(manager2.currentTargetString, 1)
    }

    func test_reset_clearsAllState() {
        manager.initializeForBaseline(.startingFresh)
        manager.phaseTwoCompletedStrings = [1, 2]
        manager.currentPhaseTwoTargetString = 3
        manager.reset()

        XCTAssertEqual(manager.currentPhase, .foundation)
        XCTAssertNil(manager.currentTargetString)
        XCTAssertTrue(manager.phaseOneCompletedStrings.isEmpty)
        XCTAssertTrue(manager.phaseTwoCompletedStrings.isEmpty)
        XCTAssertNil(manager.currentPhaseTwoTargetString)
        XCTAssertFalse(manager.isInDiagnosticMode)
        XCTAssertFalse(manager.isInConfirmationMode)
        XCTAssertTrue(manager.stuckNotes.isEmpty)
    }

    // MARK: - String Progress

    func test_currentStringProgress() throws {
        manager.initializeForBaseline(.startingFresh) // string 1
        let naturalCells = manager.naturalNoteCells(onString: 1, fretEnd: LearningPhaseManager.phaseRequiredFretEnd)

        // Seed 3 natural notes above threshold
        for (index, (note, _)) in naturalCells.enumerated() {
            if index >= 3 { break }
            try masteryRepo.save(makeScore(note: note, string: 1, total: 10, correct: 9))
        }

        let scores = try masteryRepo.allScores()
        let progress = manager.currentStringProgress(using: scores)
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.mastered, 3)
        XCTAssertEqual(progress?.total, naturalCells.count)
    }

    func test_currentStringProgress_nilForNonFoundation() {
        manager.currentPhase = .expansion
        let progress = manager.currentStringProgress(using: [])
        XCTAssertNil(progress)
    }
}
