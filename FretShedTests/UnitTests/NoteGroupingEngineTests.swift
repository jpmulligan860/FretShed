// NoteGroupingEngineTests.swift
// FretShedTests

import XCTest
import SwiftData
@testable import FretShed

@MainActor
final class NoteGroupingEngineTests: XCTestCase {

    var engine: NoteGroupingEngine!
    var fretboardMap: FretboardMap!
    var container: ModelContainer!
    var masteryRepo: SwiftDataMasteryRepository!

    override func setUp() async throws {
        try await super.setUp()
        fretboardMap = FretboardMap()
        engine = NoteGroupingEngine(fretboardMap: fretboardMap)
        container = try makeModelContainer(inMemory: true)
        masteryRepo = SwiftDataMasteryRepository(context: ModelContext(container))
    }

    override func tearDown() async throws {
        engine = nil
        fretboardMap = nil
        container = nil
        masteryRepo = nil
        try await super.tearDown()
    }

    // MARK: - Scale Fragment Tests

    func test_scaleFragments_highEString_returns2Groups() {
        let groups = engine.scaleFragments(onString: 1)
        XCTAssertEqual(groups.count, 2)
    }

    func test_scaleFragments_eachGroupHas3Notes() {
        let groups = engine.scaleFragments(onString: 1)
        for group in groups {
            XCTAssertEqual(group.targets.count, 3, "Group should have exactly 3 notes")
        }
    }

    func test_scaleFragments_allNotesAreNatural() {
        for string in 1...6 {
            let groups = engine.scaleFragments(onString: string)
            for group in groups {
                for target in group.targets {
                    XCTAssertTrue(target.note.isNatural,
                                  "Note \(target.note.sharpName) on string \(string) should be natural")
                }
            }
        }
    }

    func test_scaleFragments_allStringsProduceGroups() {
        for string in 1...6 {
            let groups = engine.scaleFragments(onString: string)
            XCTAssertGreaterThanOrEqual(groups.count, 1,
                                        "String \(string) should produce at least 1 group")
        }
    }

    func test_scaleFragments_fretSpanWithin5() {
        for string in 1...6 {
            let groups = engine.scaleFragments(onString: string)
            for group in groups {
                XCTAssertLessThanOrEqual(group.fretSpan, NoteGroupingEngine.maxFretSpan,
                                         "Fret span \(group.fretSpan) exceeds max on string \(string)")
            }
        }
    }

    func test_scaleFragments_noDuplicatePositionsWithinGroup() {
        for string in 1...6 {
            let groups = engine.scaleFragments(onString: string)
            for group in groups {
                let positions = group.targets.map { "\($0.string)-\($0.fret)" }
                XCTAssertEqual(positions.count, Set(positions).count,
                               "Duplicate positions found in group on string \(string)")
            }
        }
    }

    func test_scaleFragments_weakNoteIncluded() throws {
        // Make one note very weak on string 5
        // String 5 (A): A(0), B(2), C(3), D(5), E(7)
        let weakNote = MusicalNote.d  // fret 5
        let score = MasteryScore(note: weakNote, stringNumber: 5)
        score.totalAttempts = 10
        score.correctAttempts = 2  // very low score
        try masteryRepo.save(score)

        // Make other notes strong
        for note: MusicalNote in [.a, .b, .c, .e] {
            let s = MasteryScore(note: note, stringNumber: 5)
            s.totalAttempts = 20
            s.correctAttempts = 19
            try masteryRepo.save(s)
        }

        let scores = try masteryRepo.allScores()
        let groups = engine.scaleFragments(onString: 5, scores: scores)

        // The weakest note (D) should appear in at least one group
        let allTargetNotes = groups.flatMap { $0.targets.map(\.note) }
        XCTAssertTrue(allTargetNotes.contains(.d),
                       "Weak note D should be included in at least one group")
    }

    func test_scaleFragments_contextMetadata() {
        let groups = engine.scaleFragments(onString: 5)
        for group in groups {
            XCTAssertEqual(group.context.groupType, .scaleFragment)
            XCTAssertFalse(group.context.description.isEmpty)
        }
    }

    func test_scaleFragments_highEString_correctNotes() {
        // String 1: E(0), F(1), G(3), A(5), B(7)
        let groups = engine.scaleFragments(onString: 1, groupCount: 3)
        let allNotes = Set(groups.flatMap { $0.targets.map { $0.note.sharpName } })
        // All notes should be from {E, F, G, A, B}
        let expected: Set<String> = ["E", "F", "G", "A", "B"]
        XCTAssertTrue(allNotes.isSubset(of: expected))
    }

    func test_scaleFragments_singleGroupRequest() {
        let groups = engine.scaleFragments(onString: 4, groupCount: 1)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].targets.count, 3)
    }

    // MARK: - Triad Tests

    func test_triad_cMajor_acrossStrings() {
        // C major: C-E-G
        let group = engine.triadGroup(root: .c, strings: [4, 5, 6])
        XCTAssertNotNil(group)
        if let group = group {
            let notes = Set(group.targets.map(\.note))
            XCTAssertTrue(notes.contains(.c))
            XCTAssertTrue(notes.contains(.e))
            XCTAssertTrue(notes.contains(.g))
            XCTAssertEqual(group.targets.count, 3)
        }
    }

    func test_triad_gMajor() {
        // G major: G-B-D
        let group = engine.triadGroup(root: .g, strings: [3, 4, 5, 6])
        XCTAssertNotNil(group)
        if let group = group {
            let notes = Set(group.targets.map(\.note))
            XCTAssertTrue(notes.contains(.g))
            XCTAssertTrue(notes.contains(.b))
            XCTAssertTrue(notes.contains(.d))
        }
    }

    func test_triad_dMajor() {
        // D major: D-F#-A
        let group = engine.triadGroup(root: .d, strings: [3, 4, 5])
        XCTAssertNotNil(group)
        if let group = group {
            let notes = Set(group.targets.map(\.note))
            XCTAssertTrue(notes.contains(.d))
            XCTAssertTrue(notes.contains(.fSharp))
            XCTAssertTrue(notes.contains(.a))
        }
    }

    func test_triad_aMajor() {
        // A major: A-C#-E
        let group = engine.triadGroup(root: .a, strings: [4, 5, 6])
        XCTAssertNotNil(group)
        if let group = group {
            let notes = Set(group.targets.map(\.note))
            XCTAssertTrue(notes.contains(.a))
            XCTAssertTrue(notes.contains(.cSharp))
            XCTAssertTrue(notes.contains(.e))
        }
    }

    func test_triad_eMajor() {
        // E major: E-G#-B
        let group = engine.triadGroup(root: .e, strings: [4, 5, 6])
        XCTAssertNotNil(group)
        if let group = group {
            let notes = Set(group.targets.map(\.note))
            XCTAssertTrue(notes.contains(.e))
            XCTAssertTrue(notes.contains(.gSharp))
            XCTAssertTrue(notes.contains(.b))
        }
    }

    func test_triad_fretSpanConstraint() {
        let roots: [MusicalNote] = [.c, .g, .d, .a, .e, .f]
        for root in roots {
            if let group = engine.triadGroup(root: root, strings: Array(1...6)) {
                XCTAssertLessThanOrEqual(group.fretSpan, NoteGroupingEngine.maxFretSpan,
                                         "Triad \(root.sharpName) major exceeds max fret span")
            }
        }
    }

    func test_triad_contextMetadata() {
        let group = engine.triadGroup(root: .c, strings: [4, 5, 6])
        XCTAssertNotNil(group)
        XCTAssertEqual(group?.context.groupType, .triad)
        XCTAssertEqual(group?.context.musicalName, "C major triad")
        XCTAssertEqual(group?.context.key, "C major")
        XCTAssertEqual(group?.context.intervalNames, ["root", "major 3rd", "perfect 5th"])
    }

    func test_triad_minorQuality() {
        // A minor: A-C-E
        let group = engine.triadGroup(root: .a, quality: .minor, strings: [4, 5, 6])
        XCTAssertNotNil(group)
        if let group = group {
            let notes = Set(group.targets.map(\.note))
            XCTAssertTrue(notes.contains(.a))
            XCTAssertTrue(notes.contains(.c))
            XCTAssertTrue(notes.contains(.e))
            XCTAssertEqual(group.context.musicalName, "A minor triad")
        }
    }

    func test_triadGroups_returnsRequestedCount() {
        let groups = engine.triadGroups(strings: [4, 5, 6], groupCount: 2)
        XCTAssertEqual(groups.count, 2)
    }

    func test_triadGroups_noDuplicateGroups() {
        let groups = engine.triadGroups(strings: Array(1...6), groupCount: 4)
        for i in 0..<groups.count {
            for j in (i+1)..<groups.count {
                let notesI = Set(groups[i].targets.map { "\($0.string)-\($0.fret)" })
                let notesJ = Set(groups[j].targets.map { "\($0.string)-\($0.fret)" })
                XCTAssertNotEqual(notesI, notesJ, "Groups \(i) and \(j) are duplicates")
            }
        }
    }

    // MARK: - Session Plan Tests

    func test_sessionPlan_interleavedNotBlocked() {
        let groups = engine.scaleFragments(onString: 5, groupCount: 2)
        guard groups.count == 2 else {
            XCTFail("Expected 2 groups")
            return
        }

        let plan = engine.buildSessionPlan(groups: groups, sessionLength: 10)
        XCTAssertGreaterThan(plan.totalQuestions, 0)

        // Check interleaving: first group target should not be followed by all first group targets
        if plan.questionSequence.count >= 4 {
            let firstGroupNotes = Set(groups[0].targets.map { $0.note.rawValue })
            let secondGroupNotes = Set(groups[1].targets.map { $0.note.rawValue })
            // At least some interleaving should occur (not all group 1 then all group 2)
            var foundAlternation = false
            var lastWasGroup1: Bool?
            for target in plan.questionSequence {
                let isGroup1 = firstGroupNotes.contains(target.note.rawValue)
                let isGroup2 = secondGroupNotes.contains(target.note.rawValue)
                if let last = lastWasGroup1 {
                    if (last && isGroup2) || (!last && isGroup1) {
                        foundAlternation = true
                        break
                    }
                }
                if isGroup1 { lastWasGroup1 = true }
                else if isGroup2 { lastWasGroup1 = false }
            }
            XCTAssertTrue(foundAlternation, "Session plan should interleave groups")
        }
    }

    func test_sessionPlan_includesReviewTargets() {
        let groups = engine.scaleFragments(onString: 4, groupCount: 1)
        let reviewTarget = NoteTarget(note: .a, string: 5, fret: 0)

        let plan = engine.buildSessionPlan(
            groups: groups,
            sessionLength: 10,
            reviewTargets: [reviewTarget]
        )

        let hasReview = plan.questionSequence.contains(where: {
            $0.note == .a && $0.string == 5 && $0.fret == 0
        })
        XCTAssertTrue(hasReview, "Session plan should include review targets")
    }

    func test_sessionPlan_emptyGroups_returnsEmptyPlan() {
        let plan = engine.buildSessionPlan(groups: [], sessionLength: 10)
        XCTAssertEqual(plan.totalQuestions, 0)
        XCTAssertTrue(plan.questionSequence.isEmpty)
    }

    func test_sessionPlan_respectsSessionLength() {
        let groups = engine.scaleFragments(onString: 6, groupCount: 2)
        let plan = engine.buildSessionPlan(groups: groups, sessionLength: 12)
        // Should be close to session length (exact match may vary due to rounding)
        XCTAssertGreaterThanOrEqual(plan.totalQuestions, 8)
        XCTAssertLessThanOrEqual(plan.totalQuestions, 16)
    }

    // MARK: - Chord-Tone Pattern Tests

    func test_chordToneGroups_IIVVinC() {
        let progression: [(root: MusicalNote, quality: TriadQuality)] = [
            (.c, .major), (.f, .major), (.g, .major)  // I-IV-V in C
        ]
        let groups = engine.chordToneGroups(progression: progression)
        // Should produce groups for each chord that has positions in range
        XCTAssertGreaterThanOrEqual(groups.count, 2,
                                     "Should produce at least 2 chord-tone groups for I-IV-V in C")
    }

    // MARK: - TriadQuality Tests

    func test_triadQuality_majorIntervals() {
        XCTAssertEqual(TriadQuality.major.intervals, [0, 4, 7])
    }

    func test_triadQuality_minorIntervals() {
        XCTAssertEqual(TriadQuality.minor.intervals, [0, 3, 7])
    }

    // MARK: - NoteGroupContext Tests

    func test_scaleFragment_hasKeyContext() {
        // E-F-G on string 1 should identify as part of C major
        let groups = engine.scaleFragments(onString: 1, groupCount: 1)
        guard let group = groups.first else {
            XCTFail("Expected at least one group")
            return
        }
        // Key should be identified
        XCTAssertNotNil(group.context.key, "Scale fragment should identify a key")
    }
}
