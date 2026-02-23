// Session.swift
// FretShed — Domain Layer
//
// Represents a single practice session, from start to end.

import Foundation
import SwiftData

// MARK: - FocusMode

/// Determines which notes/strings are included in a quiz session.
public enum FocusMode: String, CaseIterable, Codable, Sendable, Hashable {
    case singleNote      = "singleNote"       // all strings, one note
    case singleString    = "singleString"     // all notes, selected strings
    case fullFretboard   = "fullFretboard"    // everything
    case fretboardPosition = "fretboardPosition" // selected fret range
    case circleOfFourths = "circleOfFourths"
    case circleOfFifths  = "circleOfFifths"
    case chordProgression = "chordProgression"

    public var localizedLabel: String {
        switch self {
        case .singleNote:         return String(localized: "Single Note", bundle: .main)
        case .singleString:       return String(localized: "String Selector", bundle: .main)
        case .fullFretboard:      return String(localized: "Full Fretboard", bundle: .main)
        case .fretboardPosition:  return String(localized: "Fretboard Position", bundle: .main)
        case .circleOfFourths:    return String(localized: "Circle of Fourths", bundle: .main)
        case .circleOfFifths:     return String(localized: "Circle of Fifths", bundle: .main)
        case .chordProgression:   return String(localized: "Chord Progression", bundle: .main)
        }
    }
}

// MARK: - MasteryLevel

/// Human-readable mastery tier derived from a numeric mastery score.
public enum MasteryLevel: String, CaseIterable, Codable, Sendable, Comparable {
    case beginner    = "beginner"
    case developing  = "developing"
    case proficient  = "proficient"
    case mastered    = "mastered"

    /// Derives a `MasteryLevel` from a 0–1 mastery score.
    public static func from(score: Double) -> MasteryLevel {
        switch score {
        case ..<0.40:  return .beginner
        case ..<0.70:  return .developing
        case ..<0.90:  return .proficient
        default:       return .mastered
        }
    }

    public var localizedLabel: String {
        switch self {
        case .beginner:   return String(localized: "Beginner", bundle: .main)
        case .developing: return String(localized: "Developing", bundle: .main)
        case .proficient: return String(localized: "Proficient", bundle: .main)
        case .mastered:   return String(localized: "Mastered", bundle: .main)
        }
    }

    public static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .beginner:   return 0
        case .developing: return 1
        case .proficient: return 2
        case .mastered:   return 3
        }
    }
}

// MARK: - Session

/// A complete practice session record, persisted via SwiftData.
@Model
public final class Session {

    // MARK: Stored Properties

    @Attribute(.unique) public var id: UUID
    public var startTime: Date
    public var endTime: Date?
    public var focusModeRaw: String           // FocusMode.rawValue
    public var gameModeRaw: String            // GameMode.rawValue
    public var attemptCount: Int
    public var correctCount: Int
    public var masteryDelta: Double           // score change during this session
    public var notes: [Int]                   // targeted MusicalNote rawValues
    public var targetStrings: [Int]           // targeted string numbers
    public var fretRangeStart: Int
    public var fretRangeEnd: Int
    public var isCompleted: Bool
    public var isPaused: Bool
    public var isAdaptive: Bool

    // Snapshot of overall mastery when session ended (for history chart)
    public var overallMasteryAtEnd: Double

    /// JSON-encoded ChordProgression for .chordProgression focus mode.
    /// Nil for all other modes.
    public var chordProgressionData: Data?

    // MARK: Computed Convenience

    public var focusMode: FocusMode {
        get { FocusMode(rawValue: focusModeRaw) ?? .fullFretboard }
        set { focusModeRaw = newValue.rawValue }
    }

    public var gameMode: GameMode {
        get { GameMode(rawValue: gameModeRaw) ?? .untimed }
        set { gameModeRaw = newValue.rawValue }
    }

    /// The decoded ChordProgression for .chordProgression mode.
    public var chordProgression: ChordProgression? {
        get {
            guard let data = chordProgressionData else { return nil }
            return try? JSONDecoder().decode(ChordProgression.self, from: data)
        }
        set {
            chordProgressionData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Duration of the session. Returns the elapsed time so far if the session is still running.
    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    /// Accuracy percentage (0–100). Returns 0 when no attempts have been made.
    public var accuracyPercent: Double {
        guard attemptCount > 0 else { return 0 }
        return (Double(correctCount) / Double(attemptCount)) * 100
    }

    /// Human-readable mastery tier for the overall score at session end.
    public var masteryLevel: MasteryLevel {
        MasteryLevel.from(score: overallMasteryAtEnd)
    }

    // MARK: Initializer

    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        focusMode: FocusMode,
        gameMode: GameMode,
        fretRangeStart: Int = 0,
        fretRangeEnd: Int = 12,
        targetNotes: [MusicalNote] = [],
        targetStrings: [Int] = [],
        chordProgression: ChordProgression? = nil,
        isAdaptive: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.focusModeRaw = focusMode.rawValue
        self.gameModeRaw = gameMode.rawValue
        self.attemptCount = 0
        self.correctCount = 0
        self.masteryDelta = 0
        self.notes = targetNotes.map(\.rawValue)
        self.targetStrings = targetStrings
        self.fretRangeStart = fretRangeStart
        self.fretRangeEnd = fretRangeEnd
        self.isCompleted = false
        self.isPaused = false
        self.isAdaptive = isAdaptive
        self.overallMasteryAtEnd = 0
        self.chordProgressionData = try? JSONEncoder().encode(chordProgression)
    }
}
