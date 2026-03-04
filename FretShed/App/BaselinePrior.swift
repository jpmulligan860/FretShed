// BaselinePrior.swift
// FretShed — App Layer
//
// Onboarding baseline level selection. Seeds the Bayesian mastery system
// so the first adaptive session is better than random.

import Foundation

// MARK: - BaselineLevel

/// Self-assessed fretboard knowledge level selected during onboarding.
/// Each case provides prior scores for the 78-cell fretboard grid.
public enum BaselineLevel: String, CaseIterable, Codable, Sendable {
    case startingFresh
    case chordPlayer
    case openPosition
    case lowStringsSolid
    case rustyEverywhere

    public var title: String {
        switch self {
        case .startingFresh:    return "Starting Fresh"
        case .chordPlayer:      return "Chord Player"
        case .openPosition:     return "Open Position"
        case .lowStringsSolid:  return "Low Strings Solid"
        case .rustyEverywhere:  return "Rusty Everywhere"
        }
    }

    public var description: String {
        switch self {
        case .startingFresh:    return "I'm pretty new — couldn't tell you what note is where"
        case .chordPlayer:      return "I can play songs but couldn't name the notes if you asked me"
        case .openPosition:     return "I know my way around the first few frets"
        case .lowStringsSolid:  return "I know the E and A strings — like finding root notes for barre chords"
        case .rustyEverywhere:  return "I used to know more of this stuff, but it's been a while"
        }
    }

    public var emoji: String {
        switch self {
        case .startingFresh:    return "\u{1F331}"  // 🌱
        case .chordPlayer:      return "\u{1F3B6}"  // 🎶
        case .openPosition:     return "\u{1F3B8}"  // 🎸
        case .lowStringsSolid:  return "\u{1F3B5}"  // 🎵
        case .rustyEverywhere:  return "\u{1F527}"  // 🔧
        }
    }

    /// Returns the prior mastery score for a specific fretboard cell.
    /// - Parameters:
    ///   - string: Guitar string number (1 = high E, 6 = low E)
    ///   - fret: Fret number (0 = open)
    /// - Returns: Prior score in [0, 1]
    public func priorScore(string: Int, fret: Int) -> Double {
        switch self {
        case .startingFresh:
            return 0.50

        case .chordPlayer:
            if fret == 0 { return 0.75 }
            // Strings 2–5 (inner strings used for open chords), frets 0–3
            if (2...5).contains(string) && (0...3).contains(fret) { return 0.60 }
            return 0.50

        case .openPosition:
            if (0...4).contains(fret) { return 0.70 }
            return 0.50

        case .lowStringsSolid:
            // Strings 5–6 (A and low E)
            if (5...6).contains(string) { return 0.70 }
            return 0.50

        case .rustyEverywhere:
            return 0.55
        }
    }

    // MARK: - UserDefaults persistence

    private static let key = "baselineLevel"

    /// Saves the selected baseline level to UserDefaults.
    public func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.key)
    }

    /// Loads the saved baseline level, or nil if none has been selected.
    public static func load() -> BaselineLevel? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return BaselineLevel(rawValue: raw)
    }
}
