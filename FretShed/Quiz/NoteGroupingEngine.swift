// NoteGroupingEngine.swift
// FretShed — Quiz Layer
//
// Selects musically meaningful note groups for Smart Practice sessions.
// Pure computation — no audio, no UI.
// Input: mastery data + phase + constraints.
// Output: ordered note groups with musical context metadata.

import Foundation

// MARK: - GroupType

/// The type of musical grouping used for a note group.
enum GroupType: String, Codable, Sendable {
    case scaleFragment      // Phase 1: adjacent natural notes on one string
    case chromaticFragment  // Phase 2: adjacent chromatic notes (including accidentals)
    case triad              // Phase 3: major/minor triad across strings
    case chordTones         // Phase 4: chord-tone patterns from progressions
    case octavePair         // Cross-string octave patterns
}

// MARK: - NoteGroupContext

/// Musical context metadata for a note group, displayed on the results screen.
struct NoteGroupContext: Sendable {
    let groupType: GroupType
    let description: String       // "C-D-E: first three steps of C major scale"
    let key: String?              // "C major"
    let musicalName: String?      // "C major triad", "ii-V-I in C"
    let intervalNames: [String]?  // ["root", "major 3rd", "perfect 5th"]
}

// MARK: - NoteTarget

/// A single note target for a quiz question, with its fretboard position.
struct NoteTarget: Equatable, Sendable {
    let note: MusicalNote
    let string: Int
    let fret: Int
}

// MARK: - NoteGroup

/// A group of musically related notes with context metadata.
struct NoteGroup: Sendable {
    let targets: [NoteTarget]
    let context: NoteGroupContext

    /// The fret span of this group (max fret - min fret).
    var fretSpan: Int {
        guard let minFret = targets.map(\.fret).min(),
              let maxFret = targets.map(\.fret).max() else { return 0 }
        return maxFret - minFret
    }
}

// MARK: - SessionPlan

/// The complete plan for a Smart Practice session: groups + repetition schedule.
struct SessionPlan: Sendable {
    let groups: [NoteGroup]
    let questionSequence: [NoteTarget]  // Interleaved, with repetitions
    let totalQuestions: Int
}

// MARK: - NoteGroupingEngine

/// Generates musically meaningful note groups for Smart Practice sessions.
struct NoteGroupingEngine: Sendable {

    private let fretboardMap: FretboardMap

    /// Maximum fret span allowed within a single group.
    static let maxFretSpan = 5

    init(fretboardMap: FretboardMap = FretboardMap()) {
        self.fretboardMap = fretboardMap
    }

    // MARK: - Phase 1: Scale Fragments

    /// Generates 3-note scale fragment groups on a single string.
    /// - Parameters:
    ///   - string: Target string number (1-6).
    ///   - fretStart: Start of fret range (inclusive).
    ///   - fretEnd: End of fret range (inclusive).
    ///   - scores: Current mastery scores for weakness ranking.
    ///   - groupCount: Number of groups to generate (default 2).
    /// - Returns: Array of NoteGroups, each containing 3 adjacent natural notes.
    func scaleFragments(
        onString string: Int,
        fretStart: Int = 0,
        fretEnd: Int = 7,
        scores: [MasteryScore] = [],
        groupCount: Int = 2
    ) -> [NoteGroup] {
        // Get natural notes on the string, sorted by fret
        let naturalCells = naturalNotesOnString(string, fretStart: fretStart, fretEnd: fretEnd)
        guard naturalCells.count >= 3 else { return [] }

        // Build all possible 3-note windows
        var windows: [(targets: [NoteTarget], weaknessScore: Double)] = []
        for i in 0...(naturalCells.count - 3) {
            let group = Array(naturalCells[i..<(i + 3)])
            let span = group.last!.fret - group.first!.fret
            guard span <= Self.maxFretSpan else { continue }

            // Score by weakness — lower mastery = higher priority
            let weakness = group.reduce(0.0) { sum, target in
                let cellScore = scores.first(where: {
                    $0.noteRaw == target.note.rawValue && $0.stringNumber == target.string
                })?.score ?? 0.5
                return sum + (1.0 - cellScore)
            }
            windows.append((group, weakness))
        }

        // Sort by weakness (most weak first)
        let sorted = windows.sorted { $0.weaknessScore > $1.weaknessScore }

        // Select non-overlapping groups up to groupCount
        var selected: [[NoteTarget]] = []
        var usedFrets: Set<Int> = []

        for window in sorted {
            guard selected.count < groupCount else { break }
            let frets = Set(window.targets.map(\.fret))
            // Allow partial overlap but prefer non-overlapping
            if usedFrets.isDisjoint(with: frets) || selected.count < groupCount && selected.isEmpty == false {
                // Only add if at least one new fret or it's the first/second group
                if usedFrets.isDisjoint(with: frets) || selected.count < groupCount {
                    selected.append(window.targets)
                    usedFrets.formUnion(frets)
                }
            }
        }

        // If we couldn't get enough non-overlapping groups, take the top ones
        if selected.count < groupCount {
            for window in sorted {
                guard selected.count < groupCount else { break }
                if !selected.contains(where: { $0 == window.targets }) {
                    selected.append(window.targets)
                }
            }
        }

        // Build NoteGroups with context
        return selected.map { targets in
            let noteNames = targets.map { $0.note.sharpName }
            let stringName = Self.stringName(string)
            let scaleContext = scaleFragmentContext(notes: targets.map(\.note), onString: string)

            return NoteGroup(
                targets: targets,
                context: NoteGroupContext(
                    groupType: .scaleFragment,
                    description: "\(noteNames.joined(separator: "-")) on the \(stringName) string\(scaleContext.map { " — \($0)" } ?? "")",
                    key: scaleKeyForNotes(targets.map(\.note)),
                    musicalName: scaleContext,
                    intervalNames: nil
                )
            )
        }
    }

    // MARK: - Phase 2: Chromatic Fragments (Expansion)

    /// Generates 3-4 note chromatic fragment groups on a single string.
    /// Includes sharps and flats — for Phase 2 (Expansion) sessions.
    func chromaticFragments(
        onString string: Int,
        fretStart: Int = 0,
        fretEnd: Int = 12,
        scores: [MasteryScore] = [],
        groupCount: Int = 2
    ) -> [NoteGroup] {
        // Get all chromatic notes on the string, sorted by fret
        let allCells = chromaticNotesOnString(string, fretStart: fretStart, fretEnd: fretEnd)
        guard allCells.count >= 3 else { return [] }

        // Build all possible 3-note windows
        var windows: [(targets: [NoteTarget], weaknessScore: Double)] = []
        for i in 0...(allCells.count - 3) {
            let group = Array(allCells[i..<(i + 3)])
            let span = group.last!.fret - group.first!.fret
            guard span <= Self.maxFretSpan else { continue }

            let weakness = group.reduce(0.0) { sum, target in
                let cellScore = scores.first(where: {
                    $0.noteRaw == target.note.rawValue && $0.stringNumber == target.string
                })?.score ?? 0.5
                return sum + (1.0 - cellScore)
            }
            windows.append((group, weakness))
        }

        let sorted = windows.sorted { $0.weaknessScore > $1.weaknessScore }

        var selected: [[NoteTarget]] = []
        var usedFrets: Set<Int> = []

        for window in sorted {
            guard selected.count < groupCount else { break }
            let frets = Set(window.targets.map(\.fret))
            if usedFrets.isDisjoint(with: frets) || selected.count < groupCount && selected.isEmpty == false {
                if usedFrets.isDisjoint(with: frets) || selected.count < groupCount {
                    selected.append(window.targets)
                    usedFrets.formUnion(frets)
                }
            }
        }

        if selected.count < groupCount {
            for window in sorted {
                guard selected.count < groupCount else { break }
                if !selected.contains(where: { $0 == window.targets }) {
                    selected.append(window.targets)
                }
            }
        }

        return selected.map { targets in
            let noteNames = targets.map { $0.note.sharpName }
            let stringName = Self.stringName(string)

            return NoteGroup(
                targets: targets,
                context: NoteGroupContext(
                    groupType: .chromaticFragment,
                    description: "\(noteNames.joined(separator: "-")) on the \(stringName) string — sharps & flats",
                    key: nil,
                    musicalName: "chromatic fragment",
                    intervalNames: nil
                )
            )
        }
    }

    // MARK: - Phase 3: Triad Groupings (Connection)

    /// Generates triad note groups across multiple strings.
    /// - Parameters:
    ///   - rootNote: The root of the triad.
    ///   - quality: Major (default) or minor.
    ///   - strings: Available strings to use.
    ///   - fretStart: Start of fret range.
    ///   - fretEnd: End of fret range.
    /// - Returns: A NoteGroup containing the 3 triad tones mapped to fretboard positions.
    func triadGroup(
        root rootNote: MusicalNote,
        quality: TriadQuality = .major,
        strings: [Int],
        fretStart: Int = 0,
        fretEnd: Int = 7
    ) -> NoteGroup? {
        let intervals = quality.intervals
        let triadNotes = intervals.map { rootNote.transposed(by: $0) }

        // Find the best position for each triad tone across available strings
        var bestTargets: [NoteTarget] = []
        for triadNote in triadNotes {
            var candidates: [NoteTarget] = []
            for string in strings {
                for fret in fretStart...fretEnd {
                    if fretboardMap.note(string: string, fret: fret) == triadNote {
                        candidates.append(NoteTarget(note: triadNote, string: string, fret: fret))
                    }
                }
            }
            guard !candidates.isEmpty else { return nil }
            bestTargets.append(contentsOf: [candidates.first!]) // Take first available
        }

        // Optimize: prefer positions with minimum fret span across strings
        let optimized = optimizeTriadPositions(triadNotes: triadNotes, strings: strings, fretStart: fretStart, fretEnd: fretEnd)
        let targets = optimized ?? bestTargets

        // Verify span constraint
        guard let span = fretSpan(of: targets), span <= Self.maxFretSpan else { return nil }

        let intervalNames = quality.intervalNames
        let noteNames = targets.map { $0.note.sharpName }

        return NoteGroup(
            targets: targets,
            context: NoteGroupContext(
                groupType: .triad,
                description: "\(noteNames.joined(separator: "-")): \(rootNote.sharpName) \(quality.displayName) triad",
                key: "\(rootNote.sharpName) \(quality.displayName)",
                musicalName: "\(rootNote.sharpName) \(quality.displayName) triad",
                intervalNames: intervalNames
            )
        )
    }

    /// Generates multiple triad groups targeting weak areas.
    /// - Parameter useAllRoots: When true, generates triads from all 12 chromatic roots
    ///   (for Phase 3 Connection, which has full chromatic vocabulary).
    func triadGroups(
        strings: [Int],
        scores: [MasteryScore] = [],
        fretStart: Int = 0,
        fretEnd: Int = 7,
        groupCount: Int = 2,
        useAllRoots: Bool = false
    ) -> [NoteGroup] {
        let roots: [MusicalNote]
        if useAllRoots {
            roots = [.c, .g, .d, .a, .e, .f, .cSharp, .dSharp, .fSharp, .gSharp, .aSharp, .b]
        } else {
            roots = [.c, .g, .d, .a, .e, .f]
        }

        var groups: [NoteGroup] = []

        for root in roots {
            guard groups.count < groupCount else { break }
            let quality: TriadQuality = useAllRoots && [MusicalNote.d, .e, .a, .b].contains(root) ? .minor : .major
            if let group = triadGroup(root: root, quality: quality, strings: strings, fretStart: fretStart, fretEnd: fretEnd) {
                let newNotes = Set(group.targets.map { "\($0.string)-\($0.fret)" })
                let isDuplicate = groups.contains { existing in
                    let existingNotes = Set(existing.targets.map { "\($0.string)-\($0.fret)" })
                    return newNotes == existingNotes
                }
                if !isDuplicate {
                    groups.append(group)
                }
            }
        }
        return groups
    }

    // MARK: - Phase 4: Chord-Tone Patterns

    /// Generates chord-tone pattern groups for full fretboard fluency.
    func chordToneGroups(
        progression: [(root: MusicalNote, quality: TriadQuality)],
        strings: [Int] = Array(1...6),
        fretStart: Int = 0,
        fretEnd: Int = 7
    ) -> [NoteGroup] {
        progression.compactMap { chord in
            triadGroup(root: chord.root, quality: chord.quality, strings: strings, fretStart: fretStart, fretEnd: fretEnd)
        }
    }

    // MARK: - Session Plan Builder

    /// Builds a complete session plan with interleaved groups and repetitions.
    /// - Parameters:
    ///   - groups: The note groups for this session.
    ///   - sessionLength: Total number of questions.
    ///   - scores: Mastery scores for weighting repetitions.
    ///   - reviewTargets: Additional review targets from stuck notes.
    /// - Returns: A SessionPlan with interleaved question sequence.
    func buildSessionPlan(
        groups: [NoteGroup],
        sessionLength: Int = 10,
        scores: [MasteryScore] = [],
        reviewTargets: [NoteTarget] = []
    ) -> SessionPlan {
        guard !groups.isEmpty else {
            return SessionPlan(groups: [], questionSequence: [], totalQuestions: 0)
        }

        var sequence: [NoteTarget] = []

        // Calculate how many questions per group
        let reviewSlots = min(reviewTargets.count, max(2, sessionLength * 25 / 100)) // 20-30% review
        let groupSlots = sessionLength - reviewSlots
        let slotsPerGroup = max(1, groupSlots / groups.count)

        // Build per-group repetitions weighted by weakness
        for group in groups {
            var groupTargets: [NoteTarget] = []
            for target in group.targets {
                let cellScore = scores.first(where: {
                    $0.noteRaw == target.note.rawValue && $0.stringNumber == target.string
                })?.score ?? 0.5
                // Weaker notes get more reps
                let reps = cellScore < 0.5 ? 2 : 1
                for _ in 0..<reps {
                    groupTargets.append(target)
                }
            }
            // Trim or pad to slotsPerGroup
            while groupTargets.count < slotsPerGroup {
                // Add weakest note again
                if let weakest = group.targets.min(by: { a, b in
                    let scoreA = scores.first(where: { $0.noteRaw == a.note.rawValue && $0.stringNumber == a.string })?.score ?? 0.5
                    let scoreB = scores.first(where: { $0.noteRaw == b.note.rawValue && $0.stringNumber == b.string })?.score ?? 0.5
                    return scoreA < scoreB
                }) {
                    groupTargets.append(weakest)
                } else {
                    break
                }
            }
            if groupTargets.count > slotsPerGroup {
                groupTargets = Array(groupTargets.prefix(slotsPerGroup))
            }
            sequence.append(contentsOf: groupTargets)
        }

        // Add review targets
        let reviewToAdd = Array(reviewTargets.prefix(reviewSlots))
        sequence.append(contentsOf: reviewToAdd)

        // Interleave: alternate between groups rather than blocking
        let interleaved = interleave(sequence, groupSizes: groups.map { _ in slotsPerGroup }, reviewCount: reviewToAdd.count)

        return SessionPlan(
            groups: groups,
            questionSequence: interleaved,
            totalQuestions: interleaved.count
        )
    }

    // MARK: - Private Helpers

    /// Returns all chromatic notes on a string sorted by fret position (deduped by note).
    private func chromaticNotesOnString(_ string: Int, fretStart: Int, fretEnd: Int) -> [NoteTarget] {
        var targets: [NoteTarget] = []
        var seenNotes: Set<Int> = []
        for fret in fretStart...fretEnd {
            guard let note = fretboardMap.note(string: string, fret: fret),
                  !seenNotes.contains(note.rawValue) else { continue }
            seenNotes.insert(note.rawValue)
            targets.append(NoteTarget(note: note, string: string, fret: fret))
        }
        return targets
    }

    /// Returns natural notes on a string sorted by fret position.
    private func naturalNotesOnString(_ string: Int, fretStart: Int, fretEnd: Int) -> [NoteTarget] {
        var targets: [NoteTarget] = []
        var seenNotes: Set<Int> = []
        for fret in fretStart...fretEnd {
            guard let note = fretboardMap.note(string: string, fret: fret),
                  note.isNatural,
                  !seenNotes.contains(note.rawValue) else { continue }
            seenNotes.insert(note.rawValue)
            targets.append(NoteTarget(note: note, string: string, fret: fret))
        }
        return targets
    }

    /// Finds optimal triad positions minimizing fret span.
    private func optimizeTriadPositions(
        triadNotes: [MusicalNote],
        strings: [Int],
        fretStart: Int,
        fretEnd: Int
    ) -> [NoteTarget]? {
        // Find all positions for each triad note
        var positionsPerNote: [[NoteTarget]] = []
        for note in triadNotes {
            var positions: [NoteTarget] = []
            for string in strings {
                for fret in fretStart...fretEnd {
                    if fretboardMap.note(string: string, fret: fret) == note {
                        positions.append(NoteTarget(note: note, string: string, fret: fret))
                    }
                }
            }
            guard !positions.isEmpty else { return nil }
            positionsPerNote.append(positions)
        }

        // Brute force: try all combinations (small search space: ≤5 × ≤5 × ≤5 = 125)
        var bestCombo: [NoteTarget]?
        var bestSpan = Int.max

        guard positionsPerNote.count == 3 else { return nil }
        for p0 in positionsPerNote[0] {
            for p1 in positionsPerNote[1] {
                for p2 in positionsPerNote[2] {
                    let combo = [p0, p1, p2]
                    // Prefer different strings
                    let uniqueStrings = Set(combo.map(\.string)).count
                    if let span = fretSpan(of: combo), span <= Self.maxFretSpan {
                        // Prefer: more unique strings, then smaller span
                        let effectiveSpan = span - (uniqueStrings * 10) // Heavily prefer string spread
                        if effectiveSpan < bestSpan {
                            bestSpan = effectiveSpan
                            bestCombo = combo
                        }
                    }
                }
            }
        }
        return bestCombo
    }

    /// Computes the fret span of a set of targets.
    private func fretSpan(of targets: [NoteTarget]) -> Int? {
        guard let minFret = targets.map(\.fret).min(),
              let maxFret = targets.map(\.fret).max() else { return nil }
        return maxFret - minFret
    }

    /// Interleaves question targets from multiple groups.
    private func interleave(_ sequence: [NoteTarget], groupSizes: [Int], reviewCount: Int) -> [NoteTarget] {
        guard groupSizes.count > 1 else { return sequence }

        var groups: [[NoteTarget]] = []
        var offset = 0
        for size in groupSizes {
            let end = min(offset + size, sequence.count)
            if offset < end {
                groups.append(Array(sequence[offset..<end]))
            }
            offset = end
        }

        // Review targets at the end of the sequence
        let reviewStart = groupSizes.reduce(0, +)
        let reviewTargets = reviewStart < sequence.count ? Array(sequence[reviewStart...]) : []

        // Round-robin interleave
        var result: [NoteTarget] = []
        let maxLen = groups.map(\.count).max() ?? 0
        for i in 0..<maxLen {
            for group in groups {
                if i < group.count {
                    result.append(group[i])
                }
            }
        }

        // Sprinkle review targets throughout
        if !reviewTargets.isEmpty && !result.isEmpty {
            let spacing = max(1, result.count / (reviewTargets.count + 1))
            for (i, review) in reviewTargets.enumerated() {
                let insertAt = min((i + 1) * spacing, result.count)
                result.insert(review, at: insertAt)
            }
        }

        return result
    }

    /// Determines the scale context for a 3-note fragment.
    private func scaleFragmentContext(notes: [MusicalNote], onString string: Int) -> String? {
        guard notes.count == 3 else { return nil }

        // Check if these 3 notes are consecutive steps in any major scale
        let majorScalePatterns: [(root: MusicalNote, name: String)] = [
            (.c, "C major"), (.g, "G major"), (.d, "D major"),
            (.a, "A major"), (.e, "E major"), (.f, "F major"),
            (.b, "B major")
        ]

        let majorIntervals = [0, 2, 4, 5, 7, 9, 11] // W-W-H-W-W-W-H

        for pattern in majorScalePatterns {
            let scaleNotes = majorIntervals.map { pattern.root.transposed(by: $0) }
            // Check if all 3 notes appear consecutively in this scale
            for i in 0...(scaleNotes.count - 3) {
                let window = Array(scaleNotes[i..<(i + 3)])
                if Set(notes) == Set(window) {
                    let degree = i + 1
                    let ordinal = Self.ordinal(degree)
                    return "\(ordinal)-\(Self.ordinal(degree+1))-\(Self.ordinal(degree+2)) steps of \(pattern.name) scale"
                }
            }
        }
        return nil
    }

    /// Determines a likely key for a set of notes.
    private func scaleKeyForNotes(_ notes: [MusicalNote]) -> String? {
        let majorScalePatterns: [(root: MusicalNote, name: String)] = [
            (.c, "C major"), (.g, "G major"), (.d, "D major"),
            (.a, "A major"), (.e, "E major"), (.f, "F major")
        ]
        let majorIntervals = [0, 2, 4, 5, 7, 9, 11]
        for pattern in majorScalePatterns {
            let scaleNotes = Set(majorIntervals.map { pattern.root.transposed(by: $0) })
            if Set(notes).isSubset(of: scaleNotes) {
                return pattern.name
            }
        }
        return nil
    }

    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    static func stringName(_ string: Int) -> String {
        switch string {
        case 1: return "high E"
        case 2: return "B"
        case 3: return "G"
        case 4: return "D"
        case 5: return "A"
        case 6: return "low E"
        default: return "\(string)"
        }
    }
}

// MARK: - TriadQuality

/// The quality of a triad chord.
enum TriadQuality: String, Codable, Sendable {
    case major
    case minor

    var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]   // root, major 3rd, perfect 5th
        case .minor: return [0, 3, 7]   // root, minor 3rd, perfect 5th
        }
    }

    var intervalNames: [String] {
        switch self {
        case .major: return ["root", "major 3rd", "perfect 5th"]
        case .minor: return ["root", "minor 3rd", "perfect 5th"]
        }
    }

    var displayName: String {
        switch self {
        case .major: return "major"
        case .minor: return "minor"
        }
    }
}
