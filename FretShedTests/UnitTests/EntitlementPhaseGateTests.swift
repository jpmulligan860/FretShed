// EntitlementPhaseGateTests.swift
// FretShed — Unit Tests
//
// Tests the phase gate logic on EntitlementManager.

import XCTest
@testable import FretShed

@MainActor
final class EntitlementPhaseGateTests: XCTestCase {

    func test_requiresPremium_foundation_isFree() {
        let em = EntitlementManager()
        // isPremium defaults to false
        XCTAssertFalse(em.requiresPremium(for: .foundation))
    }

    func test_requiresPremium_expansion_isFree() {
        let em = EntitlementManager()
        XCTAssertFalse(em.requiresPremium(for: .expansion))
    }

    func test_requiresPremium_connection_requiresPremium() {
        let em = EntitlementManager()
        XCTAssertTrue(em.requiresPremium(for: .connection))
    }

    func test_requiresPremium_fluency_requiresPremium() {
        let em = EntitlementManager()
        XCTAssertTrue(em.requiresPremium(for: .fluency))
    }
}
