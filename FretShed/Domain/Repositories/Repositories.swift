// Repositories.swift
// FretShed — Domain Layer

import Foundation

@MainActor
public protocol AttemptRepository {
    func save(_ attempt: Attempt) throws
    func attempts(forSession sessionID: UUID) throws -> [Attempt]
    func attempts(forNote note: MusicalNote, limit: Int?) throws -> [Attempt]
    func attempts(forNote note: MusicalNote, string: Int, limit: Int) throws -> [Attempt]
    func deleteAttempts(forSession sessionID: UUID) throws
    func deleteAll() throws
}

@MainActor
public protocol SessionRepository {
    func save(_ session: Session) throws
    func activeSession() throws -> Session?
    func allSessions() throws -> [Session]
    func recentSessions(limit: Int) throws -> [Session]
    func complete(_ session: Session) throws
    func delete(_ session: Session) throws
    func deleteAll() throws
}

@MainActor
public protocol MasteryRepository {
    func score(forNote note: MusicalNote, string: Int) throws -> MasteryScore
    func allScores() throws -> [MasteryScore]
    func save(_ score: MasteryScore) throws
    func rebuild(from attempts: [Attempt]) throws
    func deleteAll() throws
}

@MainActor
public protocol SettingsRepository {
    func loadSettings() throws -> UserSettings
    func saveSettings(_ settings: UserSettings) throws
}

@MainActor
public protocol CalibrationProfileRepository {
    func save(_ profile: AudioCalibrationProfile) throws
    func activeProfile() throws -> AudioCalibrationProfile?
    func deleteAll() throws
}
