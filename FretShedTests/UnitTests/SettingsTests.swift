// SettingsTests.swift
// FretShed — Unit Tests

import XCTest
import SwiftData
@testable import FretShed

@MainActor
final class SettingsTests: XCTestCase {

    var container: ModelContainer!
    var repo: SwiftDataSettingsRepository!

    override func setUp() async throws {
            try await super.setUp()
            container = try makeModelContainer(inMemory: true)
            repo = SwiftDataSettingsRepository(context: ModelContext(container))
        }

        override func tearDown() async throws {
            container = nil
            repo = nil
            try await super.tearDown()
        }

    // MARK: - Defaults

    func test_loadSettings_firstTime_returnsDefaults() throws {
        let settings = try repo.loadSettings()
        XCTAssertEqual(settings.confidenceThreshold, 0.85, accuracy: 0.001)
        XCTAssertEqual(settings.noteHoldDurationMs, 80)
        XCTAssertFalse(settings.forceBuiltInMic)
        XCTAssertEqual(settings.defaultGameMode, .untimed)
        XCTAssertEqual(settings.defaultTimerDuration, 10)
        XCTAssertEqual(settings.hintTimeoutSeconds, 5)
        XCTAssertEqual(settings.circleDirection, .fourths)
        XCTAssertEqual(settings.masteryThreshold, 0.90, accuracy: 0.001)
        XCTAssertTrue(settings.correctSoundEnabled)
        XCTAssertTrue(settings.isMetronomeEnabled)
        XCTAssertTrue(settings.hapticFeedbackEnabled)
        XCTAssertEqual(settings.tunerDisplayStyle, .needle)
        XCTAssertEqual(settings.referenceAHz, 440)
    }

    // MARK: - Persist and Restore

    func test_saveAndReload_audioSettings() throws {
        let settings = try repo.loadSettings()
        settings.confidenceThreshold = 0.92
        settings.noteHoldDurationMs = 120
        settings.forceBuiltInMic = true
        try repo.saveSettings(settings)

        let repo2 = SwiftDataSettingsRepository(context: ModelContext(container))
        let reloaded = try repo2.loadSettings()
        XCTAssertEqual(reloaded.confidenceThreshold, 0.92, accuracy: 0.001)
        XCTAssertEqual(reloaded.noteHoldDurationMs, 120)
        XCTAssertTrue(reloaded.forceBuiltInMic)
    }

    func test_saveAndReload_quizSettings() throws {
        let settings = try repo.loadSettings()
        settings.defaultGameMode = .streak
        settings.defaultTimerDuration = 15
        settings.hintTimeoutSeconds = 3
        settings.circleDirection = .fifths
        settings.masteryThreshold = 0.85
        settings.defaultStringOrdering = .inOrder
        settings.defaultNoteAcceptanceMode = .anyString
        try repo.saveSettings(settings)

        let repo2 = SwiftDataSettingsRepository(context: ModelContext(container))
        let reloaded = try repo2.loadSettings()
        XCTAssertEqual(reloaded.defaultGameMode, .streak)
        XCTAssertEqual(reloaded.defaultTimerDuration, 15)
        XCTAssertEqual(reloaded.hintTimeoutSeconds, 3)
        XCTAssertEqual(reloaded.circleDirection, .fifths)
        XCTAssertEqual(reloaded.masteryThreshold, 0.85, accuracy: 0.001)
        XCTAssertEqual(reloaded.defaultStringOrdering, .inOrder)
        XCTAssertEqual(reloaded.defaultNoteAcceptanceMode, .anyString)
    }

    func test_saveAndReload_soundSettings() throws {
        let settings = try repo.loadSettings()
        settings.correctSoundEnabled = false
        settings.correctSoundVolume = 0.3
        settings.incorrectSoundEnabled = false
        settings.isMetronomeEnabled = false
        settings.metronomeVolume = 0.5
        settings.hapticFeedbackEnabled = false
        try repo.saveSettings(settings)

        let repo2 = SwiftDataSettingsRepository(context: ModelContext(container))
        let reloaded = try repo2.loadSettings()
        XCTAssertFalse(reloaded.correctSoundEnabled)
        XCTAssertEqual(reloaded.correctSoundVolume, 0.3, accuracy: 0.001)
        XCTAssertFalse(reloaded.incorrectSoundEnabled)
        XCTAssertFalse(reloaded.isMetronomeEnabled)
        XCTAssertFalse(reloaded.hapticFeedbackEnabled)
    }

    func test_saveAndReload_tunerSettings() throws {
        let settings = try repo.loadSettings()
        settings.tunerDisplayStyle = .strobe
        settings.referenceAHz = 432
        settings.tunerSensitivity = 0.7
        try repo.saveSettings(settings)

        let repo2 = SwiftDataSettingsRepository(context: ModelContext(container))
        let reloaded = try repo2.loadSettings()
        XCTAssertEqual(reloaded.tunerDisplayStyle, .strobe)
        XCTAssertEqual(reloaded.referenceAHz, 432)
        XCTAssertEqual(reloaded.tunerSensitivity, 0.7, accuracy: 0.001)
    }

    func test_saveAndReload_notificationSettings() throws {
        let settings = try repo.loadSettings()
        settings.practiceReminderEnabled = true
        settings.practiceReminderHour = 20
        settings.practiceReminderMinute = 30
        settings.streakReminderEnabled = true
        try repo.saveSettings(settings)

        let repo2 = SwiftDataSettingsRepository(context: ModelContext(container))
        let reloaded = try repo2.loadSettings()
        XCTAssertTrue(reloaded.practiceReminderEnabled)
        XCTAssertEqual(reloaded.practiceReminderHour, 20)
        XCTAssertEqual(reloaded.practiceReminderMinute, 30)
        XCTAssertTrue(reloaded.streakReminderEnabled)
    }

    // MARK: - Enum Round-trips

    func test_allGameModes_persistAndRestore() throws {
        for mode in GameMode.allCases {
            let settings = try repo.loadSettings()
            settings.defaultGameMode = mode
            try repo.saveSettings(settings)
            let reloaded = try repo.loadSettings()
            XCTAssertEqual(reloaded.defaultGameMode, mode)
        }
    }

    func test_allCircleDirections_persistAndRestore() throws {
        for direction in CircleDirection.allCases {
            let settings = try repo.loadSettings()
            settings.circleDirection = direction
            try repo.saveSettings(settings)
            let reloaded = try repo.loadSettings()
            XCTAssertEqual(reloaded.circleDirection, direction)
        }
    }

    func test_allTunerDisplayStyles_persistAndRestore() throws {
        for style in TunerDisplayStyle.allCases {
            let settings = try repo.loadSettings()
            settings.tunerDisplayStyle = style
                        try repo.saveSettings(settings)
                        let reloaded = try repo.loadSettings()
                        XCTAssertEqual(reloaded.tunerDisplayStyle, style)
                    }
                }

                // MARK: - LocalUserPreferences Keys

                func test_localPreferencesKeys_areNonEmpty() {
                    XCTAssertFalse(LocalUserPreferences.Key.hasCompletedOnboarding.isEmpty)
                    XCTAssertFalse(LocalUserPreferences.Key.noteNameFormat.isEmpty)
                    XCTAssertFalse(LocalUserPreferences.Key.fretboardOrientation.isEmpty)
                }

                func test_localPreferencesDefaults_areValid() {
                    XCTAssertFalse(LocalUserPreferences.Default.hasCompletedOnboarding)
                    XCTAssertEqual(LocalUserPreferences.Default.noteNameFormat,
                                   NoteNameFormat.sharps.rawValue)
                    XCTAssertEqual(LocalUserPreferences.Default.fretboardOrientation,
                                   FretboardOrientation.rightHand.rawValue)
                    XCTAssertEqual(LocalUserPreferences.Default.defaultFretCount,
                                   DefaultFretCount.twentyTwo.rawValue)
                }
            }
