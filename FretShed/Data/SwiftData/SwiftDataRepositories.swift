// SwiftDataRepositories.swift
// FretShed — Data Layer

import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "Repositories")

// MARK: - SwiftDataAttemptRepository

public final class SwiftDataAttemptRepository: AttemptRepository {

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func save(_ attempt: Attempt) throws {
        context.insert(attempt)
        try context.save()
    }

    public func attempts(forSession sessionID: UUID) throws -> [Attempt] {
        let id = sessionID
        let descriptor = FetchDescriptor<Attempt>(
            predicate: #Predicate { $0.sessionID == id },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try context.fetch(descriptor)
    }

    public func attempts(forNote note: MusicalNote, limit: Int?) throws -> [Attempt] {
        let raw = note.rawValue
        var descriptor = FetchDescriptor<Attempt>(
            predicate: #Predicate { $0.targetNoteRaw == raw },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    public func attempts(forNote note: MusicalNote, string: Int, limit: Int) throws -> [Attempt] {
        let raw = note.rawValue
        let stringNum = string
        var descriptor = FetchDescriptor<Attempt>(
            predicate: #Predicate { $0.targetNoteRaw == raw && $0.targetString == stringNum },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    public func allAttempts() throws -> [Attempt] {
        let descriptor = FetchDescriptor<Attempt>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try context.fetch(descriptor)
    }

    public func deleteAttempts(forSession sessionID: UUID) throws {
        let id = sessionID
        let descriptor = FetchDescriptor<Attempt>(
            predicate: #Predicate { $0.sessionID == id }
        )
        let toDelete = try context.fetch(descriptor)
        for attempt in toDelete { context.delete(attempt) }
        try context.save()
    }

    public func deleteAll() throws {
        try context.delete(model: Attempt.self)
        try context.save()
    }
}

// MARK: - SwiftDataSessionRepository

public final class SwiftDataSessionRepository: SessionRepository {

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func save(_ session: Session) throws {
        context.insert(session)
        try context.save()
    }

    public func activeSession() throws -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    public func allSessions() throws -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isCompleted },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    public func recentSessions(limit: Int) throws -> [Session] {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.isCompleted },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    public func complete(_ session: Session) throws {
        session.isCompleted = true
        session.isPaused = false
        session.endTime = Date()
        // Always save unconditionally. The hasChanges guard was removed because
        // SwiftData's auto-save can clear the dirty flag between the property
        // mutations above and this explicit save call, silently skipping the write.
        try context.save()
    }

    public func delete(_ session: Session) throws {
        context.delete(session)
        try context.save()
    }

    public func deleteAll() throws {
        try context.delete(model: Session.self)
        try context.save()
    }
}

// MARK: - SwiftDataMasteryRepository

public final class SwiftDataMasteryRepository: MasteryRepository {

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func score(forNote note: MusicalNote, string: Int) throws -> MasteryScore {
        let raw = note.rawValue
        let stringNum = string
        let descriptor = FetchDescriptor<MasteryScore>(
            predicate: #Predicate { $0.noteRaw == raw && $0.stringNumber == stringNum }
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let newScore = MasteryScore(note: note, stringNumber: string)
        context.insert(newScore)
        try context.save()
        return newScore
    }

    public func allScores() throws -> [MasteryScore] {
        let descriptor = FetchDescriptor<MasteryScore>(
            sortBy: [SortDescriptor(\.noteRaw), SortDescriptor(\.stringNumber)]
        )
        return try context.fetch(descriptor)
    }

    public func save(_ score: MasteryScore) throws {
        context.insert(score)
        if context.hasChanges { try context.save() }
    }

    public func rebuild(from attempts: [Attempt]) throws {
        // Wipe existing scores.
        try context.delete(model: MasteryScore.self)

        // Accumulate counts per (noteRaw, stringNumber) from the attempt list.
        struct Key: Hashable { let noteRaw: Int; let stringNumber: Int }
        var totals:   [Key: Int] = [:]
        var corrects: [Key: Int] = [:]
        let bestStreaks: [Key: Int] = [:]

        for attempt in attempts {
            let key = Key(noteRaw: attempt.targetNoteRaw, stringNumber: attempt.targetString)
            totals[key, default: 0]   += 1
            if attempt.wasCorrect { corrects[key, default: 0] += 1 }
        }

        // Insert rebuilt MasteryScore records.
        for (key, total) in totals {
            guard let note = MusicalNote(rawValue: key.noteRaw) else { continue }
            let newScore = MasteryScore(note: note, stringNumber: key.stringNumber)
            newScore.totalAttempts   = total
            newScore.correctAttempts = corrects[key, default: 0]
            newScore.bestStreakCount = bestStreaks[key, default: 0]
            newScore.lastAttemptDate = attempts
                .filter { $0.targetNoteRaw == key.noteRaw && $0.targetString == key.stringNumber }
                .map(\.timestamp)
                .max()
            context.insert(newScore)
        }

        try context.save()
    }

    public func deleteAll() throws {
        try context.delete(model: MasteryScore.self)
        try context.save()
    }
}

// MARK: - SwiftDataCalibrationRepository

public final class SwiftDataCalibrationRepository: CalibrationProfileRepository {

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func save(_ profile: AudioCalibrationProfile) throws {
        context.insert(profile)
        try context.save()
    }

    public func activeProfile() throws -> AudioCalibrationProfile? {
        var descriptor = FetchDescriptor<AudioCalibrationProfile>(
            sortBy: [SortDescriptor(\.calibrationDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func deleteAll() throws {
        try context.delete(model: AudioCalibrationProfile.self)
        try context.save()
    }
}

// MARK: - SwiftDataSettingsRepository

public final class SwiftDataSettingsRepository: SettingsRepository {

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func loadSettings() throws -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        let existing = try context.fetch(descriptor)
        if let settings = existing.first {
            return settings
        }
        let defaults = UserSettings()
        context.insert(defaults)
        try context.save()
        logger.info("Created default UserSettings")
        return defaults
    }

    public func saveSettings(_ settings: UserSettings) throws {
        // Always save unconditionally. The hasChanges guard was previously used here,
        // but it could silently skip saves when SwiftData's auto-save cleared the flag
        // before our explicit save was called.
        try context.save()
        logger.debug("Saved UserSettings")
    }
}
