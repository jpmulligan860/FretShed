// CalibrationRepositoryTests.swift
// FretShedTests
//
// Tests for calibration profile CRUD mutations:
// rename, trim updates, set active, delete with promotion.

import XCTest
import SwiftData
@testable import FretShed

@MainActor
final class CalibrationRepositoryTests: XCTestCase {

    var container: AppContainer!
    var repo: CalibrationProfileRepository!

    override func setUp() async throws {
        try await super.setUp()
        container = AppContainer.makeForTesting()
        repo = container.calibrationRepository
    }

    override func tearDown() async throws {
        container = nil
        repo = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeProfile(name: String, isActive: Bool = false) -> AudioCalibrationProfile {
        let p = AudioCalibrationProfile(
            inputSource: .builtInMic,
            measuredNoiseFloorRMS: 0.02,
            measuredAGCGain: 3.0,
            signalQualityScore: 0.8,
            stringResults: [:],
            frettedStringResults: [:]
        )
        p.name = name
        p.isActive = isActive
        return p
    }

    // MARK: - Save & Fetch

    func test_saveNewProfile_fetchesBack() throws {
        let profile = makeProfile(name: "Strat", isActive: true)
        try repo.save(profile)

        let all = try repo.allProfiles()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].name, "Strat")
        XCTAssertTrue(all[0].isActive)
    }

    // MARK: - Rename

    func test_renameProfile_persistsAfterSave() throws {
        let profile = makeProfile(name: "Strat", isActive: true)
        try repo.save(profile)

        // Mutate and save (same object, already tracked)
        profile.name = "Telecaster"
        try repo.save(profile)

        let all = try repo.allProfiles()
        XCTAssertEqual(all.count, 1, "Should still be 1 profile, not a duplicate")
        XCTAssertEqual(all[0].name, "Telecaster")
    }

    // MARK: - Trim Updates

    func test_updateTrimValues_persists() throws {
        let profile = makeProfile(name: "Les Paul", isActive: true)
        try repo.save(profile)

        profile.userGainTrimDB = 3.5
        profile.userGateTrimDB = -2.0
        try repo.save(profile)

        let all = try repo.allProfiles()
        XCTAssertEqual(all[0].userGainTrimDB, 3.5, accuracy: 0.01)
        XCTAssertEqual(all[0].userGateTrimDB, -2.0, accuracy: 0.01)
    }

    // MARK: - Set Active

    func test_setActive_togglesBetweenProfiles() throws {
        let strat = makeProfile(name: "Strat", isActive: true)
        let lp = makeProfile(name: "Les Paul", isActive: false)
        try repo.save(strat)
        try repo.save(lp)

        // Switch active to Les Paul
        try repo.setActive(lp)

        let all = try repo.allProfiles()
        let activeCount = all.filter(\.isActive).count
        XCTAssertEqual(activeCount, 1, "Exactly one profile should be active")

        let active = try repo.activeProfile()
        XCTAssertEqual(active?.name, "Les Paul")
    }

    func test_setActive_clearsOtherProfiles() throws {
        let p1 = makeProfile(name: "P1", isActive: true)
        let p2 = makeProfile(name: "P2", isActive: false)
        let p3 = makeProfile(name: "P3", isActive: false)
        try repo.save(p1)
        try repo.save(p2)
        try repo.save(p3)

        try repo.setActive(p3)

        let all = try repo.allProfiles()
        for p in all {
            if p.name == "P3" {
                XCTAssertTrue(p.isActive)
            } else {
                XCTAssertFalse(p.isActive, "\(p.name ?? "nil") should not be active")
            }
        }
    }

    // MARK: - Delete

    func test_deleteInactiveProfile_keepsActive() throws {
        let strat = makeProfile(name: "Strat", isActive: true)
        let lp = makeProfile(name: "Les Paul", isActive: false)
        try repo.save(strat)
        try repo.save(lp)

        try repo.delete(lp)

        let all = try repo.allProfiles()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].name, "Strat")
        XCTAssertTrue(all[0].isActive)
    }

    func test_deleteActiveProfile_promotesNext() throws {
        let strat = makeProfile(name: "Strat", isActive: true)
        let lp = makeProfile(name: "Les Paul", isActive: false)
        try repo.save(strat)
        try repo.save(lp)

        try repo.delete(strat)

        let all = try repo.allProfiles()
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all[0].isActive, "Remaining profile should be promoted to active")
    }

    func test_deleteLastProfile_clearsCalibrationFlag() throws {
        let strat = makeProfile(name: "Strat", isActive: true)
        try repo.save(strat)
        UserDefaults.standard.set(true, forKey: LocalUserPreferences.Key.hasCompletedCalibration)

        try repo.delete(strat)

        let all = try repo.allProfiles()
        XCTAssertEqual(all.count, 0)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: LocalUserPreferences.Key.hasCompletedCalibration))
    }

    // MARK: - Fallback Active Profile

    func test_activeProfile_fallbackPromotion() throws {
        // Save a profile without isActive set
        let profile = makeProfile(name: "Unnamed", isActive: false)
        try repo.save(profile)

        // activeProfile() should promote the most recent
        let active = try repo.activeProfile()
        XCTAssertNotNil(active)
        XCTAssertTrue(active?.isActive ?? false)
    }

    func test_activeProfile_noProfiles_returnsNil() throws {
        let active = try repo.activeProfile()
        XCTAssertNil(active)
    }
}
