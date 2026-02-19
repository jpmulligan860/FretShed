// NotificationScheduler.swift
// FretMaster — App Layer
//
// Manages UNUserNotificationCenter authorization and scheduling for
// practice reminders and streak reminders. Called whenever the user
// changes notification preferences in SettingsView.
//
// All public methods are nonisolated so they can be called from any context,
// but they dispatch async work through UNUserNotificationCenter which
// handles its own thread safety.

import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretmaster", category: "NotificationScheduler")

// MARK: - NotificationSnapshot

/// A `Sendable` value-type snapshot of the notification-relevant fields from
/// `UserSettings`. Created on the `@MainActor` before crossing into a `Task`,
/// so the `@Model` object is never accessed from a background executor.
private struct NotificationSnapshot: Sendable {
    let practiceReminderEnabled: Bool
    let practiceReminderHour: Int
    let practiceReminderMinute: Int
    let streakReminderEnabled: Bool

    init(settings: UserSettings) {
        self.practiceReminderEnabled = settings.practiceReminderEnabled
        self.practiceReminderHour    = settings.practiceReminderHour
        self.practiceReminderMinute  = settings.practiceReminderMinute
        self.streakReminderEnabled   = settings.streakReminderEnabled
    }
}

private enum NotificationID {
    static let practiceReminder = "com.jpm.fretmaster.reminder.practice"
    static let streakReminder   = "com.jpm.fretmaster.reminder.streak"
}

// MARK: - NotificationScheduler

public final class NotificationScheduler: Sendable {

    public static let shared = NotificationScheduler()
    private init() {}

    // MARK: - Public API

    /// Requests authorization if needed, then syncs all scheduled notifications
    /// to match the current `UserSettings`. Safe to call every time settings change.
    ///
    /// All values are snapshotted from `settings` on the calling actor before any
    /// async work begins, so the `@Model` object is never accessed across actors.
    public func sync(settings: UserSettings) {
        // Snapshot every value we need as plain Sendable types right here,
        // on whatever actor the caller is running on (typically @MainActor).
        // The Task below captures only these value types — never `settings` itself.
        let snapshot = NotificationSnapshot(settings: settings)
        Task {
            let granted = await requestAuthorizationIfNeeded()
            guard granted else {
                await cancelAll()
                logger.info("Notification permission denied — cleared all pending notifications")
                return
            }
            await schedulePracticeReminder(snapshot: snapshot)
            await scheduleStreakReminder(snapshot: snapshot)
        }
    }

    /// Cancels every FretMaster notification. Call on sign-out or data reset.
    public func cancelAll() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [
                NotificationID.practiceReminder,
                NotificationID.streakReminder
            ])
        logger.info("Cancelled all FretMaster notifications")
    }

    // MARK: - Authorization

    private func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                logger.info("Notification authorization result: \(granted)")
                return granted
            } catch {
                logger.error("Notification authorization error: \(error)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Practice Reminder

    private func schedulePracticeReminder(snapshot: NotificationSnapshot) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.practiceReminder])

        guard snapshot.practiceReminderEnabled else {
            logger.debug("Practice reminder disabled — removed")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Time to Practice 🎸"
        content.body = "Keep your streak going — open FretMaster and play a few notes."
        content.sound = .default

        var components = DateComponents()
        components.hour   = snapshot.practiceReminderHour
        components.minute = snapshot.practiceReminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationID.practiceReminder,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            logger.info("Scheduled practice reminder at \(snapshot.practiceReminderHour):\(String(format: "%02d", snapshot.practiceReminderMinute))")
        } catch {
            logger.error("Failed to schedule practice reminder: \(error)")
        }
    }

    // MARK: - Streak Reminder

    private func scheduleStreakReminder(snapshot: NotificationSnapshot) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.streakReminder])

        guard snapshot.streakReminderEnabled else {
            logger.debug("Streak reminder disabled — removed")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak! 🔥"
        content.body = "You haven't practiced today. A quick session keeps your mastery growing."
        content.sound = .default

        // Fire at 8 PM if no practice has occurred — a reasonable evening nudge.
        var components = DateComponents()
        components.hour   = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationID.streakReminder,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            logger.info("Scheduled streak reminder at 20:00 daily")
        } catch {
            logger.error("Failed to schedule streak reminder: \(error)")
        }
    }
}
