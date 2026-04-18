//
//  LifeTrackReminderNotificationView.swift
//  LifeTrackNotificationContentExtension
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI
import UserNotifications

struct LifeTrackReminderNotificationModel {
    let reminderTitle: String
    let taskTitle: String
    let categoryTitle: String
    let dueDate: Date?
    let theme: LifeTrackNotificationTheme

    static let placeholder = LifeTrackReminderNotificationModel(
        reminderTitle: "Due in 30 minutes",
        taskTitle: "Review task",
        categoryTitle: "Personal",
        dueDate: nil,
        theme: .focus
    )

    init(content: UNNotificationContent) {
        let userInfo = content.userInfo
        let taskTitle = userInfo["taskTitle"] as? String
        let categoryTitle = userInfo["categoryTitle"] as? String
        let dueTimestamp = userInfo["dueTimestamp"] as? TimeInterval
        let themeID = userInfo["themeID"] as? String

        self.reminderTitle = content.title.nonEmptyValue ?? "Task reminder"
        self.taskTitle = taskTitle?.nonEmptyValue ?? content.subtitle.nonEmptyValue ?? "LifeTrack task"
        self.categoryTitle = categoryTitle?.nonEmptyValue ?? "Task"
        self.dueDate = dueTimestamp.map(Date.init(timeIntervalSince1970:))
        self.theme = LifeTrackNotificationTheme(rawValue: themeID ?? "") ?? .focus
    }

    init(
        reminderTitle: String,
        taskTitle: String,
        categoryTitle: String,
        dueDate: Date?,
        theme: LifeTrackNotificationTheme
    ) {
        self.reminderTitle = reminderTitle
        self.taskTitle = taskTitle
        self.categoryTitle = categoryTitle
        self.dueDate = dueDate
        self.theme = theme
    }

    var dueTimeText: String {
        guard let dueDate else {
            return "Due soon"
        }

        return dueDate.formatted(Date.FormatStyle().hour().minute())
    }

    var dueDateText: String {
        guard let dueDate else {
            return "Today"
        }

        if Calendar.current.isDateInToday(dueDate) {
            return "Today"
        }

        if Calendar.current.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        }

        return dueDate.formatted(Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day())
    }
}

struct LifeTrackReminderNotificationView: View {
    let model: LifeTrackReminderNotificationModel

    private var theme: LifeTrackNotificationTheme {
        model.theme
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 14) {
                header

                VStack(alignment: .leading, spacing: 10) {
                    Text(model.taskTitle)
                        .font(.system(.title3, design: theme.fontDesign, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    HStack(spacing: 8) {
                        capsule(
                            icon: "tag.fill",
                            title: model.categoryTitle,
                            foreground: theme.categoryTint(for: model.categoryTitle),
                            background: theme.categoryTint(for: model.categoryTitle).opacity(0.13)
                        )

                        capsule(
                            icon: "clock.fill",
                            title: "\(model.dueDateText) at \(model.dueTimeText)",
                            foreground: theme.secondaryText,
                            background: Color.white.opacity(0.62)
                        )
                    }
                }

                Divider()
                    .overlay(theme.hairline)

                actionStrip
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.hairline.opacity(0.9), lineWidth: 0.8)
        }
        .shadow(color: theme.shadow, radius: 18, x: 0, y: 10)
        .padding(3)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.accentSoft)
                    .frame(width: 52, height: 52)

                Circle()
                    .stroke(theme.accent.opacity(0.20), lineWidth: 8)
                    .frame(width: 38, height: 38)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("LifeTrack Reminder")
                    .font(.system(.caption, design: theme.fontDesign, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)

                Text(model.reminderTitle)
                    .font(.system(.headline, design: theme.fontDesign, weight: .bold))
                    .foregroundStyle(theme.primaryText)
            }

            Spacer(minLength: 8)

            Text(model.dueTimeText)
                .font(.system(.subheadline, design: theme.fontDesign, weight: .bold))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(theme.accentSoft, in: Capsule())
        }
    }

    private var actionStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Quick actions")
                .font(.system(.caption2, design: theme.fontDesign, weight: .bold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.3)

            HStack(spacing: 8) {
                actionPreview(icon: "checkmark", title: "Complete", tint: theme.success)
                actionPreview(icon: "clock.arrow.circlepath", title: "Snooze", tint: theme.warning)
                actionPreview(icon: "arrow.up.right", title: "Open", tint: theme.accent)
            }
        }
    }

    private func actionPreview(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))

            Text(title)
                .font(.system(.caption, design: theme.fontDesign, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 8)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 0.7)
        }
    }

    private func capsule(icon: String, title: String, foreground: Color, background: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))

            Text(title)
                .font(.system(.caption, design: theme.fontDesign, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(background, in: Capsule())
    }
}

enum LifeTrackNotificationTheme: String {
    case focus
    case sage
    case dreamy
    case cobalt
    case ember

    var fontDesign: Font.Design {
        switch self {
        case .sage: .default
        case .ember: .serif
        case .focus, .dreamy, .cobalt: .rounded
        }
    }

    var backgroundTop: Color {
        switch self {
        case .focus: Color(hex: 0xF8FAFF)
        case .sage: Color(hex: 0xF7FBF8)
        case .dreamy: Color(hex: 0xFBF8FF)
        case .cobalt: Color(hex: 0xF4F8FF)
        case .ember: Color(hex: 0xFFF8F3)
        }
    }

    var backgroundBottom: Color {
        switch self {
        case .focus: Color(hex: 0xEEF3F8)
        case .sage: Color(hex: 0xEAF4EF)
        case .dreamy: Color(hex: 0xEEF2FF)
        case .cobalt: Color(hex: 0xDDEBFF)
        case .ember: Color(hex: 0xFFE7DB)
        }
    }

    var accent: Color {
        switch self {
        case .focus: Color(hex: 0x3159D9)
        case .sage: Color(hex: 0x2F7E66)
        case .dreamy: Color(hex: 0x6A5AE0)
        case .cobalt: Color(hex: 0x0957FF)
        case .ember: Color(hex: 0xE5482E)
        }
    }

    var accentSoft: Color {
        switch self {
        case .focus: Color(hex: 0xE8EEFF)
        case .sage: Color(hex: 0xE7F4EF)
        case .dreamy: Color(hex: 0xEFECFF)
        case .cobalt: Color(hex: 0xDCEBFF)
        case .ember: Color(hex: 0xFFE7D6)
        }
    }

    var primaryText: Color {
        switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x111827)
        case .cobalt: Color(hex: 0x0B132B)
        case .ember: Color(hex: 0x21120F)
        }
    }

    var secondaryText: Color {
        switch self {
        case .focus, .sage, .dreamy: Color(hex: 0x5F6673)
        case .cobalt: Color(hex: 0x4E5871)
        case .ember: Color(hex: 0x66534F)
        }
    }

    var hairline: Color {
        accentSoft.opacity(0.92)
    }

    var shadow: Color {
        switch self {
        case .focus: Color(hex: 0x1D3557, alpha: 0.14)
        case .sage: Color(hex: 0x143C2F, alpha: 0.14)
        case .dreamy: Color(hex: 0x312E81, alpha: 0.14)
        case .cobalt: Color(hex: 0x082A70, alpha: 0.16)
        case .ember: Color(hex: 0x6F1D13, alpha: 0.15)
        }
    }

    var success: Color {
        switch self {
        case .focus, .dreamy: Color(hex: 0x2F9E6D)
        case .sage: Color(hex: 0x238B64)
        case .cobalt: Color(hex: 0x009A84)
        case .ember: Color(hex: 0x2C8C6A)
        }
    }

    var warning: Color {
        switch self {
        case .focus, .dreamy: Color(hex: 0xD08B2E)
        case .sage: Color(hex: 0xB47B2A)
        case .cobalt: Color(hex: 0xDA8B00)
        case .ember: Color(hex: 0xEA6A12)
        }
    }

    func categoryTint(for title: String) -> Color {
        switch title.lowercased() {
        case "health": Color(hex: 0xB54A73)
        case "finance": Color(hex: 0x2F7E66)
        case "work": Color(hex: 0x4A5CC7)
        case "home": Color(hex: 0xA6662D)
        case "personal": Color(hex: 0x2E6AA7)
        default: accent
        }
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Color {
    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

#Preview {
    LifeTrackReminderNotificationView(
        model: LifeTrackReminderNotificationModel(
            reminderTitle: "Due in 30 minutes",
            taskTitle: "Pay electricity bill",
            categoryTitle: "Finance",
            dueDate: Date().addingTimeInterval(30 * 60),
            theme: .dreamy
        )
    )
    .frame(width: 350, height: 270)
}

