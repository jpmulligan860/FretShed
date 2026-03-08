// Attempt.swift
// FretShed — Domain Layer
//
// Records a single note-identification attempt during a quiz session.

import Foundation
import SwiftData

// MARK: - GameMode

/// The scoring mode active during a quiz session.
public enum GameMode: String, CaseIterable, Codable, Sendable, Hashable {
    case untimed   = "untimed"
    case timed     = "timed"
    case tempo     = "tempo"     // Kept for backward compatibility with existing SwiftData records
    case streak    = "streak"

    /// Modes available for user selection in the UI. Excludes deprecated `.tempo`.
    public static var selectableCases: [GameMode] { [.untimed, .timed, .streak] }

    public var localizedLabel: String {
        switch self {
        case .timed:   return String(localized: "Timed", bundle: .main)
        case .untimed: return String(localized: "Relaxed", bundle: .main)
        case .streak:  return String(localized: "Streak", bundle: .main)
        case .tempo:   return String(localized: "Timed", bundle: .main) // Legacy — maps to Timed label
        }
    }
}

// MARK: - Attempt

/// A single recorded note-identification attempt within a practice session.
///
/// Persisted via SwiftData. All properties are value types to keep the model `Sendable`.
@Model
public final class Attempt {

    // MARK: Stored Properties

    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var targetNoteRaw: Int            // MusicalNote.rawValue
    public var targetString: Int             // 1–6; 0 = not specified
    public var targetFret: Int               // 0–24
    public var playedNoteRaw: Int?           // nil = timeout / miss
    public var playedString: Int?            // nil if acceptedAnyString or not detected
    public var responseTimeMs: Int
    public var wasCorrect: Bool
    public var sessionID: UUID
    public var gameModeRaw: String           // GameMode.rawValue
    public var acceptedAnyString: Bool
    public var detectedFrequencyHz: Double?  // Raw Hz from PitchDetector
    public var detectedConfidence: Double?   // 0.0–1.0 YIN confidence
    public var centsDeviation: Double?       // ±50 cents from equal temperament

    // MARK: Computed Convenience

    /// The note the user was asked to identify.
    public var targetNote: MusicalNote {
        get { MusicalNote(rawValue: targetNoteRaw) ?? .c }
        set { targetNoteRaw = newValue.rawValue }
    }

    /// The note the user actually played (`nil` on timeout or miss).
    public var playedNote: MusicalNote? {
        get { playedNoteRaw.flatMap { MusicalNote(rawValue: $0) } }
        set { playedNoteRaw = newValue?.rawValue }
    }

    /// The game mode active when this attempt was recorded.
    public var gameMode: GameMode {
        get { GameMode(rawValue: gameModeRaw) ?? .untimed }
        set { gameModeRaw = newValue.rawValue }
    }

    // MARK: Initializer

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        targetNote: MusicalNote,
        targetString: Int,
        targetFret: Int,
        playedNote: MusicalNote?,
        playedString: Int?,
        responseTimeMs: Int,
        wasCorrect: Bool,
        sessionID: UUID,
        gameMode: GameMode,
        acceptedAnyString: Bool,
        detectedFrequencyHz: Double? = nil,
        detectedConfidence: Double? = nil,
        centsDeviation: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.targetNoteRaw = targetNote.rawValue
        self.targetString = targetString
        self.targetFret = targetFret
        self.playedNoteRaw = playedNote?.rawValue
        self.playedString = playedString
        self.responseTimeMs = responseTimeMs
        self.wasCorrect = wasCorrect
        self.sessionID = sessionID
        self.gameModeRaw = gameMode.rawValue
        self.acceptedAnyString = acceptedAnyString
        self.detectedFrequencyHz = detectedFrequencyHz
        self.detectedConfidence = detectedConfidence
        self.centsDeviation = centsDeviation
    }
}
