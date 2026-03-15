// TestDataSeeder.swift
// FretShed — App Layer
//
// Seeds realistic test data for UI testing (heatmap, journey, adaptive).
// 30 sessions over 21 days showing upward accuracy trend with sawtoothing.
// Mastery ~75%, heatmap shows all 4 tiers. 5 sessions per focus mode.
// Tagged with a sentinel calibrationProfileID for easy removal.
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
    static let sessionCount = 30

    static var isSeeded: Bool {
        UserDefaults.standard.bool(forKey: isSeededKey)
    }

    // MARK: - Session Blueprint

    private struct SessionBlueprint {
        let focusMode: FocusMode
        let gameMode: GameMode
        let daysAgo: Int
        let hourOffset: Double
        let targetAccuracy: Double   // 0–1
        let targetResponseMs: Int    // average response time
        let attemptCount: Int
        let sessionTimeLimitSeconds: Int
    }

    // MARK: - Seed

    static func seed(container: AppContainer) {
        let fretboardMap = container.fretboardMap
        let context = container.modelContainer.mainContext
        var rng = SeededRNG(seed: 42)

        // Build cell map
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

            // Filter cells by focus mode
            let candidates: [(string: Int, fret: Int, note: MusicalNote)]
            let targetStrings: [Int]
            let targetNotes: [MusicalNote]

            switch bp.focusMode {
            case .singleString:
                // Alternate between strings 5, 6, 4 across sessions
                let stringChoices = [5, 6, 4]
                let pick = stringChoices[bp.daysAgo % stringChoices.count]
                targetStrings = [pick]; targetNotes = []
                candidates = allCells.filter { $0.string == pick }
            case .singleNote:
                let noteChoices: [MusicalNote] = [.a, .e, .c, .g, .d]
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
                candidates = allCells.filter { (3...7).contains($0.fret) }
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

                // Probability of correct: base accuracy modulated by cell difficulty
                let correctProb = bp.targetAccuracy * (1.0 - difficulty * 0.4)
                let roll = Double.random(in: 0...1, using: &rng)
                let wasCorrect = roll < correctProb
                if wasCorrect { correctCount += 1 }

                let playedNote: MusicalNote? = wasCorrect
                    ? cell.note
                    : cell.note.transposed(by: Int.random(in: 1...3, using: &rng))

                // Response time: base ± 30% jitter
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

                // Accumulate mastery
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

        // Force some cells into proficient tier (green): ≥75% score, <15 attempts.
        // These are naturals on strings 5–6 at mid-frets — "known but not drilled."
        // 8 correct / 8 total → Bayesian (10/11) = 0.909, well above 0.75 threshold.
        let proficientCells: [(MusicalNote, Int)] = [
            (.c, 5),   // C on A string, fret 3
            (.g, 6),   // G on low E string, fret 3
            (.a, 6),   // A on low E string, fret 5
            (.d, 5),   // D on A string, fret 5
            (.b, 5),   // B on A string, fret 2
            (.f, 6),   // F on low E string, fret 1
        ]
        for (note, string) in proficientCells {
            let key = "\(note.rawValue)-\(string)"
            masteryMap[key] = (total: 8, correct: 8, lastDate: now.addingTimeInterval(-3600))
        }

        // Build mastery scores
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
            let totalAttempts = blueprints.reduce(0) { $0 + $1.attemptCount }
            logger.info("Test data seeded: \(blueprints.count) sessions, \(totalAttempts) attempts")
        } catch {
            logger.error("Failed to seed: \(error)")
        }
    }

    // MARK: - Blueprint Factory

    /// 30 sessions: 5 per focus mode, spread over 21 days.
    /// Accuracy trends upward ~48% → ~86% with sawtoothing.
    /// Response times trend downward ~4000ms → ~1700ms.
    private static func makeBlueprints() -> [SessionBlueprint] {
        // Focus modes cycled in this order
        let modes: [FocusMode] = [
            .fullFretboard, .singleString, .singleNote,
            .fretboardPosition, .naturalNotes, .sharpsAndFlats
        ]
        let gameModes: [GameMode] = [.untimed, .timed, .streak]

        // Per-session targets: (accuracy, responseMs, attemptCount)
        // Sawtoothing pattern: each "wave" peaks higher than the last
        let targets: [(acc: Double, ms: Int, count: Int)] = [
            // Week 1 (days 21–16): beginner phase
            (0.45, 4200, 10), (0.50, 4000, 10), (0.48, 3900, 12),
            (0.55, 3700, 12), (0.52, 3800, 10), (0.58, 3500, 12),
            // Week 2 (days 15–10): building confidence
            (0.55, 3400, 12), (0.62, 3200, 14), (0.58, 3300, 12),
            (0.65, 3000, 14), (0.62, 3100, 14), (0.68, 2900, 14),
            // Week 3a (days 9–5): hitting stride
            (0.65, 2800, 14), (0.72, 2500, 15), (0.68, 2600, 14),
            (0.75, 2400, 15), (0.72, 2500, 15), (0.78, 2200, 16),
            // Week 3b (days 4–0): recent strong sessions
            (0.75, 2300, 15), (0.80, 2000, 16), (0.76, 2100, 15),
            (0.82, 1900, 16), (0.78, 2000, 16), (0.85, 1800, 18),
            // Recent sessions (days 3–0): peak performance
            (0.80, 1900, 16), (0.86, 1700, 18), (0.82, 1800, 16),
            (0.88, 1600, 18), (0.84, 1700, 18), (0.86, 1700, 18)
        ]

        // Day offsets from today (21 → 0, spread across 21 days)
        let daySchedule = [
            21, 20, 19, 18, 17, 16,   // 6 sessions in first 6 days
            15, 14, 13, 12, 11, 10,   // daily
            9, 8, 7, 6, 5, 4,        // daily
            3, 3, 2, 2, 1, 1,        // doubling up in recent days
            0, 0, 0, 0, 0, 0         // today's sessions (for demo)
        ]

        // Hour offsets within each day (morning/evening variety)
        let hourOffsets: [Double] = [
            7*3600, 19*3600, 8*3600, 20*3600, 9*3600, 18*3600,
            7.5*3600, 20*3600, 8*3600, 19.5*3600, 9*3600, 18.5*3600,
            8*3600, 19*3600, 7*3600, 20*3600, 9.5*3600, 18*3600,
            8*3600, 19*3600, 7.5*3600, 20.5*3600, 9*3600, 18*3600,
            8*3600, 10*3600, 12*3600, 14*3600, 16*3600, 18*3600
        ]

        var blueprints: [SessionBlueprint] = []
        for i in 0..<30 {
            let focusMode = modes[i % modes.count]
            let gameMode = gameModes[i % gameModes.count]
            let t = targets[i]
            let timeLimit = (gameMode == .timed) ? [60, 90, 120][i % 3] : 0

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

    /// Returns 0.0 (easy) to 1.0 (hard) for a fretboard cell.
    /// Tuned so the heatmap shows all 4 mastery tiers with naturals on
    /// strings 5–6 split between mastered (gold) and proficient (green).
    private static func cellDifficulty(note: MusicalNote, string: Int, fret: Int) -> Double {
        var d = 0.0

        // Accidentals are harder
        if !note.isNatural { d += 0.30 }

        // Higher frets are harder
        d += Double(fret) * 0.025

        // Upper strings slightly harder for beginners
        if string <= 2 { d += 0.10 }

        // Open strings are easier
        if fret == 0 { d -= 0.15 }

        // Common landmark notes are easier (5th and 7th fret)
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
