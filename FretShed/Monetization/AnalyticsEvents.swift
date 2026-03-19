import Foundation

/// Analytics event definitions for TelemetryDeck integration.
///
/// TelemetryDeck is a privacy-focused analytics SDK — no personal data is collected.
/// All events use signal names (strings) rather than structured payloads.
///
/// **Setup instructions** (when ready to integrate):
/// 1. Create a TelemetryDeck account at https://dashboard.telemetrydeck.com
/// 2. Create an app and copy the App ID
/// 3. In Xcode: File > Add Package Dependencies > `https://github.com/TelemetryDeck/SwiftSDK`
/// 4. In FretShedApp.swift, add: `TelemetryDeck.initialize(config: .init(appID: "YOUR-APP-ID"))`
/// 5. Send events with: `TelemetryDeck.signal(AnalyticsEvent.sessionStarted)`
enum AnalyticsEvent {

    // MARK: - Quiz / Practice

    /// User starts a quiz session. Include focus mode and game mode as parameters.
    static let sessionStarted = "session.started"

    /// User completes a quiz session (reaches session length or ends early).
    static let sessionCompleted = "session.completed"

    /// User taps "Repeat" on the session summary screen.
    static let sessionRepeated = "session.repeated"

    // MARK: - Calibration

    /// User begins the audio calibration flow.
    static let calibrationStarted = "calibration.started"

    /// User completes calibration successfully.
    static let calibrationCompleted = "calibration.completed"

    /// User chose tap mode instead of calibration (from gate alert).
    static let tapModeSelected = "calibration.tapModeSelected"

    // MARK: - Paywall

    /// Paywall screen was shown to the user.
    static let paywallShown = "paywall.shown"

    /// User tapped a subscription option (monthly, annual, or lifetime).
    static let paywallSubscribeTapped = "paywall.subscribeTapped"

    /// User successfully completed a purchase.
    static let subscriptionStarted = "subscription.started"

    /// User tapped "Restore Purchases."
    static let restoreTapped = "paywall.restoreTapped"

    // MARK: - Onboarding

    /// User completed the onboarding flow.
    static let onboardingCompleted = "onboarding.completed"

    /// User skipped onboarding.
    static let onboardingSkipped = "onboarding.skipped"

    // MARK: - Spacing Gate & Warmup

    /// A note advanced a spacing checkpoint (1, 2, or 3).
    /// Parameter: checkpoint number.
    static let masteryCheckpointReached = "mastery.checkpointReached"

    /// A note's spacing checkpoints were reset due to an incorrect answer.
    static let masteryCheckpointReset = "mastery.checkpointReset"

    /// A warmup review block was shown at the start of a session.
    /// Parameter: number of warmup notes.
    static let warmupBlockShown = "warmup.blockShown"

    // MARK: - Backup/Restore

    /// User exported a data backup.
    static let backupExported = "data.backupExported"

    /// User restored data from a backup.
    static let backupRestored = "data.backupRestored"
}
