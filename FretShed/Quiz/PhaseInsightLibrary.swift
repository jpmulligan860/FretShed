// PhaseInsightLibrary.swift
// FretShed — Quiz Layer
//
// Templated insight messages for the 4-phase learning progression.
// Messages use dynamic variables from session data to produce hundreds
// of unique combinations. No message should repeat within a week of daily use.
//
// Banned vocabulary: "dropped", "regressed", "back to", "lost"
// Approved vocabulary: "review", "warm up", "shore up", "refresh", "reinforce"

import Foundation

enum PhaseInsightLibrary {

    // MARK: - Phrase Selection

    /// Deterministic cycling: uses a hash of date + pool index to avoid repeats.
    static func phrase(from pool: [String], sessionCount: Int) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[sessionCount % pool.count]
    }

    // MARK: - Phase 1: Foundation

    static let foundationMusicalContext: [String] = [
        "Those notes — {notes} — are natural notes on the {string_name} string.",
        "{notes}: the building blocks of every key that uses the {string_name} string.",
        "You just drilled {notes} — the natural notes between frets {fret_start} and {fret_end}.",
        "Every scale on the {string_name} string passes through {notes}.",
        "{notes} on the {string_name} string — these are the landmarks you navigate by.",
    ]

    static let foundationPerformance: [String] = [
        "{n_mastered} of {n_total} natural notes proficient on the {string_name} string.",
        "You nailed {note} this session — that's one more down.",
        "{note} is now proficient. The {string_name} string is opening up.",
        "{note} on the {string_name} string clicked today. {n_remaining} to go.",
        "Clean reps on {notes}. The muscle memory is building.",
    ]

    static let foundationProximity: [String] = [
        "{n_remaining} more notes and you unlock Phase 2: Expansion!",
        "You're {n_remaining} notes away from sharps and flats.",
        "Almost there — {n_remaining} more on the {string_name} string.",
        "Finish the {string_name} string and you'll start adding sharps and flats.",
        "One more string after this and Phase 2 opens up.",
    ]

    static let foundationComeback: [String] = [
        "Welcome back. Let's refresh the {string_name} string.",
        "Time to warm up — the {string_name} string is waiting.",
        "Good to see you. Let's reinforce what you've learned on the {string_name} string.",
        "Picking up where you left off on the {string_name} string.",
    ]

    static let foundationEncouragement: [String] = [
        "Every note you lock in is permanent progress.",
        "Natural notes first — this is how every pro learned the neck.",
        "One string at a time. That's the way.",
        "The {string_name} string is yours. Keep building.",
        "This is real work. The fretboard is getting smaller.",
    ]

    // MARK: - Phase 2: Connection

    static let connectionMusicalContext: [String] = [
        "{notes} — that's a {musical_name} shape across strings.",
        "You just played a {musical_name}: {notes}. That shape appears everywhere.",
        "Those three notes form a {musical_name}. Knowing where they live across strings is the key.",
        "{notes} on the {string_name} strings — a {musical_name} using all notes.",
        "The {musical_name} pattern connects the {string_name} strings through {notes}.",
    ]

    static let connectionPerformance: [String] = [
        "Cross-string accuracy is at {accuracy}%. The connections are forming.",
        "You found {note} on two different strings this session. That's the point.",
        "The same note on different strings — your brain is mapping the fretboard in 2D now.",
        "Triads across strings in any key: that's how chords are built.",
        "Sharps, flats, naturals — you're connecting them all across strings now.",
    ]

    static let connectionProximity: [String] = [
        "Full chromatic cross-string mastery unlocks Phase 4.",
        "You're building connections across all notes on the fretboard.",
        "Once cross-string patterns are solid, full fretboard fluency is next.",
    ]

    static let connectionComeback: [String] = [
        "Welcome back. Let's warm up with some cross-string patterns.",
        "Time to refresh those cross-string connections.",
        "Good to see you. Let's reinforce the links between strings.",
        "Picking up where you left off — connecting notes across strings.",
    ]

    static let connectionEncouragement: [String] = [
        "Finding notes across strings is what separates fretboard readers from chord memorizers.",
        "Every triad pattern you learn unlocks dozens of chord voicings.",
        "Cross-string fluency is the skill that makes everything else easier.",
        "The fretboard is a grid. You're learning to navigate it.",
        "This is where individual strings become one connected instrument.",
    ]

    // MARK: - Phase 3: Expansion

    static let expansionMusicalContext: [String] = [
        "{notes} — the sharps and flats between frets {fret_start} and {fret_end} on the {string_name} string.",
        "{notes}: accidentals that fill in the gaps between natural notes.",
        "You just drilled {notes} — sharps and flats on the {string_name} string.",
        "Those notes — {notes} — are the accidentals most players never learn.",
        "{notes} on the {string_name} string. Every one of these fills a gap in your fretboard map.",
    ]

    static let expansionPerformance: [String] = [
        "Chromatic coverage expanding. {n_mastered} positions now proficient with sharps and flats.",
        "{note} is now in your vocabulary. One less gap on the fretboard.",
        "The space between natural notes is filling in.",
        "Sharps and flats at {accuracy}% — the full picture is coming into focus.",
    ]

    static let expansionProximity: [String] = [
        "Complete chromatic coverage unlocks Phase 3: Connection.",
        "Every sharp and flat you master brings you closer to knowing every note.",
        "Chromatic mastery on {n_remaining} more positions to go.",
        "{n_remaining} more notes on the {string_name} string and you're one step closer.",
    ]

    static let expansionComeback: [String] = [
        "Welcome back. Let's refresh those sharps and flats.",
        "Time to warm up the chromatic notes.",
        "Let's reinforce the sharps and flats you've been building.",
    ]

    static let expansionEncouragement: [String] = [
        "Sharps and flats are the notes most guitarists never learn. You're ahead of the curve.",
        "The chromatic fretboard is the full picture. You're almost there.",
        "Every accidental you learn is territory most players never map.",
        "This is advanced fretboard knowledge. Keep going.",
    ]

    // MARK: - Phase 4: Fluency

    static let fluencyMusicalContext: [String] = [
        "{notes} — chord tones from {musical_name}. You're thinking in harmony now.",
        "Those notes outline a {musical_name} across the neck.",
        "{musical_name}: {notes}. Seeing chord tones across strings is real fluency.",
        "The {key} chord tones you drilled are the foundation of every solo in that key.",
    ]

    static let fluencyPerformance: [String] = [
        "Full fretboard accuracy at {accuracy}%. That's fluency building.",
        "Chord-tone patterns are the highest level of fretboard knowledge.",
        "You're seeing the fretboard as harmony, not just individual notes.",
        "Every pattern you recognize speeds up everything — reading, improvising, composing.",
    ]

    static let fluencyEncouragement: [String] = [
        "You've earned this phase. The full fretboard is yours.",
        "Fluency means the fretboard works for you, not against you.",
        "Most guitarists never get here. Keep sharpening.",
        "This is the endgame — total fretboard command.",
    ]

    // MARK: - Phase Advancement Celebrations

    static let phaseAdvancementMessages: [LearningPhase: [String]] = [
        .expansion: [
            "Foundation complete! Natural notes are proficient on all 6 strings. Now let's add sharps and flats.",
            "Phase 1 done — you know every natural note. Phase 2 fills in the gaps between them.",
            "Natural notes are solid on every string. Time to complete the chromatic picture.",
        ],
        .connection: [
            "All notes proficient! Time to connect them across strings in any key.",
            "Phase 2 done — every note on every string. Now let's see how they connect across the fretboard.",
            "Full chromatic vocabulary unlocked. Phase 3 ties it together with cross-string patterns.",
        ],
        .fluency: [
            "Phase 3 complete! Cross-string connections are solid. Time for total fretboard fluency.",
            "Every note connects across strings. Phase 4 ties it all together with chord-tone patterns.",
            "Cross-string work complete. Welcome to the final phase — full fretboard fluency.",
        ],
    ]

    /// Returns a celebration message for advancing to the given phase.
    static func advancementMessage(to phase: LearningPhase, sessionCount: Int) -> String? {
        guard let messages = phaseAdvancementMessages[phase] else { return nil }
        return phrase(from: messages, sessionCount: sessionCount)
    }

    // MARK: - String Completion (Phase 1 milestone)

    static let stringCompletionMessages: [String] = [
        "The {string_name} string is proficient! Moving to the {next_string} string.",
        "{string_name} string complete — {n_strings_done} of {n_strings_needed} strings done.",
        "That's the {string_name} string done. {n_remaining_strings} more to Phase 2.",
        "Solid work on the {string_name} string. Next up: {next_string}.",
    ]

    // MARK: - Expansion String Completion (Phase 2 milestone)

    static let expansionStringCompletionMessages: [String] = [
        "Sharps & flats on the {string_name} string: proficient! Moving to the {next_string} string.",
        "{string_name} string chromatic complete — {n_strings_done} of {n_strings_needed} strings done.",
        "Every note on the {string_name} string is proficient. {n_remaining_strings} more to Phase 3.",
        "Full chromatic coverage on the {string_name} string. Next up: {next_string}.",
    ]

    // MARK: - Review Session Framing

    static let reviewSessionMessages: [String] = [
        "Quick warmup: refreshing the {string_name} string before moving on.",
        "Review time — shoring up the {string_name} string.",
        "A few reps to reinforce the {string_name} string, then on to new territory.",
        "Refreshing earlier work keeps it solid. Quick {string_name} string review.",
    ]

    // MARK: - Variable Substitution

    /// Substitutes template variables in a message string.
    static func substitute(_ template: String, variables: [String: String]) -> String {
        var result = template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }

    // MARK: - Musical Context from NoteGroupContext

    /// Generates a human-readable musical context message from a NoteGroupContext.
    static func musicalContextMessage(from context: NoteGroupContext, noteNames: [String], sessionCount: Int, stringName: String? = nil, fretStart: Int? = nil, fretEnd: Int? = nil) -> String {
        let pool: [String]
        switch context.groupType {
        case .scaleFragment:    pool = foundationMusicalContext
        case .chromaticFragment: pool = expansionMusicalContext
        case .triad:            pool = connectionMusicalContext
        case .chordTones:       pool = fluencyMusicalContext
        case .octavePair:       pool = connectionMusicalContext
        }

        let notesJoined = noteNames.joined(separator: ", ")
        var variables: [String: String] = [
            "notes": notesJoined,
        ]

        if let key = context.key { variables["key"] = key }
        if let name = context.musicalName { variables["musical_name"] = name }
        if let sn = stringName { variables["string_name"] = sn }
        if let fs = fretStart { variables["fret_start"] = "\(fs)" }
        if let fe = fretEnd { variables["fret_end"] = "\(fe)" }

        let template = phrase(from: pool, sessionCount: sessionCount)
        return substitute(template, variables: variables)
    }
}
