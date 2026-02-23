// SwiftDataStore.swift
// FretShed — Data Layer
//
// Configures the SwiftData ModelContainer.
// In DEBUG / Simulator builds, uses local storage only.
// In RELEASE builds with a provisioning profile, CloudKit sync is enabled.
//
// HOW TO ENABLE iCLOUD SYNC (future step):
//   1. Sign up for Apple Developer Program ($99/yr at developer.apple.com)
//   2. In Xcode → Project → Signing & Capabilities, add "iCloud" and create
//      a container named "iCloud.com.jpm.fretshed"
//   3. Remove the `#if DEBUG` guard below

import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "SwiftDataStore")

/// All SwiftData model types registered in the schema.
let fretMasterSchema = Schema([
    Attempt.self,
    Session.self,
    MasteryScore.self,
    UserSettings.self,
    AudioCalibrationProfile.self
])

// MARK: - ModelContainer Factory

/// Builds the app's `ModelContainer` with the correct configuration for the current build.
///
/// - Parameter inMemory: When `true`, uses an in-memory store (useful for unit tests and
///   SwiftUI previews). When `false`, data is persisted to disk.
/// - Returns: A fully configured `ModelContainer`.
public func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
    let configuration: ModelConfiguration

    #if DEBUG
    // Local-only storage — no iCloud account or provisioning profile required.
    configuration = ModelConfiguration(
        schema: fretMasterSchema,
        isStoredInMemoryOnly: inMemory,
        allowsSave: true
    )
    logger.debug("SwiftData: using LOCAL storage (DEBUG build)")
    #else
    // RELEASE: CloudKit sync enabled.
    // Requires an Apple Developer account and the iCloud entitlement.
    // TODO: Phase 7 — confirm iCloud container name matches provisioning profile.
    configuration = ModelConfiguration(
        schema: fretMasterSchema,
        isStoredInMemoryOnly: inMemory,
        allowsSave: true,
        cloudKitDatabase: .automatic
    )
    logger.info("SwiftData: using CloudKit-synced storage (RELEASE build)")
    #endif

    return try ModelContainer(
        for: fretMasterSchema,
        configurations: [configuration]
    )
}

// MARK: - Preview / Test Container

/// A convenience in-memory container for SwiftUI Previews and XCTest.
@MainActor
public let previewContainer: ModelContainer = {
    do {
        return try makeModelContainer(inMemory: true)
    } catch {
        fatalError("Failed to create in-memory preview container: \(error)")
    }
}()
