// SmartPracticeEngine.swift
// FretShed — Quiz Layer
//
// Generates Smart Practice sessions that rotate focus modes across sessions
// and target the user's weakest areas. Used by the primary CTA on the Shed page.

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "SmartPracticeEngine")

// MARK: - SmartPracticeMode

/// The three focus mode categories that Smart Practice rotates through.
enum SmartPracticeMode: String, CaseIterable {
    case fullFretboard
    case singleString
    case sameNote
}

// MARK: - SmartPracticeEngine

@MainActor
final class SmartPracticeEngine {

    private let masteryRepository: any MasteryRepository
    private let sessionRepository: any SessionRepository
    private let fretboardMap: FretboardMap

    private static let lastModeKey = "lastSmartPracticeMode"

    // Free-tier constraints (hardcoded until Phase 4 EntitlementManager)
    private static let freeStrings: [Int] = [4, 5, 6]
    private static let freeFretStart = 0
    private static let freeFretEnd = 7

    init(
        masteryRepository: any MasteryRepository,
        sessionRepository: any SessionRepository,
        fretboardMap: FretboardMap
    ) {
        self.masteryRepository = masteryRepository
        self.sessionRepository = sessionRepository
        self.fretboardMap = fretboardMap
    }

    /// Returns the next Smart Practice session and a human-readable description of what it will do.
    func nextSession() throws -> (session: Session, description: String) {
        let lastMode = Self.loadLastMode()
        let nextMode = Self.rotateMode(from: lastMode)
        Self.saveLastMode(nextMode)

        let allScores = try masteryRepository.allScores()

        switch nextMode {
        case .fullFretboard:
            let session = Session(
                focusMode: .fullFretboard,
                gameMode: .untimed,
                fretRangeStart: Self.freeFretStart,
                fretRangeEnd: Self.freeFretEnd,
                isAdaptive: true
            )
            return (session, "Full Fretboard — adaptive")

        case .singleString:
            let weakestString = Self.weakestString(from: allScores, strings: Self.freeStrings)
            let stringName = Self.stringName(weakestString)
            let session = Session(
                focusMode: .singleString,
                gameMode: .untimed,
                fretRangeStart: Self.freeFretStart,
                fretRangeEnd: Self.freeFretEnd,
                targetStrings: [weakestString],
                isAdaptive: true
            )
            return (session, "Single String — \(stringName) string")

        case .sameNote:
            let weakestNote = Self.weakestNote(from: allScores, fretboardMap: fretboardMap, strings: Self.freeStrings, fretEnd: Self.freeFretEnd)
            let session = Session(
                focusMode: .singleNote,
                gameMode: .untimed,
                fretRangeStart: Self.freeFretStart,
                fretRangeEnd: Self.freeFretEnd,
                targetNotes: [weakestNote],
                isAdaptive: true
            )
            return (session, "Same Note — \(weakestNote.sharpName)")
        }
    }

    /// Returns the description of the next mode without creating a session.
    func nextModeDescription() -> String {
        let lastMode = Self.loadLastMode()
        let nextMode = Self.rotateMode(from: lastMode)
        switch nextMode {
        case .fullFretboard: return "Full Fretboard"
        case .singleString:  return "Single String"
        case .sameNote:      return "Same Note"
        }
    }

    /// Returns a detailed description of the next session without side effects (no mode rotation).
    func peekNextSessionDescription() throws -> String {
        let lastMode = Self.loadLastMode()
        let nextMode = Self.rotateMode(from: lastMode)
        let allScores = try masteryRepository.allScores()

        switch nextMode {
        case .fullFretboard:
            return "Full Fretboard — adaptive"
        case .singleString:
            let weakest = Self.weakestString(from: allScores, strings: Self.freeStrings)
            return "Single String — \(Self.stringName(weakest)) string"
        case .sameNote:
            let weakest = Self.weakestNote(from: allScores, fretboardMap: fretboardMap, strings: Self.freeStrings, fretEnd: Self.freeFretEnd)
            return "Same Note — \(weakest.sharpName)"
        }
    }

    /// Count of fretboard cells with mastery score below 0.50 (within free area).
    func weakSpotCount() throws -> Int {
        let allScores = try masteryRepository.allScores()
        var count = 0
        for string in Self.freeStrings {
            guard let fretMap = fretboardMap.map[string] else { continue }
            for fret in Self.freeFretStart...Self.freeFretEnd {
                guard let note = fretMap[fret] else { continue }
                if let score = allScores.first(where: {
                    $0.noteRaw == note.rawValue && $0.stringNumber == string
                }) {
                    if score.score < 0.50 { count += 1 }
                } else {
                    // No data = uncertain = count as weak
                    count += 1
                }
            }
        }
        return count
    }

    /// Returns two sessions that differ from whatever Smart Practice is currently recommending.
    /// Each entry includes a session, display title, subtitle, and SF Symbol icon name.
    func alternativeSessions() throws -> [(session: Session, title: String, subtitle: String, icon: String)] {
        let lastMode = Self.loadLastMode()
        let currentMode = Self.rotateMode(from: lastMode)
        let allScores = try masteryRepository.allScores()

        // Build the two modes that Smart Practice is NOT recommending
        let alternatives = SmartPracticeMode.allCases.filter { $0 != currentMode }
        return alternatives.map { mode in
            switch mode {
            case .fullFretboard:
                let session = Session(
                    focusMode: .fullFretboard,
                    gameMode: .untimed,
                    fretRangeStart: Self.freeFretStart,
                    fretRangeEnd: Self.freeFretEnd,
                    isAdaptive: true
                )
                return (session, "Full Fretboard", "Cover all positions", "rectangle.grid.3x2.fill")

            case .singleString:
                let weakest = Self.weakestString(from: allScores, strings: Self.freeStrings)
                let name = Self.stringName(weakest)
                let session = Session(
                    focusMode: .singleString,
                    gameMode: .untimed,
                    fretRangeStart: Self.freeFretStart,
                    fretRangeEnd: Self.freeFretEnd,
                    targetStrings: [weakest],
                    isAdaptive: true
                )
                return (session, "Single String", "Weakest: \(Self.stringOrdinal(weakest)) — \(name)", "custom.singleString.\(weakest)")

            case .sameNote:
                let weakest = Self.weakestNote(from: allScores, fretboardMap: fretboardMap, strings: Self.freeStrings, fretEnd: Self.freeFretEnd)
                let session = Session(
                    focusMode: .singleNote,
                    gameMode: .untimed,
                    fretRangeStart: Self.freeFretStart,
                    fretRangeEnd: Self.freeFretEnd,
                    targetNotes: [weakest],
                    isAdaptive: true
                )
                return (session, "Same Note", "Weakest: \(weakest.sharpName)", "music.note")
            }
        }
    }

    // MARK: - Private Helpers

    private static func rotateMode(from last: SmartPracticeMode?) -> SmartPracticeMode {
        guard let last else { return .fullFretboard }
        switch last {
        case .fullFretboard: return .singleString
        case .singleString:  return .sameNote
        case .sameNote:      return .fullFretboard
        }
    }

    private static func loadLastMode() -> SmartPracticeMode? {
        guard let raw = UserDefaults.standard.string(forKey: lastModeKey) else { return nil }
        return SmartPracticeMode(rawValue: raw)
    }

    private static func saveLastMode(_ mode: SmartPracticeMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: lastModeKey)
    }

    private static func weakestString(from scores: [MasteryScore], strings: [Int]) -> Int {
        var stringAvgs: [(string: Int, avg: Double)] = []
        for s in strings {
            let relevant = scores.filter { $0.stringNumber == s }
            if relevant.isEmpty {
                stringAvgs.append((s, 0.50))
            } else {
                let avg = relevant.map(\.score).reduce(0, +) / Double(relevant.count)
                stringAvgs.append((s, avg))
            }
        }
        return stringAvgs.min(by: { $0.avg < $1.avg })?.string ?? strings.first ?? 6
    }

    private static func weakestNote(
        from scores: [MasteryScore],
        fretboardMap: FretboardMap,
        strings: [Int],
        fretEnd: Int
    ) -> MusicalNote {
        var noteScores: [MusicalNote: [Double]] = [:]
        for string in strings {
            guard let fretMap = fretboardMap.map[string] else { continue }
            for fret in 0...fretEnd {
                guard let note = fretMap[fret] else { continue }
                let score = scores.first(where: {
                    $0.noteRaw == note.rawValue && $0.stringNumber == string
                })?.score ?? 0.50
                noteScores[note, default: []].append(score)
            }
        }
        let weakest = noteScores.min(by: { a, b in
            let avgA = a.value.reduce(0, +) / Double(a.value.count)
            let avgB = b.value.reduce(0, +) / Double(b.value.count)
            return avgA < avgB
        })
        return weakest?.key ?? .e
    }

    private static func stringOrdinal(_ string: Int) -> String {
        switch string {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(string)th"
        }
    }

    private static func stringName(_ string: Int) -> String {
        switch string {
        case 1: return "high E"
        case 2: return "B"
        case 3: return "G"
        case 4: return "D"
        case 5: return "A"
        case 6: return "low E"
        default: return "\(string)"
        }
    }
}
