// AppContainer.swift
// FretShed — App Layer
//
// Lightweight dependency injection container.
// All services are created once at app startup and injected via SwiftUI Environment.

import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "AppContainer")

// MARK: - AppContainer

/// Assembles and owns all top-level application dependencies.
///
/// Usage:
/// ```swift
/// @main
/// struct FretShedApp: App {
///     let container = AppContainer()
///     var body: some Scene { ... }
/// }
/// ```
@MainActor
public final class AppContainer {

    // MARK: Infrastructure

    /// The SwiftData model container shared across all repositories.
    public let modelContainer: ModelContainer

    // MARK: Repositories

    public let attemptRepository: any AttemptRepository
    public let sessionRepository: any SessionRepository
    public let masteryRepository: any MasteryRepository
    public let settingsRepository: any SettingsRepository
    public let calibrationRepository: any CalibrationProfileRepository

    // MARK: Domain Services

    /// The pre-computed fretboard map (standard tuning, 0–24 frets).
    public let fretboardMap: FretboardMap

    // MARK: Async Factory

    /// Creates the production dependency graph asynchronously.
    /// ModelContainer creation runs off the main thread so the launch screen
    /// appears immediately instead of blocking for seconds on disk I/O.
    public static func create() async -> AppContainer {
        let mc: ModelContainer
        do {
            mc = try await Task.detached(priority: .userInitiated) {
                try makeModelContainer(inMemory: false)
            }.value
        } catch {
            logger.critical("Failed to create ModelContainer: \(error). Deleting store and retrying.")
            // Delete the corrupted/unmigrated store and start fresh
            Self.deleteExistingStore()
            do {
                mc = try await Task.detached(priority: .userInitiated) {
                    try makeModelContainer(inMemory: false)
                }.value
                logger.info("Successfully created fresh store after migration failure.")
            } catch {
                logger.critical("Fresh store also failed: \(error). Using in-memory fallback.")
                mc = try! makeModelContainer(inMemory: true)
            }
        }
        return AppContainer(modelContainer: mc)
    }

    /// Deletes the default SwiftData store files when migration fails.
    private static func deleteExistingStore() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupport.appendingPathComponent("default.store")
        let suffixes = ["", "-wal", "-shm"]
        for suffix in suffixes {
            let url = storeURL.deletingPathExtension().appendingPathExtension("store\(suffix)")
            try? FileManager.default.removeItem(at: url)
        }
        logger.info("Deleted existing SwiftData store files.")
    }

    // MARK: Initializers

    private init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let sharedContext = modelContainer.mainContext
        self.attemptRepository  = SwiftDataAttemptRepository(context: sharedContext)
        self.sessionRepository  = SwiftDataSessionRepository(context: sharedContext)
        self.masteryRepository  = SwiftDataMasteryRepository(context: sharedContext)
        self.settingsRepository = SwiftDataSettingsRepository(context: sharedContext)
        self.calibrationRepository = SwiftDataCalibrationRepository(context: sharedContext)
        self.fretboardMap = FretboardMap()
        logger.info("AppContainer initialised")
    }

    // MARK: Testing Initializer

    /// Creates an in-memory dependency graph suitable for unit tests and SwiftUI Previews.
    public static func makeForTesting() -> AppContainer {
        AppContainer(testing: true)
    }

    private init(testing: Bool) {
        let container: ModelContainer
        do {
            container = try makeModelContainer(inMemory: true)
        } catch {
            fatalError("Failed to create in-memory test container: \(error)")
        }
        self.modelContainer = container
        let sharedContext = container.mainContext
        self.attemptRepository  = SwiftDataAttemptRepository(context: sharedContext)
        self.sessionRepository  = SwiftDataSessionRepository(context: sharedContext)
        self.masteryRepository  = SwiftDataMasteryRepository(context: sharedContext)
        self.settingsRepository = SwiftDataSettingsRepository(context: sharedContext)
        self.calibrationRepository = SwiftDataCalibrationRepository(context: sharedContext)
        self.fretboardMap = FretboardMap()
    }
}

// MARK: - Environment Key

import SwiftUI

private struct AppContainerKey: EnvironmentKey {
    nonisolated static let defaultValue: AppContainer = {
        MainActor.assumeIsolated { AppContainer.makeForTesting() }
    }()
}

extension EnvironmentValues {
    /// The app-wide dependency container, injected at the root `App` level.
    public var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
