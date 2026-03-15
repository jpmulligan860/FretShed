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
        "{n_mastered} of {n_total} natural notes mastered on the {string_name} string.",
        "You nailed {note} this session — that's one more locked in.",
        "First-time mastery on {note}. The {string_name} string is opening up.",
        "{note} on the {string_name} string clicked today. {n_remaining} to go.",
        "Clean reps on {notes}. The muscle memory is building.",
    ]

    static let foundationProximity: [String] = [
        "{n_remaining} more notes and you unlock Phase 2: Connection!",
        "You're {n_remaining} notes away from cross-string practice.",
        "Almost there — {n_remaining} more on the {string_name} string.",
        "Finish the {string_name} string and you'll start finding notes across strings.",
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
        "{notes} on the {string_name} strings — a {musical_name} in open position.",
        "The {musical_name} pattern connects the {string_name} strings through {notes}.",
    ]

    static let connectionPerformance: [String] = [
        "{n_mastered} of 6 strings have solid natural note coverage.",
        "Cross-string accuracy is at {accuracy}%. The connections are forming.",
        "You found {note} on two different strings this session. That's the point.",
        "The same note on different strings — your brain is mapping the fretboard in 2D now.",
        "Triads across strings: that's how chords are built. You're learning the architecture.",
    ]

    static let connectionProximity: [String] = [
        "All 6 strings with solid natural notes unlocks Phase 3.",
        "Natural notes on {n_remaining} more strings and sharps & flats open up.",
        "You're building the foundation for the entire fretboard.",
        "Once all natural notes are solid, adding sharps and flats is straightforward.",
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
        "{note} is the sharp/flat between {natural_low} and {natural_high}.",
        "Every fret you skipped before has a note — {note} fills in the gap.",
        "{notes}: sharps and flats that complete the chromatic picture.",
        "Adding {note} means the {string_name} string has no blind spots left.",
        "{note} shows up in keys like {key}. It's not an edge case — it's essential.",
    ]

    static let expansionPerformance: [String] = [
        "Chromatic coverage expanding. {n_mastered} positions now mapped with sharps and flats.",
        "{note} is now in your vocabulary. One less gap on the fretboard.",
        "The space between natural notes is filling in.",
        "Sharps and flats at {accuracy}% — the full picture is coming into focus.",
    ]

    static let expansionProximity: [String] = [
        "Complete chromatic coverage unlocks Phase 4: Full Fretboard Fluency.",
        "Every sharp and flat you master brings you closer to knowing every note.",
        "Chromatic mastery on {n_remaining} more positions to go.",
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
        .connection: [
            "Phase 1 Complete! You've built a solid foundation. Time to connect the dots across strings.",
            "Foundation locked in. Phase 2 opens up cross-string patterns — this is where it gets fun.",
            "Natural notes are solid. Now let's see how they connect across the fretboard.",
        ],
        .expansion: [
            "Phase 2 Complete! Cross-string connections are solid. Time to add sharps and flats.",
            "You can find natural notes everywhere. Phase 3 fills in the gaps between them.",
            "Connection phase done. Now let's complete the chromatic picture.",
        ],
        .fluency: [
            "Phase 3 Complete! The full chromatic fretboard is mapped. Time for total fluency.",
            "Every note is in your vocabulary. Phase 4 ties it all together with chord-tone patterns.",
            "Chromatic mastery achieved. Welcome to the final phase — full fretboard fluency.",
        ],
    ]

    /// Returns a celebration message for advancing to the given phase.
    static func advancementMessage(to phase: LearningPhase, sessionCount: Int) -> String? {
        guard let messages = phaseAdvancementMessages[phase] else { return nil }
        return phrase(from: messages, sessionCount: sessionCount)
    }

    // MARK: - String Completion (Phase 1 milestone)

    static let stringCompletionMessages: [String] = [
        "The {string_name} string is locked in! Moving to the {next_string} string.",
        "{string_name} string complete — {n_strings_done} of {n_strings_needed} strings done.",
        "That's the {string_name} string mastered. {n_remaining_strings} more to Phase 2.",
        "Solid work on the {string_name} string. Next up: {next_string}.",
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
        case .scaleFragment: pool = foundationMusicalContext
        case .triad:         pool = connectionMusicalContext
        case .chordTones:    pool = fluencyMusicalContext
        case .octavePair:    pool = connectionMusicalContext
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
