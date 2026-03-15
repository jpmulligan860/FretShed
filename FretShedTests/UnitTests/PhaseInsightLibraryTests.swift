// PhaseInsightLibraryTests.swift
// FretShedTests

import XCTest
@testable import FretShed

final class PhaseInsightLibraryTests: XCTestCase {

    // MARK: - Phrase Selection

    func test_phraseSelection_cyclesThroughPool() {
        let pool = ["A", "B", "C"]
        XCTAssertEqual(PhaseInsightLibrary.phrase(from: pool, sessionCount: 0), "A")
        XCTAssertEqual(PhaseInsightLibrary.phrase(from: pool, sessionCount: 1), "B")
        XCTAssertEqual(PhaseInsightLibrary.phrase(from: pool, sessionCount: 2), "C")
        XCTAssertEqual(PhaseInsightLibrary.phrase(from: pool, sessionCount: 3), "A") // wraps
    }

    func test_phraseSelection_emptyPool_returnsEmpty() {
        XCTAssertEqual(PhaseInsightLibrary.phrase(from: [], sessionCount: 5), "")
    }

    // MARK: - Variable Substitution

    func test_substitute_replacesVariables() {
        let result = PhaseInsightLibrary.substitute(
            "{note} on the {string_name} string is yours.",
            variables: ["note": "C", "string_name": "A"]
        )
        XCTAssertEqual(result, "C on the A string is yours.")
    }

    func test_substitute_multipleOccurrences() {
        let result = PhaseInsightLibrary.substitute(
            "{note} and {note} again",
            variables: ["note": "D"]
        )
        XCTAssertEqual(result, "D and D again")
    }

    func test_substitute_unknownVariable_leftAsIs() {
        let result = PhaseInsightLibrary.substitute(
            "{note} on {unknown}",
            variables: ["note": "E"]
        )
        XCTAssertEqual(result, "E on {unknown}")
    }

    // MARK: - Phase Templates Exist

    func test_foundationTemplates_notEmpty() {
        XCTAssertFalse(PhaseInsightLibrary.foundationMusicalContext.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.foundationPerformance.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.foundationProximity.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.foundationComeback.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.foundationEncouragement.isEmpty)
    }

    func test_connectionTemplates_notEmpty() {
        XCTAssertFalse(PhaseInsightLibrary.connectionMusicalContext.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.connectionPerformance.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.connectionProximity.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.connectionComeback.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.connectionEncouragement.isEmpty)
    }

    func test_expansionTemplates_notEmpty() {
        XCTAssertFalse(PhaseInsightLibrary.expansionMusicalContext.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.expansionPerformance.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.expansionProximity.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.expansionComeback.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.expansionEncouragement.isEmpty)
    }

    func test_fluencyTemplates_notEmpty() {
        XCTAssertFalse(PhaseInsightLibrary.fluencyMusicalContext.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.fluencyPerformance.isEmpty)
        XCTAssertFalse(PhaseInsightLibrary.fluencyEncouragement.isEmpty)
    }

    // MARK: - Banned Vocabulary

    func test_noBannedVocabulary() {
        let banned = ["dropped", "regressed", "back to", "lost"]
        let allPools: [[String]] = [
            PhaseInsightLibrary.foundationMusicalContext,
            PhaseInsightLibrary.foundationPerformance,
            PhaseInsightLibrary.foundationProximity,
            PhaseInsightLibrary.foundationComeback,
            PhaseInsightLibrary.foundationEncouragement,
            PhaseInsightLibrary.connectionMusicalContext,
            PhaseInsightLibrary.connectionPerformance,
            PhaseInsightLibrary.connectionProximity,
            PhaseInsightLibrary.connectionComeback,
            PhaseInsightLibrary.connectionEncouragement,
            PhaseInsightLibrary.expansionMusicalContext,
            PhaseInsightLibrary.expansionPerformance,
            PhaseInsightLibrary.expansionProximity,
            PhaseInsightLibrary.expansionComeback,
            PhaseInsightLibrary.expansionEncouragement,
            PhaseInsightLibrary.fluencyMusicalContext,
            PhaseInsightLibrary.fluencyPerformance,
            PhaseInsightLibrary.fluencyEncouragement,
            PhaseInsightLibrary.stringCompletionMessages,
            PhaseInsightLibrary.reviewSessionMessages,
        ]

        for pool in allPools {
            for phrase in pool {
                let lower = phrase.lowercased()
                for word in banned {
                    XCTAssertFalse(lower.contains(word),
                                   "Banned word '\(word)' found in: \(phrase)")
                }
            }
        }
    }

    // MARK: - Advancement Messages

    func test_advancementMessage_connection() {
        let msg = PhaseInsightLibrary.advancementMessage(to: .connection, sessionCount: 0)
        XCTAssertNotNil(msg)
        XCTAssertTrue(msg!.contains("Phase") || msg!.contains("Foundation") || msg!.contains("cross-string"))
    }

    func test_advancementMessage_expansion() {
        let msg = PhaseInsightLibrary.advancementMessage(to: .expansion, sessionCount: 1)
        XCTAssertNotNil(msg)
    }

    func test_advancementMessage_fluency() {
        let msg = PhaseInsightLibrary.advancementMessage(to: .fluency, sessionCount: 2)
        XCTAssertNotNil(msg)
    }

    func test_advancementMessage_foundation_returnsNil() {
        // Foundation has no advancement message (it's the starting phase)
        let msg = PhaseInsightLibrary.advancementMessage(to: .foundation, sessionCount: 0)
        XCTAssertNil(msg)
    }

    // MARK: - Musical Context Message

    func test_musicalContextMessage_scaleFragment() {
        let context = NoteGroupContext(
            groupType: .scaleFragment,
            description: "C major scale fragment on the A string",
            key: "C major",
            musicalName: "C Major Scale",
            intervalNames: ["Root", "2nd", "3rd"]
        )
        let msg = PhaseInsightLibrary.musicalContextMessage(
            from: context,
            noteNames: ["C", "D", "E"],
            sessionCount: 0,
            stringName: "A"
        )
        XCTAssertFalse(msg.isEmpty)
        XCTAssertFalse(msg.contains("{string_name}"), "string_name placeholder should be substituted")
    }

    func test_musicalContextMessage_triad() {
        let context = NoteGroupContext(
            groupType: .triad,
            description: "C major triad",
            key: "C",
            musicalName: "C Major",
            intervalNames: ["Root", "Major 3rd", "Perfect 5th"]
        )
        let msg = PhaseInsightLibrary.musicalContextMessage(
            from: context,
            noteNames: ["C", "E", "G"],
            sessionCount: 3
        )
        XCTAssertFalse(msg.isEmpty)
    }

    // MARK: - Template Uniqueness Within Week

    func test_noDuplicatesWithin7Days() {
        // With 5+ templates per pool, 7 sessions should produce at least 5 unique messages
        let pool = PhaseInsightLibrary.foundationMusicalContext
        var messages: Set<String> = []
        for i in 0..<min(7, pool.count) {
            messages.insert(PhaseInsightLibrary.phrase(from: pool, sessionCount: i))
        }
        XCTAssertEqual(messages.count, min(7, pool.count),
                       "Expected unique messages for each of \(min(7, pool.count)) sessions")
    }

    // MARK: - String Completion Messages

    func test_stringCompletionMessages_notEmpty() {
        XCTAssertFalse(PhaseInsightLibrary.stringCompletionMessages.isEmpty)
    }

    func test_reviewSessionMessages_notEmpty() {
        XCTAssertFalse(PhaseInsightLibrary.reviewSessionMessages.isEmpty)
    }

    // MARK: - Phase Advancement Messages Cover All Advance Targets

    func test_advancementMessages_coverConnectionExpansionFluency() {
        XCTAssertNotNil(PhaseInsightLibrary.phaseAdvancementMessages[.connection])
        XCTAssertNotNil(PhaseInsightLibrary.phaseAdvancementMessages[.expansion])
        XCTAssertNotNil(PhaseInsightLibrary.phaseAdvancementMessages[.fluency])
        // Foundation has no advancement message — you don't "advance to" foundation
        XCTAssertNil(PhaseInsightLibrary.phaseAdvancementMessages[.foundation])
    }
}
