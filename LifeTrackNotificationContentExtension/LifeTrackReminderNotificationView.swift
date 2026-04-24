//
//  LifeTrackReminderNotificationView.swift
//  LifeTrackNotificationContentExtension
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import UIKit
import UserNotifications

struct LifeTrackReminderNotificationModel {
    let statusText: String
    let taskTitle: String
    let categoryTitle: String
    let detailText: String
    let footerText: String
    let dueDate: Date?
    let isHighPriority: Bool

    static let placeholder = LifeTrackReminderNotificationModel(
        statusText: "Due in 30 minutes",
        taskTitle: "Take medication",
        categoryTitle: "Health",
        detailText: "High priority • Health • 30 min",
        footerText: "Today at 10:45",
        dueDate: nil,
        isHighPriority: true
    )

    init(content: UNNotificationContent) {
        let userInfo = content.userInfo
        let taskTitle = userInfo["taskTitle"] as? String
        let categoryTitle = userInfo["categoryTitle"] as? String
        let dueTimestamp = userInfo["dueTimestamp"] as? TimeInterval
        let statusText = userInfo["reminderStatus"] as? String
        let detailText = userInfo["reminderDetail"] as? String
        let isHighPriority = userInfo["isHighPriority"] as? Bool
        let bodyLines = content.body
            .components(separatedBy: .newlines)
            .compactMap(\.nonEmptyValue)

        let resolvedStatus = statusText?.nonEmptyValue ?? content.subtitle.nonEmptyValue ?? bodyLines.first ?? "Task reminder"
        let remainingLines: [String]
        if let first = bodyLines.first, first.compare(resolvedStatus, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            remainingLines = Array(bodyLines.dropFirst())
        } else {
            remainingLines = bodyLines
        }

        self.statusText = resolvedStatus
        self.taskTitle = taskTitle?.nonEmptyValue ?? content.title.nonEmptyValue ?? "LifeTrack task"
        self.categoryTitle = categoryTitle?.nonEmptyValue ?? "Task"
        self.detailText = detailText?.nonEmptyValue ?? remainingLines.first ?? "Stay on track."
        self.footerText = remainingLines.dropFirst().joined(separator: " • ").nonEmptyValue ?? dueTimestamp.map { Self.footerText(for: Date(timeIntervalSince1970: $0)) } ?? "Due soon"
        self.dueDate = dueTimestamp.map(Date.init(timeIntervalSince1970:))
        self.isHighPriority = isHighPriority ?? self.detailText.localizedCaseInsensitiveContains("high priority")
    }

    init(
        statusText: String,
        taskTitle: String,
        categoryTitle: String,
        detailText: String,
        footerText: String,
        dueDate: Date?,
        isHighPriority: Bool
    ) {
        self.statusText = statusText
        self.taskTitle = taskTitle
        self.categoryTitle = categoryTitle
        self.detailText = detailText
        self.footerText = footerText
        self.dueDate = dueDate
        self.isHighPriority = isHighPriority
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

    var statusTint: UIColor {
        isHighPriority ? UIColor(red: 0.82, green: 0.24, blue: 0.28, alpha: 1.0) : categoryTint
    }

    var symbolName: String {
        switch categoryTitle.lowercased() {
        case "health":
            return "heart.text.square.fill"
        case "finance":
            return "creditcard.fill"
        case "work":
            return "briefcase.fill"
        case "home":
            return "house.fill"
        case "personal":
            return "person.crop.circle.fill"
        default:
            return "checklist"
        }
    }

    private static func footerText(for dueDate: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let timeText = formatter.string(from: dueDate)

        if calendar.isDateInToday(dueDate) {
            return "Today at \(timeText)"
        }
        if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow at \(timeText)"
        }

        formatter.dateStyle = .medium
        return formatter.string(from: dueDate)
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
