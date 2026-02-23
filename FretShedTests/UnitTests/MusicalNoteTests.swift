// MusicalNoteTests.swift
// FretShed — Unit Tests

import XCTest
@testable import FretShed

final class MusicalNoteTests: XCTestCase {

    // MARK: - Raw Values

    func test_rawValues_areCorrect() {
        XCTAssertEqual(MusicalNote.c.rawValue,      0)
        XCTAssertEqual(MusicalNote.cSharp.rawValue, 1)
        XCTAssertEqual(MusicalNote.d.rawValue,      2)
        XCTAssertEqual(MusicalNote.dSharp.rawValue, 3)
        XCTAssertEqual(MusicalNote.e.rawValue,      4)
        XCTAssertEqual(MusicalNote.f.rawValue,      5)
        XCTAssertEqual(MusicalNote.fSharp.rawValue, 6)
        XCTAssertEqual(MusicalNote.g.rawValue,      7)
        XCTAssertEqual(MusicalNote.gSharp.rawValue, 8)
        XCTAssertEqual(MusicalNote.a.rawValue,      9)
        XCTAssertEqual(MusicalNote.aSharp.rawValue, 10)
        XCTAssertEqual(MusicalNote.b.rawValue,      11)
    }

    func test_allCases_hasExactly12Notes() {
        XCTAssertEqual(MusicalNote.allCases.count, 12)
    }

    // MARK: - Display Names

    func test_sharpNames() {
        XCTAssertEqual(MusicalNote.c.sharpName,      "C")
        XCTAssertEqual(MusicalNote.cSharp.sharpName, "C#")
        XCTAssertEqual(MusicalNote.d.sharpName,      "D")
        XCTAssertEqual(MusicalNote.dSharp.sharpName, "D#")
        XCTAssertEqual(MusicalNote.e.sharpName,      "E")
        XCTAssertEqual(MusicalNote.f.sharpName,      "F")
        XCTAssertEqual(MusicalNote.fSharp.sharpName, "F#")
        XCTAssertEqual(MusicalNote.g.sharpName,      "G")
        XCTAssertEqual(MusicalNote.gSharp.sharpName, "G#")
        XCTAssertEqual(MusicalNote.a.sharpName,      "A")
        XCTAssertEqual(MusicalNote.aSharp.sharpName, "A#")
        XCTAssertEqual(MusicalNote.b.sharpName,      "B")
    }

    func test_flatNames() {
        XCTAssertEqual(MusicalNote.c.flatName,      "C")
        XCTAssertEqual(MusicalNote.cSharp.flatName, "Db")
        XCTAssertEqual(MusicalNote.d.flatName,      "D")
        XCTAssertEqual(MusicalNote.dSharp.flatName, "Eb")
        XCTAssertEqual(MusicalNote.e.flatName,      "E")
        XCTAssertEqual(MusicalNote.f.flatName,      "F")
        XCTAssertEqual(MusicalNote.fSharp.flatName, "Gb")
        XCTAssertEqual(MusicalNote.g.flatName,      "G")
        XCTAssertEqual(MusicalNote.gSharp.flatName, "Ab")
        XCTAssertEqual(MusicalNote.a.flatName,      "A")
        XCTAssertEqual(MusicalNote.aSharp.flatName, "Bb")
        XCTAssertEqual(MusicalNote.b.flatName,      "B")
    }

    func test_displayName_sharpsFormat() {
        XCTAssertEqual(MusicalNote.cSharp.displayName(format: .sharps), "C#")
    }

    func test_displayName_flatsFormat() {
        XCTAssertEqual(MusicalNote.cSharp.displayName(format: .flats), "Db")
    }

    func test_displayName_bothFormat_forAccidental() {
        XCTAssertEqual(MusicalNote.cSharp.displayName(format: .both), "C#/Db")
    }

    func test_displayName_bothFormat_forNatural() {
        XCTAssertEqual(MusicalNote.c.displayName(format: .both), "C")
    }

    // MARK: - Natural Notes

    func test_naturalNotes_areCorrect() {
        let naturals: [MusicalNote] = [.c, .d, .e, .f, .g, .a, .b]
        for note in naturals {
            XCTAssertTrue(note.isNatural, "\(note.sharpName) should be natural")
        }
        let accidentals: [MusicalNote] = [.cSharp, .dSharp, .fSharp, .gSharp, .aSharp]
        for note in accidentals {
            XCTAssertFalse(note.isNatural, "\(note.sharpName) should NOT be natural")
        }
    }

    // MARK: - Transposition

    func test_transposed_upOneSemitone() {
        XCTAssertEqual(MusicalNote.c.transposed(by: 1),  .cSharp)
        XCTAssertEqual(MusicalNote.b.transposed(by: 1),  .c)       // wraps
        XCTAssertEqual(MusicalNote.a.transposed(by: 3),  .c)
    }

    func test_transposed_downOneSemitone() {
        XCTAssertEqual(MusicalNote.c.transposed(by: -1), .b)        // wraps down
        XCTAssertEqual(MusicalNote.d.transposed(by: -2), .c)
    }

    func test_transposed_byOctave_returnsSameNote() {
        for note in MusicalNote.allCases {
            XCTAssertEqual(note.transposed(by: 12), note)
            XCTAssertEqual(note.transposed(by: -12), note)
        }
    }

    func test_transposed_byZero_returnsSelf() {
        for note in MusicalNote.allCases {
            XCTAssertEqual(note.transposed(by: 0), note)
        }
    }

    // MARK: - Circle of Fourths

    func test_circleOfFourths_hasAllTwelveNotes() {
        XCTAssertEqual(MusicalNote.circleOfFourths.count, 12)
        XCTAssertEqual(Set(MusicalNote.circleOfFourths), Set(MusicalNote.allCases))
    }

    func test_circleOfFourths_startsOnC() {
        XCTAssertEqual(MusicalNote.circleOfFourths.first, .c)
    }

    func test_circleOfFourths_secondNoteIsF() {
        // C → F is a perfect fourth (5 semitones)
        XCTAssertEqual(MusicalNote.circleOfFourths[1], .f)
    }

    func test_circleOfFourths_fullSequence() {
        // C F Bb Eb Ab Db Gb B E A D G
        let expected: [MusicalNote] = [.c, .f, .aSharp, .dSharp, .gSharp, .cSharp, .fSharp, .b, .e, .a, .d, .g]
        XCTAssertEqual(MusicalNote.circleOfFourths, expected)
    }

    func test_circleOfFourths_consecutive_intervals_arePerfectFourths() {
        let circle = MusicalNote.circleOfFourths
        for i in 0..<(circle.count - 1) {
            let interval = (circle[i + 1].rawValue - circle[i].rawValue + 12) % 12
            XCTAssertEqual(interval, 5, "\(circle[i].sharpName) → \(circle[i+1].sharpName) should be a 4th")
        }
    }

    // MARK: - Circle of Fifths

    func test_circleOfFifths_hasAllTwelveNotes() {
        XCTAssertEqual(MusicalNote.circleOfFifths.count, 12)
        XCTAssertEqual(Set(MusicalNote.circleOfFifths), Set(MusicalNote.allCases))
    }

    func test_circleOfFifths_startsOnC() {
        XCTAssertEqual(MusicalNote.circleOfFifths.first, .c)
    }

    func test_circleOfFifths_secondNoteIsG() {
        // C → G is a perfect fifth (7 semitones)
        XCTAssertEqual(MusicalNote.circleOfFifths[1], .g)
    }

    func test_circleOfFifths_fullSequence() {
        // C G D A E B F# C# Ab Eb Bb F
        let expected: [MusicalNote] = [.c, .g, .d, .a, .e, .b, .fSharp, .cSharp, .gSharp, .dSharp, .aSharp, .f]
        XCTAssertEqual(MusicalNote.circleOfFifths, expected)
    }

    func test_circleOfFifths_consecutive_intervals_arePerfectFifths() {
        let circle = MusicalNote.circleOfFifths
        for i in 0..<(circle.count - 1) {
            let interval = (circle[i + 1].rawValue - circle[i].rawValue + 12) % 12
            XCTAssertEqual(interval, 7, "\(circle[i].sharpName) → \(circle[i+1].sharpName) should be a 5th")
        }
    }

    // MARK: - Next In Circle

    func test_nextInCircleOfFourths_fromC_isF() {
        XCTAssertEqual(MusicalNote.c.nextInCircleOfFourths, .f)
    }

    func test_nextInCircleOfFifths_fromC_isG() {
        XCTAssertEqual(MusicalNote.c.nextInCircleOfFifths, .g)
    }

    // MARK: - Enharmonic Equivalents

    func test_enharmonicEquivalents_areEqual() {
        XCTAssertTrue(MusicalNote.cSharp.isEnharmonic(with: .cSharp))
        // C# and Db are the same pitch class (both rawValue == 1)
        XCTAssertTrue(MusicalNote.cSharp.isEnharmonic(with: .cSharp))
    }

    func test_differentNotes_areNotEnharmonic() {
        XCTAssertFalse(MusicalNote.c.isEnharmonic(with: .cSharp))
    }

    func test_sameNote_isAlwaysEnharmonicWithItself() {
        for note in MusicalNote.allCases {
            XCTAssertTrue(note.isEnharmonic(with: note))
        }
    }

    // MARK: - Codable

    func test_musicalNote_encodesAndDecodes() throws {
        for note in MusicalNote.allCases {
            let data = try JSONEncoder().encode(note)
            let decoded = try JSONDecoder().decode(MusicalNote.self, from: data)
            XCTAssertEqual(note, decoded)
        }
    }

    // MARK: - Circle Cycling Tests (matches CircleCyclingTests requirement)

    func test_circleOfFourths_cycles_wraps_after12() {
        var note = MusicalNote.c
        for _ in 0..<12 {
            note = note.nextInCircleOfFourths
        }
        // After 12 fourths we complete the cycle and return to C
        XCTAssertEqual(note, .c)
    }

    func test_circleOfFifths_cycles_wraps_after12() {
        var note = MusicalNote.c
        for _ in 0..<12 {
            note = note.nextInCircleOfFifths
        }
        XCTAssertEqual(note, .c)
    }
}
