// TestDataSeeder.swift
// FretShed — App Layer
//
// Seeds realistic test data for App Store screenshots.
// Simulates a Phase 3 user with ~35 sessions over 28 days.
// Heatmap shows all 5 tiers. Accuracy trending up, response time down.
//
// ⚠️ DELETE THIS FILE BEFORE TESTFLIGHT BETA (Task 5.16).

import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "TestDataSeeder")

// MARK: - Deterministic PRNG

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@MainActor
enum TestDataSeeder {

    static let sentinelProfileID = UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000000")!
    static let isSeededKey = "testDataSeeded"
    static let sessionCount = 35

    static var isSeeded: Bool {
        UserDefaults.standard.bool(forKey: isSeededKey)
    }

    // MARK: - Session Blueprint

    private struct SessionBlueprint {
        let focusMode: FocusMode
        let gameMode: GameMode
        let daysAgo: Int
        let hourOffset: Double
        let targetAccuracy: Double
        let targetResponseMs: Int
        let attemptCount: Int
        let sessionTimeLimitSeconds: Int
    }

    // MARK: - Seed

    static func seed(container: AppContainer) {
        let fretboardMap = container.fretboardMap
        let context = container.modelContainer.mainContext
        var rng = SeededRNG(seed: 42)

        // Build cell map (all 6 strings for premium screenshots)
        var allCells: [(string: Int, fret: Int, note: MusicalNote)] = []
        for string in 1...6 {
            for fret in 0...12 {
                if let note = fretboardMap.note(string: string, fret: fret) {
                    allCells.append((string, fret, note))
                }
            }
        }

        let blueprints = makeBlueprints()
        let now = Date()
        let calendar = Calendar.current
        var masteryMap: [String: (total: Int, correct: Int, lastDate: Date)] = [:]

        for bp in blueprints {
            let startTime = calendar.date(byAdding: .day, value: -bp.daysAgo, to: now)!
                .addingTimeInterval(bp.hourOffset)

            let candidates: [(string: Int, fret: Int, note: MusicalNote)]
            let targetStrings: [Int]
            let targetNotes: [MusicalNote]

            switch bp.focusMode {
            case .singleString:
                let stringChoices = [6, 5, 4, 3, 2, 1]
                let pick = stringChoices[bp.daysAgo % stringChoices.count]
                targetStrings = [pick]; targetNotes = []
                candidates = allCells.filter { $0.string == pick }
            case .singleNote:
                let noteChoices: [MusicalNote] = [.a, .e, .c, .g, .d, .b]
                let pick = noteChoices[bp.daysAgo % noteChoices.count]
                targetStrings = []; targetNotes = [pick]
                candidates = allCells.filter { $0.note == pick }
            case .naturalNotes:
                targetStrings = []; targetNotes = []
                candidates = allCells.filter { $0.note.isNatural }
            case .sharpsAndFlats:
                targetStrings = []; targetNotes = []
                candidates = allCells.filter { !$0.note.isNatural }
            case .fretboardPosition:
                targetStrings = []; targetNotes = []
                candidates = allCells.filter { (3...8).contains($0.fret) }
            default:
                targetStrings = []; targetNotes = []
                candidates = allCells
            }

            guard !candidates.isEmpty else { continue }

            let sessionID = UUID()
            var correctCount = 0
            let shuffled = candidates.shuffled(using: &rng)

            for qi in 0..<bp.attemptCount {
                let cell = shuffled[qi % shuffled.count]
                let difficulty = cellDifficulty(note: cell.note, string: cell.string, fret: cell.fret)

                let correctProb = bp.targetAccuracy * (1.0 - difficulty * 0.4)
                let roll = Double.random(in: 0...1, using: &rng)
                let wasCorrect = roll < correctProb
                if wasCorrect { correctCount += 1 }

                let playedNote: MusicalNote? = wasCorrect
                    ? cell.note
                    : cell.note.transposed(by: Int.random(in: 1...3, using: &rng))

                let jitter = Double.random(in: 0.7...1.3, using: &rng)
                let responseMs = Int(Double(bp.targetResponseMs) * jitter)

                let attemptTime = startTime.addingTimeInterval(Double(qi) * 6)
                let attempt = Attempt(
                    targetNote: cell.note,
                    targetString: cell.string,
                    targetFret: cell.fret,
                    playedNote: playedNote,
                    playedString: wasCorrect ? cell.string : nil,
                    responseTimeMs: max(800, min(6000, responseMs)),
                    wasCorrect: wasCorrect,
                    sessionID: sessionID,
                    gameMode: bp.gameMode,
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
                focusMode: bp.focusMode,
                gameMode: bp.gameMode,
                fretRangeStart: 0,
                fretRangeEnd: 12,
                targetNotes: targetNotes,
                targetStrings: targetStrings,
                isAdaptive: true,
                sessionTimeLimitSeconds: bp.sessionTimeLimitSeconds
            )
            session.calibrationProfileID = sentinelProfileID
            session.endTime = startTime.addingTimeInterval(Double(bp.attemptCount) * 6)
            session.attemptCount = bp.attemptCount
            session.correctCount = correctCount
            session.isCompleted = true
            session.overallMasteryAtEnd = Double(correctCount) / Double(max(1, bp.attemptCount))
            context.insert(session)
        }

        // --- Force specific heatmap tiers ---

        // MASTERED (green): strings 4-6 naturals with spacing gate complete
        // These are notes the user has "proven" across multiple days
        let masteredCells: [(MusicalNote, Int)] = [
            (.d, 4), (.e, 4), (.f, 4), (.g, 4),           // D string naturals
            (.a, 5), (.b, 5), (.c, 5), (.d, 5), (.e, 5),  // A string naturals
            (.e, 6), (.f, 6), (.g, 6), (.a, 6), (.b, 6),  // low E string naturals
        ]
        for (note, string) in masteredCells {
            let key = "\(note.rawValue)-\(string)"
            masteryMap[key] = (total: 18, correct: 17, lastDate: now.addingTimeInterval(-3600))
        }

        // PROFICIENT (gold): some cells at 75%+ with 3+ attempts but no spacing gate
        let proficientCells: [(MusicalNote, Int)] = [
            (.a, 4), (.b, 4), (.c, 4),                    // D string remaining naturals
            (.f, 5), (.g, 5),                              // A string remaining naturals
            (.c, 6), (.d, 6),                              // low E remaining naturals
            (.e, 3), (.a, 3), (.b, 3),                     // G string
            (.e, 2), (.c, 2),                              // B string
            (.e, 1), (.b, 1),                              // high E string
        ]
        for (note, string) in proficientCells {
            let key = "\(note.rawValue)-\(string)"
            masteryMap[key] = (total: 8, correct: 7, lastDate: now.addingTimeInterval(-7200))
        }

        // STRUGGLING (red): some cells with low accuracy
        let strugglingCells: [(MusicalNote, Int)] = [
            (.gSharp, 3), (.dSharp, 2), (.fSharp, 1),
            (.aSharp, 6), (.cSharp, 4),
        ]
        for (note, string) in strugglingCells {
            let key = "\(note.rawValue)-\(string)"
            masteryMap[key] = (total: 8, correct: 2, lastDate: now.addingTimeInterval(-86400))
        }

        // Build mastery scores with spacing gate checkpoints
        for (key, value) in masteryMap {
            let parts = key.split(separator: "-")
            guard let noteRaw = Int(parts[0]),
                  let note = MusicalNote(rawValue: noteRaw),
                  let stringNum = Int(parts[1]) else { continue }
            let score = MasteryScore(note: note, stringNumber: stringNum)
            score.totalAttempts = value.total
            score.correctAttempts = value.correct
            score.lastAttemptDate = value.lastDate

            // Set spacing gate checkpoints for mastered cells
            if masteredCells.contains(where: { $0.0 == note && $0.1 == stringNum }) {
                score.spacingCheckpoint1Date = now.addingTimeInterval(-14 * 86400)
                score.spacingCheckpoint2Date = now.addingTimeInterval(-10 * 86400)
                score.spacingCheckpoint3Date = now.addingTimeInterval(-5 * 86400)
            }

            context.insert(score)
        }

        // --- Set LearningPhaseManager to Phase 3 (Connection) ---
        setPhaseState()

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: isSeededKey)
            let totalAttempts = blueprints.reduce(0) { $0 + $1.attemptCount }
            logger.info("Test data seeded: \(blueprints.count) sessions, \(totalAttempts) attempts, Phase 3 state set")
        } catch {
            logger.error("Failed to seed: \(error)")
        }
    }

    // MARK: - Phase State

    /// Sets LearningPhaseManager to Phase 3 (Connection) with all Phase 1+2 strings completed.
    private static func setPhaseState() {
        let ud = UserDefaults.standard
        // Phase 3 = Connection (rawValue 3)
        ud.set(3, forKey: "learningPhase_current")
        // All 6 Phase 1 strings completed
        if let data = try? JSONEncoder().encode(Set(1...6)) {
            ud.set(data, forKey: "learningPhase_completedStrings")
        }
        // All 6 Phase 2 strings completed
        if let data = try? JSONEncoder().encode(Set(1...6)) {
            ud.set(data, forKey: "learningPhase_phaseTwoCompletedStrings")
        }
        // No current target string (Connection is cross-string)
        ud.set(0, forKey: "learningPhase_targetString")
        ud.set(0, forKey: "learningPhase_phaseTwoTargetString")
        // Sessions in current phase
        ud.set(5, forKey: "learningPhase_sessionsInPhase")
        // v2 migration done
        ud.set(true, forKey: "learningPhase_v2Migrated")
    }

    // MARK: - Blueprint Factory

    /// 35 sessions over 28 days. Mix of modes, accuracy trending up, response time trending down.
    private static func makeBlueprints() -> [SessionBlueprint] {
        let modes: [FocusMode] = [
            .fullFretboard, .singleString, .singleNote,
            .fretboardPosition, .naturalNotes, .sharpsAndFlats, .fullFretboard
        ]
        let gameModes: [GameMode] = [.untimed, .untimed, .timed, .untimed, .streak]

        let targets: [(acc: Double, ms: Int, count: Int)] = [
            // Week 1 (days 28–22): early phase, finding footing
            (0.42, 4500, 15), (0.48, 4200, 15), (0.45, 4300, 18),
            (0.52, 4000, 18), (0.50, 4100, 15), (0.55, 3800, 18),
            (0.53, 3900, 18),
            // Week 2 (days 21–15): building confidence
            (0.55, 3600, 18), (0.60, 3400, 20), (0.57, 3500, 18),
            (0.63, 3200, 20), (0.60, 3300, 20), (0.66, 3000, 20),
            (0.64, 3100, 20),
            // Week 3 (days 14–8): hitting stride
            (0.65, 2900, 20), (0.70, 2700, 20), (0.67, 2800, 20),
            (0.73, 2500, 20), (0.70, 2600, 20), (0.76, 2300, 20),
            (0.74, 2400, 20),
            // Week 4 (days 7–0): strong recent performance
            (0.75, 2200, 20), (0.80, 2000, 20), (0.77, 2100, 20),
            (0.82, 1900, 20), (0.79, 2000, 20), (0.84, 1800, 20),
            (0.81, 1900, 20), (0.86, 1700, 20), (0.83, 1800, 20),
            (0.88, 1600, 20), (0.85, 1700, 20), (0.90, 1500, 20),
            (0.87, 1600, 20), (0.88, 1550, 20),
        ]

        let daySchedule = [
            28, 27, 26, 25, 24, 23, 22,
            21, 20, 19, 18, 17, 16, 15,
            14, 13, 12, 11, 10, 9, 8,
            7, 6, 5, 4, 3, 2, 2,
            1, 1, 1, 0, 0, 0, 0,
        ]

        let hourOffsets: [Double] = [
            7*3600, 19*3600, 8*3600, 20*3600, 9*3600, 18*3600, 7.5*3600,
            8*3600, 19*3600, 7*3600, 20*3600, 9*3600, 18.5*3600, 8*3600,
            19*3600, 7*3600, 20*3600, 9.5*3600, 18*3600, 8*3600, 19*3600,
            7.5*3600, 20*3600, 9*3600, 18*3600, 8*3600, 10*3600, 14*3600,
            8*3600, 12*3600, 16*3600, 8*3600, 10*3600, 14*3600, 18*3600,
        ]

        var blueprints: [SessionBlueprint] = []
        for i in 0..<35 {
            let focusMode = modes[i % modes.count]
            let gameMode = gameModes[i % gameModes.count]
            let t = targets[i]
            let timeLimit = (gameMode == .timed) ? [120, 180, 300][i % 3] : 0

            blueprints.append(SessionBlueprint(
                focusMode: focusMode,
                gameMode: gameMode,
                daysAgo: daySchedule[i],
                hourOffset: hourOffsets[i],
                targetAccuracy: t.acc,
                targetResponseMs: t.ms,
                attemptCount: t.count,
                sessionTimeLimitSeconds: timeLimit
            ))
        }
        return blueprints
    }

    // MARK: - Cell Difficulty

    private static func cellDifficulty(note: MusicalNote, string: Int, fret: Int) -> Double {
        var d = 0.0
        if !note.isNatural { d += 0.30 }
        d += Double(fret) * 0.025
        if string <= 2 { d += 0.15 }
        if string == 3 { d += 0.08 }
        if fret == 0 { d -= 0.15 }
        if fret == 5 || fret == 7 { d -= 0.05 }
        return max(0, min(1, d))
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
