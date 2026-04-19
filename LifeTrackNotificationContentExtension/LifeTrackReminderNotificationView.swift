//
//  LifeTrackReminderNotificationView.swift
//  LifeTrackNotificationContentExtension
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import UIKit
import UserNotifications

struct LifeTrackReminderNotificationModel {
    let reminderTitle: String
    let taskTitle: String
    let categoryTitle: String
    let dueDate: Date?

    static let placeholder = LifeTrackReminderNotificationModel(
        reminderTitle: "Due in 30 minutes",
        taskTitle: "Loading…",
        categoryTitle: "Task",
        dueDate: nil
    )

    init(content: UNNotificationContent) {
        let userInfo = content.userInfo
        let taskTitle = userInfo["taskTitle"] as? String
        let categoryTitle = userInfo["categoryTitle"] as? String
        let dueTimestamp = userInfo["dueTimestamp"] as? TimeInterval

        self.reminderTitle = content.title.nonEmptyValue ?? "Task reminder"
        self.taskTitle = taskTitle?.nonEmptyValue ?? content.subtitle.nonEmptyValue ?? "LifeTrack task"
        self.categoryTitle = categoryTitle?.nonEmptyValue ?? "Task"
        self.dueDate = dueTimestamp.map(Date.init(timeIntervalSince1970:))
    }

    init(
        reminderTitle: String,
        taskTitle: String,
        categoryTitle: String,
        dueDate: Date?
    ) {
        self.reminderTitle = reminderTitle
        self.taskTitle = taskTitle
        self.categoryTitle = categoryTitle
        self.dueDate = dueDate
    }

    var dueTimeText: String {
        guard let dueDate else {
            return "Due soon"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: dueDate)
    }

    var dueDateText: String {
        guard let dueDate else {
            return "Today"
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Today"
        }
        if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: dueDate)
    }

    var categoryTint: UIColor {
        switch categoryTitle.lowercased() {
        case "health":
            return UIColor(red: 0.71, green: 0.29, blue: 0.45, alpha: 1.0)
        case "finance":
            return UIColor(red: 0.18, green: 0.49, blue: 0.40, alpha: 1.0)
        case "work":
            return UIColor(red: 0.29, green: 0.36, blue: 0.78, alpha: 1.0)
        case "home":
            return UIColor(red: 0.65, green: 0.40, blue: 0.18, alpha: 1.0)
        case "personal":
            return UIColor(red: 0.18, green: 0.42, blue: 0.65, alpha: 1.0)
        default:
            return UIColor(red: 0.19, green: 0.35, blue: 0.85, alpha: 1.0)
        }
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
