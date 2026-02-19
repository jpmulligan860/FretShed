// FretboardMap.swift
// FretMaster — Domain Layer
//
// Pre-computes the musical note at every fret on every string
// for standard guitar tuning (E2 A2 D3 G3 B3 E4).

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretmaster", category: "FretboardMap")

// MARK: - Constants

/// The maximum number of frets supported by the app.
public let kMaxFrets = 24

/// Number of guitar strings (always 6).
public let kStringCount = 6

// MARK: - FretboardMap

/// A pre-computed lookup table mapping `(stringNumber, fretNumber)` → `MusicalNote`.
///
/// - String numbering: 1 = high E (thinnest), 6 = low E (thickest).
/// - Fret numbering: 0 = open string (nut), 1–`kMaxFrets` = fretted positions.
/// - Standard tuning open string notes (low to high): E2, A2, D3, G3, B3, E4.
public struct FretboardMap: Sendable {

    // MARK: - Types

    /// A single cell on the fretboard identified by string and fret.
    public struct Position: Hashable, Sendable, Codable {
        /// Guitar string number (1 = high E … 6 = low E).
        public let string: Int
        /// Fret number (0 = open).
        public let fret: Int

        public init(string: Int, fret: Int) {
            self.string = string
            self.fret = fret
        }
    }

    // MARK: - Standard Tuning Open-String Notes

    /// Open-string MIDI-note pitches for standard tuning, indexed by string number (1…6).
    /// String 1 = E4 (MIDI 64), String 6 = E2 (MIDI 40).
    public static let standardTuningOpenNotes: [Int: MusicalNote] = [
        1: .e,  // E4 — high E
        2: .b,  // B3
        3: .g,  // G3
        4: .d,  // D3
        5: .a,  // A2
        6: .e   // E2 — low E
    ]

    /// Open-string octave numbers indexed by string number (1…6).
    public static let standardTuningOpenOctaves: [Int: Int] = [
        1: 4,  // E4
        2: 3,  // B3
        3: 3,  // G3
        4: 3,  // D3
        5: 2,  // A2
        6: 2   // E2
    ]

    // MARK: - Storage

    /// The underlying lookup: `[stringNumber: [fretNumber: MusicalNote]]`.
    /// String numbers 1–6; fret numbers 0–kMaxFrets.
    public let map: [Int: [Int: MusicalNote]]

    // MARK: - Initializer

    /// Builds the complete fretboard map for standard tuning up to `kMaxFrets` frets.
    public init() {
        var result: [Int: [Int: MusicalNote]] = [:]

        for stringNum in 1...kStringCount {
            guard let openNote = Self.standardTuningOpenNotes[stringNum] else {
                logger.error("Missing open-string note for string \(stringNum)")
                continue
            }
            var fretMap: [Int: MusicalNote] = [:]
            for fret in 0...kMaxFrets {
                fretMap[fret] = openNote.transposed(by: fret)
            }
            result[stringNum] = fretMap
        }

        self.map = result
        logger.debug("FretboardMap built: \(kStringCount) strings × \(kMaxFrets + 1) frets")
    }

    // MARK: - Lookup

    /// Returns the `MusicalNote` at a given string and fret, or `nil` for out-of-range input.
    public func note(string: Int, fret: Int) -> MusicalNote? {
        guard (1...kStringCount).contains(string),
              (0...kMaxFrets).contains(fret) else {
            return nil
        }
        return map[string]?[fret]
    }

    /// Returns every `Position` on the fretboard where a given note appears.
    /// - Parameters:
    ///   - note: The target `MusicalNote`.
    ///   - fretRange: The range of frets to search (default 0…kMaxFrets).
    /// - Returns: Array of `Position` values sorted by string then fret.
    public func positions(
        for note: MusicalNote,
        inFretRange fretRange: ClosedRange<Int> = 0...kMaxFrets
    ) -> [Position] {
        var positions: [Position] = []
        for string in 1...kStringCount {
            for fret in fretRange {
                if self.note(string: string, fret: fret) == note {
                    positions.append(Position(string: string, fret: fret))
                }
            }
        }
        return positions
    }

    /// Returns the octave number for a given position.
    /// Computes octave by counting semitones above the open-string pitch.
    public func octave(string: Int, fret: Int) -> Int? {
        guard let baseOctave = Self.standardTuningOpenOctaves[string],
              let baseNote = Self.standardTuningOpenNotes[string],
              (0...kMaxFrets).contains(fret) else {
            return nil
        }
        // Total semitones above C in the reference octave
        let basePitchClass = baseNote.rawValue
        let targetPitchClass = (basePitchClass + fret) % 12
        // Each time we wrap around past B→C, the octave increases
        let wraps = (basePitchClass + fret) / 12
        _ = targetPitchClass // suppress unused warning; used implicitly via wraps
        return baseOctave + wraps
    }

    // MARK: - Standard Fret Marker Positions

    /// Fret positions that conventionally have a single dot marker.
    public static let singleDotFrets: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]

    /// Fret positions that have double dot markers (octave markers).
    public static let doubleDotFrets: Set<Int> = [12, 24]
}
