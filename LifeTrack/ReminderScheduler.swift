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

    static func synchronizeReminder(
        taskID: UUID,
        title: String,
        categoryTitle: String,
        dueDate: Date,
        isCompleted: Bool
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
                dueDate: dueDate
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
                return true
            case .denied:
                return false
            case .notDetermined:
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
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
        dueDate: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(categoryTitle) task due now"
        content.sound = .default
        content.badge = 1

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
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
}
