// UserSettings.swift
// FretMaster — Domain Layer
//
// Single source of truth for all user preferences.
// Non-sensitive UI preferences live in UserDefaults (no SwiftData overhead).
// Preferences that should iCloud-sync are marked and mirrored to SwiftData in a future phase.

import Foundation
import SwiftData

// MARK: - Supporting Enums

/// Which accidental notation style to use when displaying note names.
// (Defined in MusicalNote.swift as NoteNameFormat)

/// Fretboard orientation for left-handed vs right-handed players.
public enum FretboardOrientation: String, CaseIterable, Codable, Sendable {
    case rightHand = "rightHand"
    case leftHand  = "leftHand"
}

/// How many frets to display on the fretboard by default.
public enum DefaultFretCount: Int, CaseIterable, Codable, Sendable {
    case twelve     = 12
    case fifteen    = 15
    case twentyTwo  = 22
    case twentyFour = 24

    public var label: String { "\(rawValue)" }
}

/// Tuner visual display style.
public enum TunerDisplayStyle: String, CaseIterable, Codable, Sendable {
    case needle = "needle"
    case strobe = "strobe"

    public var localizedLabel: String {
        switch self {
        case .needle: return String(localized: "Needle", bundle: .main)
        case .strobe: return String(localized: "Strobe", bundle: .main)
        }
    }
}

/// Reference A tuning frequency for the tuner.
public enum ReferenceA: Int, CaseIterable, Codable, Sendable {
    case hz432 = 432
    case hz440 = 440

    public var hertz: Double { Double(rawValue) }
    public var label: String { "\(rawValue) Hz" }
}

/// Circle direction for circle-of-fourths/fifths practice mode.
public enum CircleDirection: String, CaseIterable, Codable, Sendable {
    case fourths = "fourths"
    case fifths  = "fifths"
}

/// How the quiz selects strings when in single-note mode.
public enum StringOrdering: String, CaseIterable, Codable, Sendable {
    case inOrder           = "inOrder"
    case random            = "random"
    case weightedUnmastered = "weightedUnmastered"
    case skipMastered      = "skipMastered"

    public var localizedLabel: String {
        switch self {
        case .inOrder:            return String(localized: "In Order", bundle: .main)
        case .random:             return String(localized: "Random", bundle: .main)
        case .weightedUnmastered: return String(localized: "Weighted (Unmastered)", bundle: .main)
        case .skipMastered:       return String(localized: "Skip Mastered", bundle: .main)
        }
    }
}

/// How the fretboard is displayed during a session.
public enum FretboardDisplay: String, CaseIterable, Codable, Sendable {
    case fullFretboard    = "fullFretboard"
    case autoZoom         = "autoZoom"
    case fullWithHighlight = "fullWithHighlight"
}

/// How many fret positions are highlighted for the target note.
public enum NoteHighlighting: String, CaseIterable, Codable, Sendable {
    case singlePosition     = "singlePosition"
    case allPositions       = "allPositions"
    case singleThenReveal   = "singleThenReveal"
}

/// Whether the user must play the correct string or just the correct pitch.
public enum NoteAcceptanceMode: String, CaseIterable, Codable, Sendable {
    case exactString   = "exactString"
    case anyString     = "anyString"
}

/// How note names are shown on fret dots during a session.
public enum NoteDisplayMode: String, CaseIterable, Codable, Sendable {
    case showNames    = "showNames"
    case dotsOnly     = "dotsOnly"
    case revealOnPlay = "revealOnPlay"
    case hintOnTimeout = "hintOnTimeout"
}

// MARK: - UserSettings (SwiftData model for cloud-synced preferences)

/// User preferences that are persisted and optionally iCloud-synced.
/// Lightweight preferences (theme, etc.) use `UserDefaults`; see `LocalUserPreferences`.
@Model
public final class UserSettings {

    @Attribute(.unique) public var id: UUID

    // Audio
    public var confidenceThreshold: Float          // 0.70 – 0.99
    public var noteHoldDurationMs: Int             // 50 – 200 ms
    public var forceBuiltInMic: Bool

    // Quiz defaults
    public var defaultGameModeRaw: String
    public var defaultTimerDuration: Int           // seconds
    public var defaultSessionLength: Int           // number of questions per session
    public var hintTimeoutSeconds: Int
    public var circleDirectionRaw: String
    public var masteryThreshold: Double
    public var defaultStringOrderingRaw: String
    public var defaultFretboardDisplayRaw: String
    public var defaultNoteHighlightingRaw: String
    public var defaultNoteAcceptanceModeRaw: String
    public var defaultNoteDisplayModeRaw: String

    // Sound & Haptics
    public var correctSoundEnabled: Bool
    public var correctSoundVolume: Float
    public var incorrectSoundEnabled: Bool
    public var isMetronomeEnabled: Bool
    public var metronomeVolume: Float
    public var hapticFeedbackEnabled: Bool

    // Tuner
    public var tunerDisplayStyleRaw: String
    public var referenceAHz: Int                   // e.g. 440
    public var tunerSensitivity: Float

    // Notifications
    public var practiceReminderEnabled: Bool
    public var practiceReminderHour: Int
    public var practiceReminderMinute: Int
    public var streakReminderEnabled: Bool

    // MARK: Computed Typed Accessors

    public var defaultGameMode: GameMode {
        get { GameMode(rawValue: defaultGameModeRaw) ?? .untimed }
        set { defaultGameModeRaw = newValue.rawValue }
    }

    public var circleDirection: CircleDirection {
        get { CircleDirection(rawValue: circleDirectionRaw) ?? .fourths }
        set { circleDirectionRaw = newValue.rawValue }
    }

    public var defaultStringOrdering: StringOrdering {
        get { StringOrdering(rawValue: defaultStringOrderingRaw) ?? .random }
        set { defaultStringOrderingRaw = newValue.rawValue }
    }

    public var defaultFretboardDisplay: FretboardDisplay {
        get { FretboardDisplay(rawValue: defaultFretboardDisplayRaw) ?? .fullFretboard }
        set { defaultFretboardDisplayRaw = newValue.rawValue }
    }

    public var defaultNoteHighlighting: NoteHighlighting {
        get { NoteHighlighting(rawValue: defaultNoteHighlightingRaw) ?? .singlePosition }
        set { defaultNoteHighlightingRaw = newValue.rawValue }
    }

    public var defaultNoteAcceptanceMode: NoteAcceptanceMode {
        get { NoteAcceptanceMode(rawValue: defaultNoteAcceptanceModeRaw) ?? .exactString }
        set { defaultNoteAcceptanceModeRaw = newValue.rawValue }
    }

    public var defaultNoteDisplayMode: NoteDisplayMode {
        get { NoteDisplayMode(rawValue: defaultNoteDisplayModeRaw) ?? .showNames }
        set { defaultNoteDisplayModeRaw = newValue.rawValue }
    }

    public var tunerDisplayStyle: TunerDisplayStyle {
        get { TunerDisplayStyle(rawValue: tunerDisplayStyleRaw) ?? .needle }
        set { tunerDisplayStyleRaw = newValue.rawValue }
    }

    // MARK: Initializer

    public init() {
        self.id = UUID()
        self.confidenceThreshold = 0.85
        self.noteHoldDurationMs = 80
        self.forceBuiltInMic = false
        self.defaultGameModeRaw = GameMode.untimed.rawValue
        self.defaultTimerDuration = 10
        self.defaultSessionLength = 20
        self.hintTimeoutSeconds = 5
        self.circleDirectionRaw = CircleDirection.fourths.rawValue
        self.masteryThreshold = 0.90
        self.defaultStringOrderingRaw = StringOrdering.random.rawValue
        self.defaultFretboardDisplayRaw = FretboardDisplay.fullFretboard.rawValue
        self.defaultNoteHighlightingRaw = NoteHighlighting.singlePosition.rawValue
        self.defaultNoteAcceptanceModeRaw = NoteAcceptanceMode.exactString.rawValue
        self.defaultNoteDisplayModeRaw = NoteDisplayMode.showNames.rawValue
        self.correctSoundEnabled = true
        self.correctSoundVolume = 0.7
        self.incorrectSoundEnabled = true
        self.isMetronomeEnabled = true
        self.metronomeVolume = 0.7
        self.hapticFeedbackEnabled = true
        self.tunerDisplayStyleRaw = TunerDisplayStyle.needle.rawValue
        self.referenceAHz = 440
        self.tunerSensitivity = 0.85
        self.practiceReminderEnabled = false
        self.practiceReminderHour = 18
        self.practiceReminderMinute = 0
        self.streakReminderEnabled = false
    }
}

// MARK: - LocalUserPreferences (UserDefaults)

/// Lightweight preferences stored in `UserDefaults` (no iCloud sync needed).
/// Use `@AppStorage` in SwiftUI views to bind directly.
public enum LocalUserPreferences {

    /// Keys used for `UserDefaults` / `@AppStorage`.
    public enum Key {
        public static let hasCompletedOnboarding = "hasCompletedOnboarding"
        public static let noteNameFormat         = "noteNameFormat"
        public static let fretboardOrientation   = "fretboardOrientation"
        public static let defaultFretCount       = "defaultFretCount"
        public static let colorScheme            = "colorScheme"   // "light" / "dark" / "system"
        public static let lastActiveTab          = "lastActiveTab"
    }

    /// Default values matching the spec.
    public enum Default {
        public static let hasCompletedOnboarding = false
        public static let noteNameFormat         = NoteNameFormat.sharps.rawValue
        public static let fretboardOrientation   = FretboardOrientation.rightHand.rawValue
        public static let defaultFretCount       = DefaultFretCount.twentyTwo.rawValue
        public static let colorScheme            = "system"
    }
}
