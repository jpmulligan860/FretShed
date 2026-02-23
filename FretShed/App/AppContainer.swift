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
public final class AppContainer: ObservableObject {

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

    // MARK: Initializer

    /// Creates the full production dependency graph.
    public init() {
        // 1. Build the model container (local in DEBUG, CloudKit in RELEASE)
        let container: ModelContainer
        do {
            container = try makeModelContainer(inMemory: false)
        } catch {
            logger.critical("Failed to create ModelContainer: \(error). Using in-memory fallback.")
            // swiftlint:disable:next force_try
            // Safe: in-memory store cannot fail — no disk I/O or CloudKit involved.
            container = try! makeModelContainer(inMemory: true)
        }
        self.modelContainer = container

        // 2. Wire up repositories — use the container's mainContext so that
        //    all repository I/O goes through the SAME context that SwiftUI's
        //    .modelContainer() modifier uses.  Creating a separate
        //    ModelContext(container) causes WAL-level contention with
        //    SwiftUI's auto-save, which can freeze fetch() on iOS 26.
        let sharedContext = container.mainContext
        self.attemptRepository  = SwiftDataAttemptRepository(context: sharedContext)
        self.sessionRepository  = SwiftDataSessionRepository(context: sharedContext)
        self.masteryRepository  = SwiftDataMasteryRepository(context: sharedContext)
        self.settingsRepository = SwiftDataSettingsRepository(context: sharedContext)
        self.calibrationRepository = SwiftDataCalibrationRepository(context: sharedContext)

        // 3. Pre-compute domain objects
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
