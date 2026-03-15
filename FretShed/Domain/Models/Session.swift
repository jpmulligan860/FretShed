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
    case accuracyAssessment = "accuracyAssessment"
    case naturalNotes = "naturalNotes"
    case sharpsAndFlats = "sharpsAndFlats"

    public var localizedLabel: String {
        switch self {
        case .singleNote:           return String(localized: "Same Note", bundle: .main)
        case .singleString:         return String(localized: "String Selector", bundle: .main)
        case .fullFretboard:        return String(localized: "Full Fretboard", bundle: .main)
        case .fretboardPosition:    return String(localized: "Fretboard Position", bundle: .main)
        case .circleOfFourths:      return String(localized: "Circle of Fourths", bundle: .main)
        case .circleOfFifths:       return String(localized: "Circle of Fifths", bundle: .main)
        case .chordProgression:     return String(localized: "Chord Progression", bundle: .main)
        case .accuracyAssessment:   return String(localized: "Accuracy Assessment", bundle: .main)
        case .naturalNotes:         return String(localized: "Natural Notes", bundle: .main)
        case .sharpsAndFlats:       return String(localized: "Sharps & Flats", bundle: .main)
        }
    }

    /// Focus modes currently available in the UI. Add new modes here as they ship.
    public static var activeCases: [FocusMode] {
        [.fullFretboard, .fretboardPosition, .singleString, .singleNote, .naturalNotes, .sharpsAndFlats]
    }

    /// True for modes available to free-tier users.
    public var isFreeMode: Bool {
        switch self {
        case .fullFretboard, .singleString: return true
        default: return false
        }
    }
}

// MARK: - MasteryLevel

/// Human-readable mastery tier derived from a numeric mastery score.
///
/// 4-tier system:
/// - `.struggling`  — mastery < 50% (cherry red)
/// - `.learning`    — mastery 50–89% (amber)
/// - `.proficient`  — mastery ≥ 75%, fewer than 15 attempts (green)
/// - `.mastered`    — mastery ≥ 75% AND ≥ 15 attempts (gold)
///
/// Legacy cases `.beginner` and `.developing` are kept as
/// deprecated aliases so that any persisted Codable data still decodes.
public enum MasteryLevel: String, CaseIterable, Codable, Sendable, Comparable {
    case struggling  = "struggling"
    case learning    = "learning"
    case proficient  = "proficient"
    case mastered    = "mastered"

    // Legacy aliases — kept for Codable backwards compatibility.
    case beginner    = "beginner"
    case developing  = "developing"

    /// All "real" cases used by the current 4-tier UI.
    public static var activeCases: [MasteryLevel] { [.struggling, .learning, .proficient, .mastered] }

    /// Exclude legacy cases from CaseIterable's default allCases.
    public static var allCases: [MasteryLevel] { [.struggling, .learning, .proficient, .mastered, .beginner, .developing] }

    /// Derives a `MasteryLevel` from a 0–1 mastery score.
    /// Use the overload with `isMastered` when you have access to the
    /// full `MasteryScore` to distinguish proficient from mastered.
    ///
    /// Thresholds account for Bayesian smoothing (α=2, β=1 → prior 0.667):
    /// - Struggling: < 0.50 (below-chance accuracy)
    /// - Learning: 0.50–0.74 (building accuracy)
    /// - Proficient: 0.75+ (consistent accuracy)
    /// - Mastered: 0.75+ AND ≥15 attempts (sustained mastery)
    public static func from(score: Double) -> MasteryLevel {
        switch score {
        case ..<0.50:  return .struggling
        case ..<0.75:  return .learning
        default:       return .proficient
        }
    }

    /// Derives a `MasteryLevel` with full context (score + attempt threshold).
    public static func from(score: Double, isMastered: Bool) -> MasteryLevel {
        switch score {
        case ..<0.50:  return .struggling
        case ..<0.75:  return .learning
        default:       return isMastered ? .mastered : .proficient
        }
    }

    public var localizedLabel: String {
        switch self {
        case .struggling, .beginner:   return String(localized: "Struggling", bundle: .main)
        case .learning, .developing:   return String(localized: "Learning", bundle: .main)
        case .proficient:              return String(localized: "Proficient", bundle: .main)
        case .mastered:                return String(localized: "Mastered", bundle: .main)
        }
    }

    public static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .struggling, .beginner:   return 0
        case .learning, .developing:   return 1
        case .proficient:              return 2
        case .mastered:                return 3
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

    /// ID of the calibration profile used for this session.
    /// Nullable for migration compatibility with existing sessions.
    public var calibrationProfileID: UUID?

    /// Time limit in seconds for timed practice sessions. 0 = no limit.
    public var sessionTimeLimitSeconds: Int = 0

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
        isAdaptive: Bool = false,
        sessionTimeLimitSeconds: Int = 0
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
        self.sessionTimeLimitSeconds = sessionTimeLimitSeconds
    }
}
