// BackupPayload.swift
// FretShed — Data Layer
//
// Codable structs for JSON backup/restore of all SwiftData models.
// Decoupled from @Model classes so the backup format can evolve independently.

import Foundation

// MARK: - BackupPayload

struct BackupPayload: Codable {
    let version: Int          // 1 — for future migration
    let exportDate: Date
    let sessions: [SessionBackup]
    let attempts: [AttemptBackup]
    let masteryScores: [MasteryScoreBackup]
    let settings: SettingsBackup?
    let calibrationProfile: CalibrationProfileBackup?
}

// MARK: - BackupImportResult

struct BackupImportResult {
    let sessionsRestored: Int
    let attemptsRestored: Int
    let masteryScoresRestored: Int
    let settingsRestored: Bool
    let calibrationRestored: Bool
}

// MARK: - SessionBackup

struct SessionBackup: Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let focusModeRaw: String
    let gameModeRaw: String
    let attemptCount: Int
    let correctCount: Int
    let masteryDelta: Double
    let notes: [Int]
    let targetStrings: [Int]
    let fretRangeStart: Int
    let fretRangeEnd: Int
    let isCompleted: Bool
    let isPaused: Bool
    let isAdaptive: Bool
    let overallMasteryAtEnd: Double
    let chordProgressionDataBase64: String?

    init(from session: Session) {
        self.id = session.id
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.focusModeRaw = session.focusModeRaw
        self.gameModeRaw = session.gameModeRaw
        self.attemptCount = session.attemptCount
        self.correctCount = session.correctCount
        self.masteryDelta = session.masteryDelta
        self.notes = session.notes
        self.targetStrings = session.targetStrings
        self.fretRangeStart = session.fretRangeStart
        self.fretRangeEnd = session.fretRangeEnd
        self.isCompleted = session.isCompleted
        self.isPaused = session.isPaused
        self.isAdaptive = session.isAdaptive
        self.overallMasteryAtEnd = session.overallMasteryAtEnd
        self.chordProgressionDataBase64 = session.chordProgressionData?.base64EncodedString()
    }

    func toModel() -> Session {
        let session = Session(
            id: id,
            startTime: startTime,
            focusMode: FocusMode(rawValue: focusModeRaw) ?? .fullFretboard,
            gameMode: GameMode(rawValue: gameModeRaw) ?? .untimed,
            fretRangeStart: fretRangeStart,
            fretRangeEnd: fretRangeEnd,
            isAdaptive: isAdaptive
        )
        session.endTime = endTime
        session.attemptCount = attemptCount
        session.correctCount = correctCount
        session.masteryDelta = masteryDelta
        session.notes = notes
        session.targetStrings = targetStrings
        session.isCompleted = isCompleted
        session.isPaused = isPaused
        session.overallMasteryAtEnd = overallMasteryAtEnd
        if let base64 = chordProgressionDataBase64 {
            session.chordProgressionData = Data(base64Encoded: base64)
        }
        return session
    }
}

// MARK: - AttemptBackup

struct AttemptBackup: Codable {
    let id: UUID
    let timestamp: Date
    let targetNoteRaw: Int
    let targetString: Int
    let targetFret: Int
    let playedNoteRaw: Int?
    let playedString: Int?
    let responseTimeMs: Int
    let wasCorrect: Bool
    let sessionID: UUID
    let gameModeRaw: String
    let acceptedAnyString: Bool

    init(from attempt: Attempt) {
        self.id = attempt.id
        self.timestamp = attempt.timestamp
        self.targetNoteRaw = attempt.targetNoteRaw
        self.targetString = attempt.targetString
        self.targetFret = attempt.targetFret
        self.playedNoteRaw = attempt.playedNoteRaw
        self.playedString = attempt.playedString
        self.responseTimeMs = attempt.responseTimeMs
        self.wasCorrect = attempt.wasCorrect
        self.sessionID = attempt.sessionID
        self.gameModeRaw = attempt.gameModeRaw
        self.acceptedAnyString = attempt.acceptedAnyString
    }

    func toModel() -> Attempt {
        Attempt(
            id: id,
            timestamp: timestamp,
            targetNote: MusicalNote(rawValue: targetNoteRaw) ?? .c,
            targetString: targetString,
            targetFret: targetFret,
            playedNote: playedNoteRaw.flatMap { MusicalNote(rawValue: $0) },
            playedString: playedString,
            responseTimeMs: responseTimeMs,
            wasCorrect: wasCorrect,
            sessionID: sessionID,
            gameMode: GameMode(rawValue: gameModeRaw) ?? .untimed,
            acceptedAnyString: acceptedAnyString
        )
    }
}

// MARK: - MasteryScoreBackup

struct MasteryScoreBackup: Codable {
    let id: UUID
    let noteRaw: Int
    let stringNumber: Int
    let totalAttempts: Int
    let correctAttempts: Int
    let lastAttemptDate: Date?
    let bestStreakCount: Int

    init(from score: MasteryScore) {
        self.id = score.id
        self.noteRaw = score.noteRaw
        self.stringNumber = score.stringNumber
        self.totalAttempts = score.totalAttempts
        self.correctAttempts = score.correctAttempts
        self.lastAttemptDate = score.lastAttemptDate
        self.bestStreakCount = score.bestStreakCount
    }

    func toModel() -> MasteryScore {
        let score = MasteryScore(
            id: id,
            note: MusicalNote(rawValue: noteRaw) ?? .c,
            stringNumber: stringNumber
        )
        score.totalAttempts = totalAttempts
        score.correctAttempts = correctAttempts
        score.lastAttemptDate = lastAttemptDate
        score.bestStreakCount = bestStreakCount
        return score
    }
}

// MARK: - SettingsBackup

struct SettingsBackup: Codable {
    let id: UUID
    let confidenceThreshold: Float
    let noteHoldDurationMs: Int
    let forceBuiltInMic: Bool
    let defaultGameModeRaw: String
    let defaultTimerDuration: Int
    let defaultSessionLength: Int
    let hintTimeoutSeconds: Int
    let circleDirectionRaw: String
    let masteryThreshold: Double
    let defaultStringOrderingRaw: String
    let defaultFretboardDisplayRaw: String
    let defaultNoteHighlightingRaw: String
    let defaultNoteAcceptanceModeRaw: String
    let defaultNoteDisplayModeRaw: String
    let correctSoundEnabled: Bool
    let correctSoundVolume: Float
    let incorrectSoundEnabled: Bool
    let isMetronomeEnabled: Bool
    let metronomeVolume: Float
    let hapticFeedbackEnabled: Bool
    let tapModeEnabled: Bool
    let tapToAnswerEnabled: Bool
    let tunerDisplayStyleRaw: String
    let referenceAHz: Int
    let tunerSensitivity: Float
    let practiceReminderEnabled: Bool
    let practiceReminderHour: Int
    let practiceReminderMinute: Int
    let streakReminderEnabled: Bool

    init(from settings: UserSettings) {
        self.id = settings.id
        self.confidenceThreshold = settings.confidenceThreshold
        self.noteHoldDurationMs = settings.noteHoldDurationMs
        self.forceBuiltInMic = settings.forceBuiltInMic
        self.defaultGameModeRaw = settings.defaultGameModeRaw
        self.defaultTimerDuration = settings.defaultTimerDuration
        self.defaultSessionLength = settings.defaultSessionLength
        self.hintTimeoutSeconds = settings.hintTimeoutSeconds
        self.circleDirectionRaw = settings.circleDirectionRaw
        self.masteryThreshold = settings.masteryThreshold
        self.defaultStringOrderingRaw = settings.defaultStringOrderingRaw
        self.defaultFretboardDisplayRaw = settings.defaultFretboardDisplayRaw
        self.defaultNoteHighlightingRaw = settings.defaultNoteHighlightingRaw
        self.defaultNoteAcceptanceModeRaw = settings.defaultNoteAcceptanceModeRaw
        self.defaultNoteDisplayModeRaw = settings.defaultNoteDisplayModeRaw
        self.correctSoundEnabled = settings.correctSoundEnabled
        self.correctSoundVolume = settings.correctSoundVolume
        self.incorrectSoundEnabled = settings.incorrectSoundEnabled
        self.isMetronomeEnabled = settings.isMetronomeEnabled
        self.metronomeVolume = settings.metronomeVolume
        self.hapticFeedbackEnabled = settings.hapticFeedbackEnabled
        self.tapModeEnabled = settings.tapModeEnabled
        self.tapToAnswerEnabled = settings.tapToAnswerEnabled
        self.tunerDisplayStyleRaw = settings.tunerDisplayStyleRaw
        self.referenceAHz = settings.referenceAHz
        self.tunerSensitivity = settings.tunerSensitivity
        self.practiceReminderEnabled = settings.practiceReminderEnabled
        self.practiceReminderHour = settings.practiceReminderHour
        self.practiceReminderMinute = settings.practiceReminderMinute
        self.streakReminderEnabled = settings.streakReminderEnabled
    }

    func applyTo(_ settings: UserSettings) {
        settings.confidenceThreshold = confidenceThreshold
        settings.noteHoldDurationMs = noteHoldDurationMs
        settings.forceBuiltInMic = forceBuiltInMic
        settings.defaultGameModeRaw = defaultGameModeRaw
        settings.defaultTimerDuration = defaultTimerDuration
        settings.defaultSessionLength = defaultSessionLength
        settings.hintTimeoutSeconds = hintTimeoutSeconds
        settings.circleDirectionRaw = circleDirectionRaw
        settings.masteryThreshold = masteryThreshold
        settings.defaultStringOrderingRaw = defaultStringOrderingRaw
        settings.defaultFretboardDisplayRaw = defaultFretboardDisplayRaw
        settings.defaultNoteHighlightingRaw = defaultNoteHighlightingRaw
        settings.defaultNoteAcceptanceModeRaw = defaultNoteAcceptanceModeRaw
        settings.defaultNoteDisplayModeRaw = defaultNoteDisplayModeRaw
        settings.correctSoundEnabled = correctSoundEnabled
        settings.correctSoundVolume = correctSoundVolume
        settings.incorrectSoundEnabled = incorrectSoundEnabled
        settings.isMetronomeEnabled = isMetronomeEnabled
        settings.metronomeVolume = metronomeVolume
        settings.hapticFeedbackEnabled = hapticFeedbackEnabled
        settings.tapModeEnabled = tapModeEnabled
        settings.tapToAnswerEnabled = tapToAnswerEnabled
        settings.tunerDisplayStyleRaw = tunerDisplayStyleRaw
        settings.referenceAHz = referenceAHz
        settings.tunerSensitivity = tunerSensitivity
        settings.practiceReminderEnabled = practiceReminderEnabled
        settings.practiceReminderHour = practiceReminderHour
        settings.practiceReminderMinute = practiceReminderMinute
        settings.streakReminderEnabled = streakReminderEnabled
    }
}

// MARK: - CalibrationProfileBackup

struct CalibrationProfileBackup: Codable {
    let id: UUID
    let inputSourceRaw: String
    let measuredNoiseFloorRMS: Float
    let measuredAGCGain: Float
    let calibrationDate: Date
    let signalQualityScore: Float
    let userGainTrimDB: Float
    let userGateTrimDB: Float
    let stringResultsDataBase64: String

    init(from profile: AudioCalibrationProfile) {
        self.id = profile.id
        self.inputSourceRaw = profile.inputSourceRaw
        self.measuredNoiseFloorRMS = profile.measuredNoiseFloorRMS
        self.measuredAGCGain = profile.measuredAGCGain
        self.calibrationDate = profile.calibrationDate
        self.signalQualityScore = profile.signalQualityScore
        self.userGainTrimDB = profile.userGainTrimDB
        self.userGateTrimDB = profile.userGateTrimDB
        self.stringResultsDataBase64 = profile.stringResultsData.base64EncodedString()
    }

    func toModel() -> AudioCalibrationProfile {
        let stringResults = Data(base64Encoded: stringResultsDataBase64)
            .flatMap { try? JSONDecoder().decode([Int: Bool].self, from: $0) } ?? [:]
        let profile = AudioCalibrationProfile(
            inputSource: AudioInputSource(rawValue: inputSourceRaw) ?? .unknown,
            measuredNoiseFloorRMS: measuredNoiseFloorRMS,
            measuredAGCGain: measuredAGCGain,
            signalQualityScore: signalQualityScore,
            stringResults: stringResults,
            userGainTrimDB: userGainTrimDB,
            userGateTrimDB: userGateTrimDB
        )
        return profile
    }
}
