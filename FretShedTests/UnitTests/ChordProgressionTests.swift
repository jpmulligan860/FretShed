// ChordProgressionTests.swift
// FretShed — Unit Tests

import XCTest
@testable import FretShed

final class ChordProgressionTests: XCTestCase {

    // MARK: - Tone Selection: selectedTones

    func test_toneSelection_rootOnly_returnsOnlyRoot() {
        let slot = ChordSlot(root: .c, quality: .major)
        let result = slot.selectedTones(for: .rootOnly)
        XCTAssertEqual(result, [.c])
    }

    func test_toneSelection_rootAndThird_returnsRootAndThird_major() {
        let slot = ChordSlot(root: .c, quality: .major)
        let result = slot.selectedTones(for: .rootAndThird)
        // C major: root = C, 3rd = E (4 semitones)
        XCTAssertEqual(result, [.c, .e])
    }

    func test_toneSelection_rootAndThird_returnsRootAndThird_minor() {
        let slot = ChordSlot(root: .a, quality: .minor)
        let result = slot.selectedTones(for: .rootAndThird)
        // A minor: root = A, 3rd = C (3 semitones)
        XCTAssertEqual(result, [.a, .c])
    }

    func test_toneSelection_rootAndFifth_returnsRootAndFifth() {
        let slot = ChordSlot(root: .g, quality: .major)
        let result = slot.selectedTones(for: .rootAndFifth)
        // G major: root = G, 5th = D (7 semitones)
        XCTAssertEqual(result, [.g, .d])
    }

    func test_toneSelection_closeTriad_returnsAllThree() {
        let slot = ChordSlot(root: .c, quality: .major)
        let result = slot.selectedTones(for: .closeTriad)
        // C major: root = C, 3rd = E, 5th = G
        XCTAssertEqual(result, [.c, .e, .g])
    }

    // MARK: - ChordToneSelection Properties

    func test_toneCount_matchesIndicesCount() {
        for selection in ChordToneSelection.allCases {
            XCTAssertEqual(selection.toneCount, selection.toneIndices.count,
                           "\(selection) toneCount should match toneIndices.count")
            XCTAssertEqual(selection.toneCount, selection.toneLabels.count,
                           "\(selection) toneCount should match toneLabels.count")
        }
    }

    // MARK: - Backward Compatibility

    func test_backwardCompat_missingToneSelection_decodesAsCloseTriad() throws {
        // Simulate old JSON that lacks a "toneSelection" key.
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Test",
            "chords": [
                { "id": "00000000-0000-0000-0000-000000000002", "root": 0, "quality": "major" }
            ]
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(ChordProgression.self, from: data)
        XCTAssertEqual(decoded.toneSelection, .closeTriad)
        XCTAssertEqual(decoded.name, "Test")
        XCTAssertEqual(decoded.chords.count, 1)
    }

    // MARK: - Transposition Preserves Tone Selection

    func test_transposed_preservesToneSelection() {
        var progression = ChordProgression(
            name: "Test",
            chords: [ChordSlot(root: .c, quality: .major)],
            toneSelection: .rootAndThird
        )
        let transposed = progression.transposed(toKey: .g)
        XCTAssertEqual(transposed.toneSelection, .rootAndThird)
        XCTAssertEqual(transposed.chords.first?.root, .g)
    }
}
