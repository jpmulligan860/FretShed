// Repositories.swift
// FretShed — Data Layer

import Foundation

// MARK: - AttemptRepository

public protocol AttemptRepository: AnyObject {
    func save(_ attempt: Attempt) throws
    func attempts(forSession sessionID: UUID) throws -> [Attempt]
    func attempts(forNote note: MusicalNote, limit: Int?) throws -> [Attempt]
    func attempts(forNote note: MusicalNote, string: Int, limit: Int) throws -> [Attempt]
    func deleteAttempts(forSession sessionID: UUID) throws
    func deleteAll() throws
}

// MARK: - SessionRepository

public protocol SessionRepository: AnyObject {
    func save(_ session: Session) throws
    func activeSession() throws -> Session?
    func allSessions() throws -> [Session]
    func recentSessions(limit: Int) throws -> [Session]
    func complete(_ session: Session) throws
    func delete(_ session: Session) throws
    func deleteAll() throws
}

// MARK: - MasteryRepository

public protocol MasteryRepository: AnyObject {
    func score(forNote note: MusicalNote, string: Int) throws -> MasteryScore
    func allScores() throws -> [MasteryScore]
    func save(_ score: MasteryScore) throws
    func rebuild(from attempts: [Attempt]) throws
    func deleteAll() throws
}

// MARK: - SettingsRepository

public protocol SettingsRepository: AnyObject {
    func loadSettings() throws -> UserSettings
    func saveSettings(_ settings: UserSettings) throws
}
