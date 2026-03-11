// CalibrationEngineTests.swift
// FretShedTests

import XCTest
@testable import FretShed

@MainActor
final class CalibrationEngineTests: XCTestCase {

    // MARK: - Init & Default State

    func test_initialPhase_isWelcome() {
        let engine = CalibrationEngine()
        XCTAssertEqual(engine.phase, .welcome)
    }

    func test_initialStringResults_allFalse() {
        let engine = CalibrationEngine()
        for s in 1...6 {
            XCTAssertEqual(engine.stringResults[s], false, "String \(s) should start as false")
            XCTAssertEqual(engine.frettedStringResults[s], false, "Fretted string \(s) should start as false")
        }
    }

    func test_isRecalibration_defaultFalse() {
        let engine = CalibrationEngine()
        XCTAssertFalse(engine.isRecalibration)
    }

    func test_isRecalibration_whenTrue() {
        let engine = CalibrationEngine(isRecalibration: true)
        XCTAssertTrue(engine.isRecalibration)
    }

    func test_defaultNoiseFloor() {
        let engine = CalibrationEngine()
        XCTAssertEqual(engine.measuredNoiseFloor, 0.01, accuracy: 0.001)
    }

    func test_defaultAGCGain() {
        let engine = CalibrationEngine()
        XCTAssertEqual(engine.measuredAGCGain, 2.0, accuracy: 0.01)
    }

    func test_defaultSignalQuality() {
        let engine = CalibrationEngine()
        XCTAssertEqual(engine.signalQualityScore, 0.0, accuracy: 0.001)
    }

    // MARK: - Static Data Validation

    func test_openStringNotes_hasAllSixStrings() {
        let notes = CalibrationEngine.openStringNotes
        XCTAssertEqual(notes.count, 6)
        let strings = Set(notes.map(\.string))
        XCTAssertEqual(strings, Set(1...6))
    }

    func test_openStringNotes_correctTuning() {
        let notes = CalibrationEngine.openStringNotes
        let lookup = Dictionary(uniqueKeysWithValues: notes.map { ($0.string, $0.note) })
        XCTAssertEqual(lookup[6], .e)   // Low E
        XCTAssertEqual(lookup[5], .a)
        XCTAssertEqual(lookup[4], .d)
        XCTAssertEqual(lookup[3], .g)
        XCTAssertEqual(lookup[2], .b)
        XCTAssertEqual(lookup[1], .e)   // High E
    }

    func test_frettedStringNotes_matchesOpenStrings() {
        // 12th fret should be same note name as open string
        let open = Dictionary(uniqueKeysWithValues: CalibrationEngine.openStringNotes.map { ($0.string, $0.note) })
        let fretted = Dictionary(uniqueKeysWithValues: CalibrationEngine.frettedStringNotes.map { ($0.string, $0.note) })
        for s in 1...6 {
            XCTAssertEqual(open[s], fretted[s], "String \(s) open and 12th fret should be the same note")
        }
    }

    func test_stringNames_hasAllSixStrings() {
        XCTAssertEqual(CalibrationEngine.stringNames.count, 6)
        for s in 1...6 {
            XCTAssertNotNil(CalibrationEngine.stringNames[s], "Missing name for string \(s)")
        }
    }

    // MARK: - Build Profile

    func test_buildProfile_capturesDefaults() {
        let engine = CalibrationEngine()
        let profile = engine.buildProfile()

        XCTAssertEqual(profile.inputSourceRaw, AudioInputSource.unknown.rawValue)
        XCTAssertEqual(profile.measuredNoiseFloorRMS, 0.01, accuracy: 0.001)
        XCTAssertEqual(profile.measuredAGCGain, 2.0, accuracy: 0.01)
        XCTAssertEqual(profile.signalQualityScore, 0.0, accuracy: 0.001)
        XCTAssertEqual(profile.userGainTrimDB, 0.0, accuracy: 0.01)
        XCTAssertEqual(profile.userGateTrimDB, 0.0, accuracy: 0.01)
    }

    func test_buildProfile_stringResults_encoded() {
        let engine = CalibrationEngine()
        let profile = engine.buildProfile()

        // Decode the stored string results
        let decoded = try? JSONDecoder().decode([Int: Bool].self, from: profile.stringResultsData)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 6)
        // All should be false (no strings tested)
        for s in 1...6 {
            XCTAssertEqual(decoded?[s], false)
        }
    }

    func test_buildProfile_frettedStringResults_encoded() {
        let engine = CalibrationEngine()
        let profile = engine.buildProfile()

        let decoded = try? JSONDecoder().decode([Int: Bool].self, from: profile.frettedStringResultsData)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 6)
        for s in 1...6 {
            XCTAssertEqual(decoded?[s], false)
        }
    }

    // MARK: - Phase Helpers

    func test_expectedNote_welcomePhase_isNil() {
        let engine = CalibrationEngine()
        XCTAssertNil(engine.expectedNote)
    }

    func test_currentStringName_welcomePhase_isNil() {
        let engine = CalibrationEngine()
        XCTAssertNil(engine.currentStringName)
    }

    func test_isFrettedPhase_welcomePhase_isFalse() {
        let engine = CalibrationEngine()
        XCTAssertFalse(engine.isFrettedPhase)
    }

    // MARK: - CalibrationPhase Equatable

    func test_phaseEquality() {
        XCTAssertEqual(CalibrationPhase.welcome, CalibrationPhase.welcome)
        XCTAssertEqual(CalibrationPhase.testingString(number: 3), CalibrationPhase.testingString(number: 3))
        XCTAssertNotEqual(CalibrationPhase.testingString(number: 3), CalibrationPhase.testingString(number: 4))
        XCTAssertEqual(CalibrationPhase.measuringNoise(progress: 0.5), CalibrationPhase.measuringNoise(progress: 0.5))
        XCTAssertNotEqual(CalibrationPhase.welcome, CalibrationPhase.complete)
    }
}
