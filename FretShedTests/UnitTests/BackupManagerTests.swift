// BackupManagerTests.swift
// FretShedTests

import XCTest
import SwiftData
@testable import FretShed

@MainActor
final class BackupManagerTests: XCTestCase {

    var appContainer: AppContainer!
    var manager: BackupManager!

    override func setUp() async throws {
        try await super.setUp()
        appContainer = AppContainer.makeForTesting()
        manager = BackupManager(container: appContainer)
    }

    override func tearDown() async throws {
        appContainer = nil
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Export

    func test_exportBackup_createsFile() throws {
        let url = try manager.exportBackup()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }

    func test_exportBackup_isValidJSON() throws {
        let url = try manager.exportBackup()
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["version"] as? Int, 1)
        try? FileManager.default.removeItem(at: url)
    }

    func test_exportBackup_includesSessions() throws {
        let session = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session.attemptCount = 15
        session.correctCount = 12
        session.isCompleted = true
        try appContainer.sessionRepository.save(session)

        let url = try manager.exportBackup()
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)

        XCTAssertEqual(payload.sessions.count, 1)
        XCTAssertEqual(payload.sessions[0].attemptCount, 15)
        XCTAssertEqual(payload.sessions[0].correctCount, 12)
        XCTAssertTrue(payload.sessions[0].isCompleted)
        try? FileManager.default.removeItem(at: url)
    }

    func test_exportBackup_includesCalibrationProfiles() throws {
        let profile = AudioCalibrationProfile(
            inputSource: .builtInMic,
            measuredNoiseFloorRMS: 0.02,
            measuredAGCGain: 1.5,
            signalQualityScore: 0.83,
            stringResults: [1: true, 2: true, 3: true, 4: true, 5: true, 6: false],
            name: "Strat",
            guitarType: .electric,
            isActive: true
        )
        try appContainer.calibrationRepository.save(profile)

        let url = try manager.exportBackup()
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)

        XCTAssertEqual(payload.calibrationProfiles.count, 1)
        XCTAssertEqual(payload.calibrationProfiles[0].name, "Strat")
        XCTAssertEqual(payload.calibrationProfiles[0].guitarTypeRaw, "electric")
        XCTAssertEqual(payload.calibrationProfiles[0].measuredNoiseFloorRMS, 0.02, accuracy: 0.001)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Round Trip

    func test_roundTrip_sessions() throws {
        let session = Session(focusMode: .singleString, gameMode: .timed, sessionTimeLimitSeconds: 180)
        session.attemptCount = 25
        session.correctCount = 20
        session.isCompleted = true
        session.targetStrings = [3]
        session.fretRangeStart = 0
        session.fretRangeEnd = 12
        session.isAdaptive = true
        try appContainer.sessionRepository.save(session)

        let url = try manager.exportBackup()
        let result = try manager.importBackup(from: url)

        XCTAssertEqual(result.sessionsRestored, 1)
        let restored = try appContainer.sessionRepository.allSessions()
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].focusMode, .singleString)
        XCTAssertEqual(restored[0].gameMode, .timed)
        XCTAssertEqual(restored[0].attemptCount, 25)
        XCTAssertEqual(restored[0].correctCount, 20)
        XCTAssertEqual(restored[0].targetStrings, [3])
        XCTAssertEqual(restored[0].sessionTimeLimitSeconds, 180)
        XCTAssertTrue(restored[0].isAdaptive)
        try? FileManager.default.removeItem(at: url)
    }

    func test_roundTrip_attempts() throws {
        let sessionID = UUID()
        let attempt = Attempt(
            targetNote: .a,
            targetString: 3,
            targetFret: 2,
            playedNote: .a,
            playedString: 3,
            responseTimeMs: 1200,
            wasCorrect: true,
            sessionID: sessionID,
            gameMode: .untimed,
            acceptedAnyString: false,
            detectedFrequencyHz: 440.0,
            detectedConfidence: 0.95,
            centsDeviation: -2.5
        )
        try appContainer.attemptRepository.save(attempt)

        let url = try manager.exportBackup()
        let result = try manager.importBackup(from: url)

        XCTAssertEqual(result.attemptsRestored, 1)
        let restored = try appContainer.attemptRepository.allAttempts()
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].targetNote, .a)
        XCTAssertEqual(restored[0].targetString, 3)
        XCTAssertEqual(restored[0].wasCorrect, true)
        XCTAssertEqual(restored[0].detectedFrequencyHz ?? 0, 440.0, accuracy: 0.01)
        try? FileManager.default.removeItem(at: url)
    }

    func test_roundTrip_masteryScores() throws {
        let score = MasteryScore(note: .g, stringNumber: 3)
        score.totalAttempts = 30
        score.correctAttempts = 27
        score.bestStreakCount = 12
        try appContainer.masteryRepository.save(score)

        let url = try manager.exportBackup()
        let result = try manager.importBackup(from: url)

        XCTAssertEqual(result.masteryScoresRestored, 1)
        let restored = try appContainer.masteryRepository.allScores()
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].note, .g)
        XCTAssertEqual(restored[0].stringNumber, 3)
        XCTAssertEqual(restored[0].totalAttempts, 30)
        XCTAssertEqual(restored[0].correctAttempts, 27)
        XCTAssertEqual(restored[0].bestStreakCount, 12)
        try? FileManager.default.removeItem(at: url)
    }

    func test_roundTrip_settings() throws {
        let settings = try appContainer.settingsRepository.loadSettings()
        settings.referenceAHz = 432
        settings.confidenceThreshold = 0.90
        settings.hapticFeedbackEnabled = false
        try appContainer.settingsRepository.saveSettings(settings)

        let url = try manager.exportBackup()
        let result = try manager.importBackup(from: url)

        XCTAssertTrue(result.settingsRestored)
        let restored = try appContainer.settingsRepository.loadSettings()
        XCTAssertEqual(restored.referenceAHz, 432)
        XCTAssertEqual(restored.confidenceThreshold, 0.90, accuracy: 0.01)
        XCTAssertEqual(restored.hapticFeedbackEnabled, false)
        try? FileManager.default.removeItem(at: url)
    }

    func test_roundTrip_multipleCalibrationProfiles() throws {
        let profile1 = AudioCalibrationProfile(
            inputSource: .builtInMic,
            measuredNoiseFloorRMS: 0.02,
            measuredAGCGain: 1.5,
            signalQualityScore: 0.83,
            stringResults: [1: true, 2: true, 3: true, 4: true, 5: true, 6: true],
            name: "Strat",
            guitarType: .electric,
            isActive: true
        )
        let profile2 = AudioCalibrationProfile(
            inputSource: .usbInterface,
            measuredNoiseFloorRMS: 0.005,
            measuredAGCGain: 0.8,
            signalQualityScore: 1.0,
            stringResults: [1: true, 2: true, 3: true, 4: true, 5: true, 6: true],
            name: "Acoustic",
            guitarType: .acoustic,
            isActive: false
        )
        try appContainer.calibrationRepository.save(profile1)
        try appContainer.calibrationRepository.save(profile2)

        let url = try manager.exportBackup()
        let result = try manager.importBackup(from: url)

        XCTAssertTrue(result.calibrationRestored)
        let restored = try appContainer.calibrationRepository.allProfiles()
        XCTAssertEqual(restored.count, 2)
        let names = Set(restored.compactMap(\.name))
        XCTAssertTrue(names.contains("Strat"))
        XCTAssertTrue(names.contains("Acoustic"))
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Import Clears Existing Data

    func test_import_deletesExistingDataFirst() throws {
        // Seed two sessions
        let session1 = Session(focusMode: .fullFretboard, gameMode: .untimed)
        session1.isCompleted = true
        try appContainer.sessionRepository.save(session1)
        let session2 = Session(focusMode: .singleString, gameMode: .timed)
        session2.isCompleted = true
        try appContainer.sessionRepository.save(session2)

        // Export with 2 sessions
        let url = try manager.exportBackup()

        // Add a third session after export
        let session3 = Session(focusMode: .singleNote, gameMode: .untimed)
        try appContainer.sessionRepository.save(session3)

        // Import should replace all with the 2 from backup
        let result = try manager.importBackup(from: url)
        XCTAssertEqual(result.sessionsRestored, 2)
        let restored = try appContainer.sessionRepository.allSessions()
        XCTAssertEqual(restored.count, 2)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Backward Compatibility

    func test_v1Decode_singleCalibrationProfile() throws {
        // Simulate v1 JSON with singular "calibrationProfile" key
        let json: [String: Any] = [
            "version": 1,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "sessions": [],
            "attempts": [],
            "masteryScores": [],
            "calibrationProfile": [
                "id": UUID().uuidString,
                "inputSourceRaw": "builtInMic",
                "measuredNoiseFloorRMS": 0.02,
                "measuredAGCGain": 1.5,
                "calibrationDate": ISO8601DateFormatter().string(from: Date()),
                "signalQualityScore": 0.83,
                "userGainTrimDB": 0.0,
                "userGateTrimDB": 0.0,
                "stringResultsDataBase64": Data("{}".utf8).base64EncodedString()
            ] as [String: Any]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)

        XCTAssertEqual(payload.calibrationProfiles.count, 1)
        XCTAssertEqual(payload.calibrationProfiles[0].inputSourceRaw, "builtInMic")
    }

    func test_decode_missingOptionalFields() throws {
        // SessionBackup without sessionTimeLimitSeconds or calibrationProfileID
        let json: [String: Any] = [
            "version": 1,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "sessions": [[
                "id": UUID().uuidString,
                "startTime": ISO8601DateFormatter().string(from: Date()),
                "focusModeRaw": "fullFretboard",
                "gameModeRaw": "untimed",
                "attemptCount": 10,
                "correctCount": 8,
                "masteryDelta": 0.05,
                "notes": [Int](),
                "targetStrings": [Int](),
                "fretRangeStart": 0,
                "fretRangeEnd": 12,
                "isCompleted": true,
                "isPaused": false,
                "isAdaptive": false,
                "overallMasteryAtEnd": 0.80
            ] as [String: Any]],
            "attempts": [],
            "masteryScores": [],
            "calibrationProfiles": []
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)

        XCTAssertEqual(payload.sessions.count, 1)
        XCTAssertNil(payload.sessions[0].sessionTimeLimitSeconds)
        XCTAssertNil(payload.sessions[0].calibrationProfileID)

        // toModel should default sessionTimeLimitSeconds to 0
        let session = payload.sessions[0].toModel()
        XCTAssertEqual(session.sessionTimeLimitSeconds, 0)
    }

    // MARK: - Diagnostic Report

    func test_diagnosticReport_createsFile() throws {
        let sessionID = UUID()
        let attempt = Attempt(
            targetNote: .c,
            targetString: 5,
            targetFret: 3,
            playedNote: .c,
            playedString: 5,
            responseTimeMs: 800,
            wasCorrect: true,
            sessionID: sessionID,
            gameMode: .untimed,
            acceptedAnyString: false
        )
        try appContainer.attemptRepository.save(attempt)

        let url = try manager.exportDiagnosticReport(sessionID: sessionID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(DiagnosticReport.self, from: data)

        XCTAssertEqual(report.version, 1)
        XCTAssertEqual(report.sessionID, sessionID)
        XCTAssertEqual(report.attemptCount, 1)
        XCTAssertEqual(report.attempts.count, 1)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Version Check

    func test_import_rejectsUnsupportedVersion() throws {
        let json: [String: Any] = [
            "version": 99,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "sessions": [],
            "attempts": [],
            "masteryScores": [],
            "calibrationProfiles": []
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-v99.json")
        try data.write(to: tempURL)

        XCTAssertThrowsError(try manager.importBackup(from: tempURL)) { error in
            XCTAssertTrue(error is BackupError)
        }
        try? FileManager.default.removeItem(at: tempURL)
    }
}
