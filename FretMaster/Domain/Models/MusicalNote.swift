// MusicalNote.swift
// FretMaster — Domain Layer
//
// Represents one of the 12 chromatic pitch classes (C through B).
// Raw value is the pitch class integer (0 = C, 1 = C#/Db, … 11 = B).

import Foundation

/// One of the 12 chromatic pitch classes used in Western music.
/// The raw `Int` value is the pitch class (0–11), where 0 = C.
public enum MusicalNote: Int, CaseIterable, Codable, Sendable, Hashable, Identifiable {
    case c  = 0
    case cSharp = 1
    case d  = 2
    case dSharp = 3
    case e  = 4
    case f  = 5
    case fSharp = 6
    case g  = 7
    case gSharp = 8
    case a  = 9
    case aSharp = 10
    case b  = 11

    public var id: Int { rawValue }

    // MARK: - Display Names

    /// The sharp name of this note (e.g. "C#").
    public var sharpName: String {
        switch self {
        case .c:      return "C"
        case .cSharp: return "C#"
        case .d:      return "D"
        case .dSharp: return "D#"
        case .e:      return "E"
        case .f:      return "F"
        case .fSharp: return "F#"
        case .g:      return "G"
        case .gSharp: return "G#"
        case .a:      return "A"
        case .aSharp: return "A#"
        case .b:      return "B"
        }
    }

    /// The flat name of this note (e.g. "Db").
    public var flatName: String {
        switch self {
        case .c:      return "C"
        case .cSharp: return "Db"
        case .d:      return "D"
        case .dSharp: return "Eb"
        case .e:      return "E"
        case .f:      return "F"
        case .fSharp: return "Gb"
        case .g:      return "G"
        case .gSharp: return "Ab"
        case .a:      return "A"
        case .aSharp: return "Bb"
        case .b:      return "B"
        }
    }

    /// Returns `true` when this note is a natural (no accidental).
    public var isNatural: Bool {
        switch self {
        case .c, .d, .e, .f, .g, .a, .b: return true
        default: return false
        }
    }

    /// Display name respecting the user's chosen accidental preference.
    public func displayName(format: NoteNameFormat) -> String {
        switch format {
        case .sharps:  return sharpName
        case .flats:   return flatName
        case .both:
            if sharpName == flatName { return sharpName }
            return "\(sharpName)/\(flatName)"
        }
    }

    // MARK: - Interval Arithmetic

    /// Returns the note that is `semitones` half-steps above this note.
    public func transposed(by semitones: Int) -> MusicalNote {
        let newRaw = ((rawValue + semitones) % 12 + 12) % 12
        return MusicalNote(rawValue: newRaw)! // safe: modulo always in 0…11
    }

    // MARK: - Circle of Fourths / Fifths

    /// The 12 notes ordered by ascending perfect fourths (C F Bb Eb Ab Db Gb B E A D G).
    public static let circleOfFourths: [MusicalNote] = {
        var notes: [MusicalNote] = []
        var current = MusicalNote.c
        for _ in 0..<12 {
            notes.append(current)
            current = current.transposed(by: 5) // perfect fourth = 5 semitones
        }
        return notes
    }()

    /// The 12 notes ordered by ascending perfect fifths (C G D A E B F# C# Ab Eb Bb F).
    public static let circleOfFifths: [MusicalNote] = {
        var notes: [MusicalNote] = []
        var current = MusicalNote.c
        for _ in 0..<12 {
            notes.append(current)
            current = current.transposed(by: 7) // perfect fifth = 7 semitones
        }
        return notes
    }()

    /// Returns the next note in the circle of fourths after `self`.
    public var nextInCircleOfFourths: MusicalNote {
        transposed(by: 5)
    }

    /// Returns the next note in the circle of fifths after `self`.
    public var nextInCircleOfFifths: MusicalNote {
        transposed(by: 7)
    }

    // MARK: - Enharmonic Equivalents

    /// Returns `true` when `other` represents the same pitch class as `self`.
    /// (Always true for the same enum case; also true for enharmonic pairs.)
    public func isEnharmonic(with other: MusicalNote) -> Bool {
        rawValue == other.rawValue
    }
}

// MARK: - NoteNameFormat

/// Controls how accidentals are displayed in the UI.
public enum NoteNameFormat: String, CaseIterable, Codable, Sendable {
    case sharps  = "sharps"
    case flats   = "flats"
    case both    = "both"

    public var localizedLabel: String {
        switch self {
        case .sharps: return String(localized: "Sharps (#)", bundle: .main)
        case .flats:  return String(localized: "Flats (b)", bundle: .main)
        case .both:   return String(localized: "Both", bundle: .main)
        }
    }
}
