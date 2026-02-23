// ChordProgression.swift
// FretShed — Domain Layer
//
// Defines chord progressions used in Chord Progression practice mode.
// Each progression is a sequence of up to four chords expressed as
// scale degrees in a given key.  The quiz engine drills the root,
// major/minor third, and perfect fifth of each chord in turn.

import Foundation

// MARK: - ChordQuality

/// The quality (major / minor / dominant-seventh) of a chord.
public enum ChordQuality: String, Codable, CaseIterable, Sendable, Hashable {
    case major   = "major"
    case minor   = "minor"
    case dom7    = "dom7"      // dominant seventh (major triad + minor 7th)

    public var label: String {
        switch self {
        case .major: return "maj"
        case .minor: return "min"
        case .dom7:  return "7"
        }
    }

    /// Semitone intervals above the root for this quality [root, third, fifth].
    public var triadIntervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .dom7:  return [0, 4, 7]   // quiz only covers the triad; 7th is optional future work
        }
    }
}

// MARK: - ChordSlot

/// One chord in a progression: a root note and a quality.
public struct ChordSlot: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var root: MusicalNote
    public var quality: ChordQuality

    public init(id: UUID = UUID(), root: MusicalNote, quality: ChordQuality) {
        self.id = id
        self.root = root
        self.quality = quality
    }

    /// The three chord tones [root, third, fifth] for this slot.
    public var tones: [MusicalNote] {
        quality.triadIntervals.map { root.transposed(by: $0) }
    }

    public var label: String { "\(root.sharpName)\(quality.label)" }
}

// MARK: - ChordProgression

/// A named sequence of up to four chords to drill.
public struct ChordProgression: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var chords: [ChordSlot]    // 1–4 chords

    public init(id: UUID = UUID(), name: String, chords: [ChordSlot]) {
        self.id = id
        self.name = name
        self.chords = Array(chords.prefix(4))
    }

    /// Human-readable chord names, e.g. "Cmaj – Amaj – Fmaj – Gmaj".
    public var shortDescription: String {
        chords.map(\.label).joined(separator: " – ")
    }
}

// MARK: - Built-in Presets

public extension ChordProgression {

    /// The 8 most common progressions in modern popular music, all in the key of C.
    /// The SessionSetupView lets the user transpose to any key before starting.
    static let presets: [ChordProgression] = [
        // I – V – vi – IV  (the "four chord song")
        ChordProgression(name: "I – V – vi – IV", chords: [
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .g, quality: .major),
            ChordSlot(root: .a, quality: .minor),
            ChordSlot(root: .f, quality: .major)
        ]),
        // I – IV – V  (blues / rock staple)
        ChordProgression(name: "I – IV – V", chords: [
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .f, quality: .major),
            ChordSlot(root: .g, quality: .major)
        ]),
        // I – vi – IV – V  (50s progression)
        ChordProgression(name: "I – vi – IV – V", chords: [
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .a, quality: .minor),
            ChordSlot(root: .f, quality: .major),
            ChordSlot(root: .g, quality: .major)
        ]),
        // ii – V – I  (jazz staple)
        ChordProgression(name: "ii – V – I", chords: [
            ChordSlot(root: .d, quality: .minor),
            ChordSlot(root: .g, quality: .dom7),
            ChordSlot(root: .c, quality: .major)
        ]),
        // I – V – vi – iii – IV  (Canon progression)
        ChordProgression(name: "I – V – vi – iii – IV", chords: [
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .g, quality: .major),
            ChordSlot(root: .a, quality: .minor),
            ChordSlot(root: .e, quality: .minor)
        ]),
        // vi – IV – I – V  (minor-feel pop)
        ChordProgression(name: "vi – IV – I – V", chords: [
            ChordSlot(root: .a, quality: .minor),
            ChordSlot(root: .f, quality: .major),
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .g, quality: .major)
        ]),
        // I – IV – vi – V  (modern pop)
        ChordProgression(name: "I – IV – vi – V", chords: [
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .f, quality: .major),
            ChordSlot(root: .a, quality: .minor),
            ChordSlot(root: .g, quality: .major)
        ]),
        // I – III – IV – iv  (minor subdominant)
        ChordProgression(name: "I – III – IV – iv", chords: [
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .e, quality: .major),
            ChordSlot(root: .f, quality: .major),
            ChordSlot(root: .f, quality: .minor)
        ])
    ]

    /// A blank custom progression starting with four C-major chords.
    static func customTemplate() -> ChordProgression {
        ChordProgression(name: "Custom", chords: [
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .c, quality: .major),
            ChordSlot(root: .c, quality: .major)
        ])
    }
}

// MARK: - Transposition helpers

public extension ChordProgression {

    /// Returns a copy of this progression transposed so that the first chord's
    /// root becomes `newKey`.  All other chords are shifted by the same interval.
    func transposed(toKey newKey: MusicalNote) -> ChordProgression {
        guard let firstRoot = chords.first?.root else { return self }
        let semitones = (newKey.rawValue - firstRoot.rawValue + 12) % 12
        let newChords = chords.map { slot in
            ChordSlot(root: slot.root.transposed(by: semitones), quality: slot.quality)
        }
        return ChordProgression(id: id, name: name, chords: newChords)
    }
}
