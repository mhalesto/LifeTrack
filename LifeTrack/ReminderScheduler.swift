//
//  ReminderScheduler.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let identifierPrefix = "lifetrack.task."
    static let actionTipDidBecomePendingNotification = Notification.Name("LifeTrack.ReminderScheduler.actionTipDidBecomePending")
    static let categoryIdentifier = "LIFETRACK_TASK_REMINDER"
    static let markCompleteActionIdentifier = "LIFETRACK_MARK_COMPLETE"
    static let snoozeTenMinutesActionIdentifier = "LIFETRACK_SNOOZE_10_MIN"
    static let openTaskActionIdentifier = "LIFETRACK_OPEN_TASK"
    static let taskIDUserInfoKey = "taskID"
    static let taskTitleUserInfoKey = "taskTitle"
    static let categoryTitleUserInfoKey = "categoryTitle"
    static let dueTimestampUserInfoKey = "dueTimestamp"
    static let themeIDUserInfoKey = "themeID"
    private static let reminderLeadTime: TimeInterval = 30 * 60

    static func configureNotificationCategories() {
        let markCompleteAction = UNNotificationAction(
            identifier: markCompleteActionIdentifier,
            title: "Mark Complete",
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: snoozeTenMinutesActionIdentifier,
            title: "Snooze 10 min",
            options: []
        )
        let openAction = UNNotificationAction(
            identifier: openTaskActionIdentifier,
            title: "Open Task",
            options: [.foreground]
        )
        let taskReminderCategory = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [markCompleteAction, snoozeAction, openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([taskReminderCategory])
    }

    static func synchronizeReminder(
        taskID: UUID,
        title: String,
        categoryTitle: String,
        dueDate: Date,
        isCompleted: Bool,
        detailLine: String? = nil
    ) {
        let identifier = notificationIdentifier(for: taskID)

        Task {
            if isCompleted || dueDate <= Date() {
                cancel(identifier: identifier)
                return
            }

            let authorized = await requestAuthorizationIfNeeded()
            guard authorized else {
                return
            }

            schedule(
                identifier: identifier,
                title: title,
                categoryTitle: categoryTitle,
                dueDate: dueDate,
                detailLine: detailLine
            )
        }
    }

    static func snoozeReminder(
        taskID: UUID,
        title: String,
        categoryTitle: String,
        dueDate: Date,
        minutes: Int = 10,
        detailLine: String? = nil
    ) {
        let identifier = notificationIdentifier(for: taskID)
        let snoozeDate = Date().addingTimeInterval(TimeInterval(max(1, minutes) * 60))

        Task {
            let authorized = await requestAuthorizationIfNeeded()
            guard authorized else {
                return
            }

            schedule(
                identifier: identifier,
                title: title,
                categoryTitle: categoryTitle,
                dueDate: dueDate,
                preferredTriggerDate: snoozeDate,
                titleOverride: "Snoozed for \(minutes) minutes",
                detailLine: detailLine
            )
        }
    }

    static func cancel(taskID: UUID) {
        cancel(identifier: notificationIdentifier(for: taskID))
    }

    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                queueActionTipIfNeeded()
                return true
            case .denied:
                return false
            case .notDetermined:
                let isAuthorized = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                if isAuthorized {
                    queueActionTipIfNeeded()
                }
                return isAuthorized
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    private static func schedule(
        identifier: String,
        title: String,
        categoryTitle: String,
        dueDate: Date,
        preferredTriggerDate: Date? = nil,
        titleOverride: String? = nil,
        detailLine: String? = nil
    ) {
        let now = Date()
        let reminderDate = dueDate.addingTimeInterval(-reminderLeadTime)
        let triggerDate: Date
        if let preferredTriggerDate {
            triggerDate = preferredTriggerDate > now ? preferredTriggerDate : now.addingTimeInterval(3)
        } else if reminderDate > now {
            triggerDate = reminderDate
        } else if dueDate > now {
            triggerDate = now.addingTimeInterval(3)
        } else {
            cancel(identifier: identifier)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = titleOverride ?? notificationTitle(for: dueDate, referenceDate: triggerDate)
        content.subtitle = title
        content.body = notificationBody(
            categoryTitle: categoryTitle,
            dueDate: dueDate,
            detailLine: detailLine
        )
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = categoryIdentifier
        content.threadIdentifier = "lifetrack.task-reminders"
        content.targetContentIdentifier = identifier
        content.userInfo = [
            taskIDUserInfoKey: String(identifier.dropFirst(identifierPrefix.count)),
            taskTitleUserInfoKey: title,
            categoryTitleUserInfoKey: categoryTitle,
            dueTimestampUserInfoKey: dueDate.timeIntervalSince1970,
            themeIDUserInfoKey: LifeTrackAppTheme.current.rawValue
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        center.add(request)
    }

    private static func cancel(identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private static func notificationIdentifier(for taskID: UUID) -> String {
        "\(identifierPrefix)\(taskID.uuidString)"
    }

    private static func notificationTitle(for dueDate: Date, referenceDate: Date) -> String {
        let remainingSeconds = max(0, dueDate.timeIntervalSince(referenceDate))
        let remainingMinutes = max(1, Int(ceil(remainingSeconds / 60)))

        if remainingMinutes >= 30 {
            return "Due in 30 minutes"
        }

        if remainingMinutes == 1 {
            return "Due in 1 minute"
        }

        return "Due in \(remainingMinutes) minutes"
    }

    private static func notificationBody(
        categoryTitle: String,
        dueDate: Date,
        detailLine: String?
    ) -> String {
        let detail = detailLine?
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if let detail, !detail.isEmpty {
            return detail
        }

        return "\(categoryTitle) • \(dueDate.timeString)"
    }

    private static func queueActionTipIfNeeded() {
        let defaults = UserDefaults.standard
        guard
            !defaults.bool(forKey: LifeTrackSettings.Keys.reminderActionTipShown),
            !defaults.bool(forKey: LifeTrackSettings.Keys.reminderActionTipPending)
        else {
            return
        }

        defaults.set(true, forKey: LifeTrackSettings.Keys.reminderActionTipPending)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: actionTipDidBecomePendingNotification, object: nil)
        }
    }

    static func consumePendingActionTip() -> Bool {
        let defaults = UserDefaults.standard
        guard
            defaults.bool(forKey: LifeTrackSettings.Keys.reminderActionTipPending),
            !defaults.bool(forKey: LifeTrackSettings.Keys.reminderActionTipShown)
        else {
            defaults.removeObject(forKey: LifeTrackSettings.Keys.reminderActionTipPending)
            return false
        }

        defaults.removeObject(forKey: LifeTrackSettings.Keys.reminderActionTipPending)
        defaults.set(true, forKey: LifeTrackSettings.Keys.reminderActionTipShown)
        return true
    }
}
