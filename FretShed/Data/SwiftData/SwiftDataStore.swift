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

// MARK: - Versioned Schema

/// Captures the initial SwiftData schema so future migrations can be applied safely.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Attempt.self,
            Session.self,
            MasteryScore.self,
            UserSettings.self,
            AudioCalibrationProfile.self
        ]
    }
}

// MARK: - Migration Plan

/// Declares the ordered list of schema versions for SwiftData migration.
/// When a future SchemaV2 is added, insert a MigrationStage between V1 and V2 here.
enum FretShedMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []   // No migrations yet — SchemaV1 is the initial (and only) version.
    }
}

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
    // RELEASE: Local-only storage for now — no iCloud container is configured.
    // TODO: Phase 7 — switch to .automatic once iCloud entitlement is added.
    configuration = ModelConfiguration(
        schema: fretMasterSchema,
        isStoredInMemoryOnly: inMemory,
        allowsSave: true,
        cloudKitDatabase: .none
    )
    logger.info("SwiftData: using local storage (RELEASE build)")
    #endif

    return try ModelContainer(
        for: fretMasterSchema,
        migrationPlan: FretShedMigrationPlan.self,
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
