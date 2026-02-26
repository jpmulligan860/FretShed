// BackupManager.swift
// FretShed — Data Layer
//
// Exports and imports JSON backups of all SwiftData models.

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "BackupManager")

// MARK: - BackupManager

@MainActor
struct BackupManager {

    let container: AppContainer

    // MARK: - Export

    func exportBackup() throws -> URL {
        // Fetch all data
        let sessions = try container.sessionRepository.allSessions()
        let attempts = try container.attemptRepository.allAttempts()
        let masteryScores = try container.masteryRepository.allScores()
        let settings = try? container.settingsRepository.loadSettings()
        let calibration = try? container.calibrationRepository.activeProfile()

        let payload = BackupPayload(
            version: 1,
            exportDate: Date(),
            sessions: sessions.map { SessionBackup(from: $0) },
            attempts: attempts.map { AttemptBackup(from: $0) },
            masteryScores: masteryScores.map { MasteryScoreBackup(from: $0) },
            settings: settings.map { SettingsBackup(from: $0) },
            calibrationProfile: calibration.map { CalibrationProfileBackup(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let fileName = "FretShed-Backup-\(dateFormatter.string(from: Date())).json"

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)

        logger.info("Backup exported: \(sessions.count) sessions, \(attempts.count) attempts, \(masteryScores.count) mastery scores")
        return fileURL
    }

    // MARK: - Import

    func importBackup(from url: URL) throws -> BackupImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)

        guard payload.version == 1 else {
            throw BackupError.unsupportedVersion(payload.version)
        }

        // Delete existing data (same scope as deleteAllData)
        try container.sessionRepository.deleteAll()
        try container.attemptRepository.deleteAll()
        try container.masteryRepository.deleteAll()

        // Restore sessions
        for backup in payload.sessions {
            let session = backup.toModel()
            try container.sessionRepository.save(session)
        }

        // Restore attempts
        for backup in payload.attempts {
            let attempt = backup.toModel()
            try container.attemptRepository.save(attempt)
        }

        // Restore mastery scores
        for backup in payload.masteryScores {
            let score = backup.toModel()
            try container.masteryRepository.save(score)
        }

        // Restore settings
        var settingsRestored = false
        if let settingsBackup = payload.settings {
            let settings = try container.settingsRepository.loadSettings()
            settingsBackup.applyTo(settings)
            try container.settingsRepository.saveSettings(settings)
            settingsRestored = true
        }

        // Restore calibration profile
        var calibrationRestored = false
        if let calibBackup = payload.calibrationProfile {
            try container.calibrationRepository.deleteAll()
            let profile = calibBackup.toModel()
            try container.calibrationRepository.save(profile)
            calibrationRestored = true
        }

        logger.info("Backup imported: \(payload.sessions.count) sessions, \(payload.attempts.count) attempts, \(payload.masteryScores.count) mastery scores")

        return BackupImportResult(
            sessionsRestored: payload.sessions.count,
            attemptsRestored: payload.attempts.count,
            masteryScoresRestored: payload.masteryScores.count,
            settingsRestored: settingsRestored,
            calibrationRestored: calibrationRestored
        )
    }
}

// MARK: - BackupError

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "This backup was created with a newer version (v\(version)) and cannot be restored."
        }
    }
}
