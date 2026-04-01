import Foundation
import UserNotifications

@MainActor
@Observable
final class NotificationService {

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Notification Identifiers

    private enum Identifier {
        static let morning = "com.sleepandcode.notification.morning"
        static let evening = "com.sleepandcode.notification.evening"
        static let weekly = "com.sleepandcode.notification.weekly"
    }

    private enum Category {
        static let morning = "MORNING_SLEEP_REPORT"
        static let evening = "EVENING_STREAK"
        static let weekly = "WEEKLY_SUMMARY"
    }

    private enum DefaultsKey {
        static let isEnabled = "notifications_enabled"
        static let morningEnabled = "notifications_morning_enabled"
        static let eveningEnabled = "notifications_evening_enabled"
        static let weeklyEnabled = "notifications_weekly_enabled"
    }

    // MARK: - Properties

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: DefaultsKey.isEnabled) }
    }

    var morningEnabled: Bool {
        didSet { UserDefaults.standard.set(morningEnabled, forKey: DefaultsKey.morningEnabled) }
    }

    var eveningEnabled: Bool {
        didSet { UserDefaults.standard.set(eveningEnabled, forKey: DefaultsKey.eveningEnabled) }
    }

    var weeklyEnabled: Bool {
        didSet { UserDefaults.standard.set(weeklyEnabled, forKey: DefaultsKey.weeklyEnabled) }
    }

    // MARK: - Private

    private let center = UNUserNotificationCenter.current()

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.bool(forKey: DefaultsKey.isEnabled)
        self.morningEnabled = defaults.bool(forKey: DefaultsKey.morningEnabled)
        self.eveningEnabled = defaults.bool(forKey: DefaultsKey.eveningEnabled)
        self.weeklyEnabled = defaults.bool(forKey: DefaultsKey.weeklyEnabled)

        registerCategories()
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isEnabled = granted
            return granted
        } catch {
            isEnabled = false
            return false
        }
    }

    // MARK: - Morning Notification (8:30 AM)

    func scheduleMorningNotification(sleepScore: Int) {
        guard isEnabled, morningEnabled else { return }

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.morning
        content.sound = .default

        if sleepScore < 65 {
            content.title = "Rough Night"
            content.body = "Rough night (\(sleepScore)). Consider easier tasks today."
        } else if sleepScore > 85 {
            content.title = "Great Sleep!"
            content.body = "Great sleep last night (\(sleepScore))! Time to crush it."
        } else {
            content.title = "Sleep Report"
            content.body = "Sleep score: \(sleepScore). Have a productive day!"
        }

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: Identifier.morning,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Evening Notification (9:00 PM)

    func scheduleEveningNotification(streakDays: Int, avgScore: Double) {
        guard isEnabled, eveningEnabled else { return }
        guard streakDays >= 3 else { return }

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.evening
        content.sound = .default
        content.title = "Sleep Streak"
        content.body = "\(streakDays)-day streak of 80+ sleep. Keep it going!"

        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: Identifier.evening,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Weekly Notification (Sunday 10:00 AM)

    func scheduleWeeklyNotification(
        avgSleep: Double,
        totalCommits: Int,
        bestDay: String,
        bestDayHours: Double
    ) {
        guard isEnabled, weeklyEnabled else { return }

        let formattedAvgSleep = String(format: "%.1f", avgSleep)
        let formattedHours = String(format: "%.1f", bestDayHours)

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.weekly
        content.sound = .default
        content.title = "Weekly Summary"
        content.body = "Avg sleep \(formattedAvgSleep), \(totalCommits) commits this week. Best day: \(bestDay) after \(formattedHours) hours."

        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Identifier.weekly,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Cancel All

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Private Helpers

    private func registerCategories() {
        let morningCategory = UNNotificationCategory(
            identifier: Category.morning,
            actions: [],
            intentIdentifiers: []
        )

        let eveningCategory = UNNotificationCategory(
            identifier: Category.evening,
            actions: [],
            intentIdentifiers: []
        )

        let weeklyCategory = UNNotificationCategory(
            identifier: Category.weekly,
            actions: [],
            intentIdentifiers: []
        )

        center.setNotificationCategories([morningCategory, eveningCategory, weeklyCategory])
    }
}
