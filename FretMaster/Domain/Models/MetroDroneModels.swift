// MetroDroneModels.swift
// FretMaster — Domain Layer
//
// Supporting types for the MetroDrone practice tool (metronome + drone generator).

import Foundation

// MARK: - Beat Accent

/// Accent level for a single beat within a measure.
enum BeatAccent: String, Codable, CaseIterable, Sendable {
    case accent   // louder, higher-pitched click
    case normal   // standard click
    case muted    // silent beat (no click scheduled)

    /// Cycles to the next accent in order: accent → normal → muted → accent.
    var next: BeatAccent {
        switch self {
        case .accent: return .normal
        case .normal: return .muted
        case .muted:  return .accent
        }
    }
}

// MARK: - Time Signature

/// A musical time signature (e.g. 4/4, 3/4, 6/8).
struct TimeSignature: Codable, Sendable, Hashable {
    let beats: Int      // numerator
    let noteValue: Int  // denominator

    var label: String { "\(beats)/\(noteValue)" }

    static let twoFour   = TimeSignature(beats: 2, noteValue: 4)
    static let threeFour = TimeSignature(beats: 3, noteValue: 4)
    static let fourFour  = TimeSignature(beats: 4, noteValue: 4)
    static let fiveFour  = TimeSignature(beats: 5, noteValue: 4)
    static let sixEight  = TimeSignature(beats: 6, noteValue: 8)
    static let sevenEight = TimeSignature(beats: 7, noteValue: 8)

    static let common: [TimeSignature] = [
        .twoFour, .threeFour, .fourFour, .fiveFour, .sixEight, .sevenEight
    ]
}

// MARK: - Drone Voicing

/// How many notes the drone plays simultaneously.
enum DroneVoicing: String, Codable, CaseIterable, Sendable {
    case root        // fundamental only
    case powerChord  // root + perfect 5th
    case majorTriad  // root + major 3rd + perfect 5th
    case minorTriad  // root + minor 3rd + perfect 5th

    var label: String {
        switch self {
        case .root:       return "Root"
        case .powerChord: return "Root + 5th"
        case .majorTriad: return "Major"
        case .minorTriad: return "Minor"
        }
    }

    /// Semitone intervals above the root for each voicing.
    var intervals: [Int] {
        switch self {
        case .root:       return [0]
        case .powerChord: return [0, 7]
        case .majorTriad: return [0, 4, 7]
        case .minorTriad: return [0, 3, 7]
        }
    }
}

// MARK: - Drone Sound

/// Timbre of the drone oscillator.
enum DroneSound: String, Codable, CaseIterable, Sendable {
    case pure  // single sine wave
    case rich  // fundamental + harmonics + slight detune for warmth

    var label: String {
        switch self {
        case .pure: return "Pure"
        case .rich: return "Rich"
        }
    }
}
