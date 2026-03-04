// TestDataSeeder.swift
// FretShed — App Layer
//
// Seeds a small amount of test data for UI testing (heatmap, journey, adaptive).
// Minimal approach: ~50 objects inserted synchronously via mainContext.
// Tagged with a sentinel calibrationProfileID for easy removal.
//
// ⚠️ DELETE THIS FILE BEFORE TESTFLIGHT BETA (Task 5.16).

import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "TestDataSeeder")

@MainActor
enum TestDataSeeder {

    static let sentinelProfileID = UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000000")!
    static let isSeededKey = "testDataSeeded"

    static var isSeeded: Bool {
        UserDefaults.standard.bool(forKey: isSeededKey)
    }

    // MARK: - Seed

    static func seed(container: AppContainer) {
        let fretboardMap = container.fretboardMap
        let context = container.modelContainer.mainContext

        var allCells: [(string: Int, fret: Int, note: MusicalNote)] = []
        for string in 1...6 {
            for fret in 0...12 {
                if let note = fretboardMap.note(string: string, fret: fret) {
                    allCells.append((string, fret, note))
                }
            }
        }

        // 6 sessions (one per focus mode), 5 attempts each ≈ 51 total objects
        let focusModes: [FocusMode] = [
            .fullFretboard, .singleString, .singleNote,
            .naturalNotes, .sharpsAndFlats, .fretboardPosition
        ]
        let gameModes: [GameMode] = [.untimed, .timed, .streak]
        let calendar = Calendar.current
        let now = Date()
        var masteryMap: [String: (total: Int, correct: Int, lastDate: Date)] = [:]

        for (i, focusMode) in focusModes.enumerated() {
            let gameMode = gameModes[i % gameModes.count]
            let daysAgo = 12 - (i * 2)
            let startTime = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
                .addingTimeInterval(Double.random(in: 3600...36000))

            let candidates: [(string: Int, fret: Int, note: MusicalNote)]
            let targetStrings: [Int]
            let targetNotes: [MusicalNote]

            switch focusMode {
            case .singleString:
                targetStrings = [5]; targetNotes = []
                candidates = allCells.filter { $0.string == 5 }
            case .singleNote:
                targetStrings = []; targetNotes = [.a]
                candidates = allCells.filter { $0.note == .a }
            case .naturalNotes:
                targetStrings = []; targetNotes = []
                candidates = allCells.filter { $0.note.isNatural }
            case .sharpsAndFlats:
                targetStrings = []; targetNotes = []
                candidates = allCells.filter { !$0.note.isNatural }
            case .fretboardPosition:
                targetStrings = []; targetNotes = []
                candidates = allCells.filter { (3...7).contains($0.fret) }
            default:
                targetStrings = []; targetNotes = []
                candidates = allCells
            }

            guard !candidates.isEmpty else { continue }

            let sessionID = UUID()
            let shuffled = candidates.shuffled()
            let questionCount = 5
            var correctCount = 0

            for qi in 0..<questionCount {
                let cell = shuffled[qi % shuffled.count]
                let wasCorrect = Double.random(in: 0...1) < 0.65
                if wasCorrect { correctCount += 1 }

                let playedNote: MusicalNote? = wasCorrect
                    ? cell.note
                    : cell.note.transposed(by: Int.random(in: 1...3))
                let attemptTime = startTime.addingTimeInterval(Double(qi) * 5)

                let attempt = Attempt(
                    targetNote: cell.note,
                    targetString: cell.string,
                    targetFret: cell.fret,
                    playedNote: playedNote,
                    playedString: wasCorrect ? cell.string : nil,
                    responseTimeMs: Int.random(in: 1500...4000),
                    wasCorrect: wasCorrect,
                    sessionID: sessionID,
                    gameMode: gameMode,
                    acceptedAnyString: false
                )
                attempt.timestamp = attemptTime
                context.insert(attempt)

                let key = "\(cell.note.rawValue)-\(cell.string)"
                var e = masteryMap[key] ?? (0, 0, attemptTime)
                e.total += 1
                if wasCorrect { e.correct += 1 }
                if attemptTime > e.lastDate { e.lastDate = attemptTime }
                masteryMap[key] = e
            }

            let session = Session(
                id: sessionID,
                startTime: startTime,
                focusMode: focusMode,
                gameMode: gameMode,
                fretRangeStart: 0,
                fretRangeEnd: 12,
                targetNotes: targetNotes,
                targetStrings: targetStrings,
                isAdaptive: true
            )
            session.calibrationProfileID = sentinelProfileID
            session.endTime = startTime.addingTimeInterval(Double(questionCount) * 5)
            session.attemptCount = questionCount
            session.correctCount = correctCount
            session.isCompleted = true
            session.overallMasteryAtEnd = Double(correctCount) / Double(questionCount)
            context.insert(session)
        }

        for (key, value) in masteryMap {
            let parts = key.split(separator: "-")
            guard let noteRaw = Int(parts[0]),
                  let note = MusicalNote(rawValue: noteRaw),
                  let stringNum = Int(parts[1]) else { continue }
            let score = MasteryScore(note: note, stringNumber: stringNum)
            score.totalAttempts = value.total
            score.correctAttempts = value.correct
            score.lastAttemptDate = value.lastDate
            context.insert(score)
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: isSeededKey)
            logger.info("Test data seeded: 6 sessions, 30 attempts")
        } catch {
            logger.error("Failed to seed: \(error)")
        }
    }

    // MARK: - Remove

    static func remove(container: AppContainer) {
        let context = container.modelContainer.mainContext

        do {
            let allSessions = try context.fetch(FetchDescriptor<Session>())
            for session in allSessions where session.calibrationProfileID == sentinelProfileID {
                let sessionID = session.id
                let descriptor = FetchDescriptor<Attempt>(
                    predicate: #Predicate { $0.sessionID == sessionID }
                )
                for attempt in try context.fetch(descriptor) {
                    context.delete(attempt)
                }
                context.delete(session)
            }

            for score in try context.fetch(FetchDescriptor<MasteryScore>()) {
                context.delete(score)
            }

            let remaining = try context.fetch(FetchDescriptor<Attempt>())
            var counts: [String: (total: Int, correct: Int, lastDate: Date)] = [:]
            for a in remaining {
                let key = "\(a.targetNoteRaw)-\(a.targetString)"
                var e = counts[key] ?? (0, 0, a.timestamp)
                e.total += 1
                if a.wasCorrect { e.correct += 1 }
                if a.timestamp > e.lastDate { e.lastDate = a.timestamp }
                counts[key] = e
            }
            for (key, c) in counts {
                let parts = key.split(separator: "-")
                guard let noteRaw = Int(parts[0]), let stringNum = Int(parts[1]),
                      let note = MusicalNote(rawValue: noteRaw) else { continue }
                let score = MasteryScore(note: note, stringNumber: stringNum)
                score.totalAttempts = c.total
                score.correctAttempts = c.correct
                score.lastAttemptDate = c.lastDate
                context.insert(score)
            }

            try context.save()
            UserDefaults.standard.set(false, forKey: isSeededKey)
            logger.info("Test data removed, mastery rebuilt")
        } catch {
            logger.error("Failed to remove: \(error)")
        }
    }
}
