// FretboardMapTests.swift
// FretMaster — Unit Tests
//
// Verifies every note at every fret/string is correct for standard tuning.

import XCTest
@testable import FretMaster

final class FretboardMapTests: XCTestCase {

    var map: FretboardMap!

    override func setUp() {
        super.setUp()
        map = FretboardMap()
    }

    // MARK: - Open String Notes (Standard Tuning)

    func test_openStrings_string1_isE4() {
        XCTAssertEqual(map.note(string: 1, fret: 0), .e, "String 1 open should be E (high E4)")
    }

    func test_openStrings_string2_isB() {
        XCTAssertEqual(map.note(string: 2, fret: 0), .b, "String 2 open should be B3")
    }

    func test_openStrings_string3_isG() {
        XCTAssertEqual(map.note(string: 3, fret: 0), .g, "String 3 open should be G3")
    }

    func test_openStrings_string4_isD() {
        XCTAssertEqual(map.note(string: 4, fret: 0), .d, "String 4 open should be D3")
    }

    func test_openStrings_string5_isA() {
        XCTAssertEqual(map.note(string: 5, fret: 0), .a, "String 5 open should be A2")
    }

    func test_openStrings_string6_isE2() {
        XCTAssertEqual(map.note(string: 6, fret: 0), .e, "String 6 open should be E (low E2)")
    }

    // MARK: - Well-Known Fret Positions (Standard Tuning Reference Chart)

    func test_string1_fret5_isA() {
        // E4 + 5 semitones = A4
        XCTAssertEqual(map.note(string: 1, fret: 5), .a)
    }

    func test_string1_fret7_isB() {
        XCTAssertEqual(map.note(string: 1, fret: 7), .b)
    }

    func test_string1_fret12_isE() {
        // Octave — same pitch class as open
        XCTAssertEqual(map.note(string: 1, fret: 12), .e)
    }

    func test_string2_fret5_isE() {
        // B + 5 = E
        XCTAssertEqual(map.note(string: 2, fret: 5), .e)
    }

    func test_string3_fret2_isA() {
        // G + 2 = A
        XCTAssertEqual(map.note(string: 3, fret: 2), .a)
    }

    func test_string3_fret4_isB() {
        // G + 4 = B
        XCTAssertEqual(map.note(string: 3, fret: 4), .b)
    }

    func test_string4_fret2_isE() {
        // D + 2 = E
        XCTAssertEqual(map.note(string: 4, fret: 2), .e)
    }

    func test_string5_fret2_isB() {
        // A + 2 = B
        XCTAssertEqual(map.note(string: 5, fret: 2), .b)
    }

    func test_string5_fret3_isC() {
        // A + 3 = C
        XCTAssertEqual(map.note(string: 5, fret: 3), .c)
    }

    func test_string6_fret5_isA() {
        // E + 5 = A
        XCTAssertEqual(map.note(string: 6, fret: 5), .a)
    }

    func test_string6_fret7_isB() {
        // E + 7 = B
        XCTAssertEqual(map.note(string: 6, fret: 7), .b)
    }

    func test_string6_fret8_isC() {
        // E + 8 = C
        XCTAssertEqual(map.note(string: 6, fret: 8), .c)
    }

    func test_string6_fret12_isE() {
        // Octave
        XCTAssertEqual(map.note(string: 6, fret: 12), .e)
    }

    // MARK: - Chromatic Progression Per String

    /// Verifies that each fret increments the pitch class by exactly one semitone.
    func test_allStrings_chromaticProgression() {
        for string in 1...kStringCount {
            guard let openNote = FretboardMap.standardTuningOpenNotes[string] else {
                XCTFail("No open note for string \(string)")
                continue
            }
            for fret in 0...kMaxFrets {
                let expected = openNote.transposed(by: fret)
                let actual = map.note(string: string, fret: fret)
                XCTAssertEqual(actual, expected,
                    "String \(string) fret \(fret): expected \(expected.sharpName), got \(actual?.sharpName ?? "nil")")
            }
        }
    }

    // MARK: - Octave Invariant

    func test_fret12_alwaysSamePitchClassAsOpenString() {
        for string in 1...kStringCount {
            let openNote = map.note(string: string, fret: 0)
            let fret12Note = map.note(string: string, fret: 12)
            XCTAssertEqual(openNote, fret12Note,
                "String \(string): open and fret-12 should be the same pitch class")
        }
    }

    // MARK: - Out-of-Range Safety

    func test_outOfRange_stringZero_returnsNil() {
        XCTAssertNil(map.note(string: 0, fret: 5))
    }

    func test_outOfRange_string7_returnsNil() {
        XCTAssertNil(map.note(string: 7, fret: 5))
    }

    func test_outOfRange_negativeFret_returnsNil() {
        XCTAssertNil(map.note(string: 1, fret: -1))
    }

    func test_outOfRange_fret25_returnsNil() {
        XCTAssertNil(map.note(string: 1, fret: 25))
    }

    func test_maxFret_24_isValidForAllStrings() {
        for string in 1...kStringCount {
            XCTAssertNotNil(map.note(string: string, fret: 24))
        }
    }

    // MARK: - Map Completeness

    func test_mapContainsAllStrings() {
        XCTAssertEqual(map.map.count, kStringCount)
    }

    func test_mapContainsAllFretsPerString() {
        for (_, fretMap) in map.map {
            // 0 through kMaxFrets inclusive = kMaxFrets + 1 entries
            XCTAssertEqual(fretMap.count, kMaxFrets + 1)
        }
    }

    // MARK: - Positions Lookup

    func test_positions_forNoteA_findsMultiplePositions() {
        let positions = map.positions(for: .a, inFretRange: 0...12)
        // A appears on every string somewhere in frets 0–12
        XCTAssertGreaterThan(positions.count, 0)
    }

    func test_positions_forNoteE_includesOpenStrings1and6() {
        let positions = map.positions(for: .e, inFretRange: 0...0)
        let strings = positions.map(\.string)
        XCTAssertTrue(strings.contains(1), "String 1 open = E")
        XCTAssertTrue(strings.contains(6), "String 6 open = E")
    }

    func test_positions_fretRangeFilter_works() {
        let all = map.positions(for: .c)
        let restricted = map.positions(for: .c, inFretRange: 0...12)
        XCTAssertLessThanOrEqual(restricted.count, all.count)
        XCTAssertTrue(restricted.allSatisfy { $0.fret <= 12 })
    }

    // MARK: - Octave Calculation

    func test_octave_string1_openString_is4() {
        XCTAssertEqual(map.octave(string: 1, fret: 0), 4)
    }

    func test_octave_string6_openString_is2() {
        XCTAssertEqual(map.octave(string: 6, fret: 0), 2)
    }

    func test_octave_string1_fret12_is5() {
        // E4 up one octave = E5
        XCTAssertEqual(map.octave(string: 1, fret: 12), 5)
    }

    // MARK: - Fret Marker Constants

    func test_singleDotFrets_containsCorrectPositions() {
        let expected: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]
        XCTAssertEqual(FretboardMap.singleDotFrets, expected)
    }

    func test_doubleDotFrets_containsCorrectPositions() {
        let expected: Set<Int> = [12, 24]
        XCTAssertEqual(FretboardMap.doubleDotFrets, expected)
    }

    func test_fret12_isInDoubleDotSet_notSingleDotSet() {
        XCTAssertTrue(FretboardMap.doubleDotFrets.contains(12))
        XCTAssertFalse(FretboardMap.singleDotFrets.contains(12))
    }
}
