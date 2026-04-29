//
//  BetaFocusedDashboardShared.swift
//  LifeTrack
//

import Foundation
import SwiftUI

enum BetaFocusedDashboardRoute: Hashable {
    case tools
    case statistics
    case calendar
    case documents
    case taskData
    case money
    case bin
    case weeklyReview
    case backup
    case aiSuggestions
}

enum BetaFocusedDashboardTab: Hashable {
    case home
    case capture
    case focus
    case tools
}

enum BetaFocusedDashboardTypography {
    static let greeting = Font.system(size: 22, weight: .regular, design: .serif)
    static let date = Font.system(size: 13, weight: .regular, design: .default)
    static let section = Font.system(size: 17, weight: .medium, design: .serif)
    static let heroTitle = Font.system(size: 29, weight: .semibold, design: .serif)
    static let statValue = Font.system(size: 25, weight: .regular, design: .serif)
    static let button = Font.system(size: 14.5, weight: .semibold, design: .default)
    static let body = Font.system(size: 12, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 10.5, weight: .regular, design: .default)
    static let chip = Font.system(size: 10.5, weight: .semibold, design: .default)
    static let nav = Font.system(size: 10.5, weight: .medium, design: .default)
    static let taskTitle = Font.system(size: 14.5, weight: .medium, design: .default)
}

enum BetaFocusedDashboardPalette {
    static let backgroundTop = Color(hex: 0xFFF9F2)
    static let backgroundBottom = Color(hex: 0xF6EBDD)
    static let headerText = Color(hex: 0x2B231F)
    static let secondaryText = Color(hex: 0x8D847A)
    static let tertiaryText = Color(hex: 0xA89E94)
    static let cardBackground = Color.white.opacity(0.88)
    static let cardSecondary = Color(hex: 0xFFFDF9).opacity(0.96)
    static let softSurface = Color(hex: 0xFBF4EC)
    static let border = Color(hex: 0xE7DACB)
    static let softShadow = Color.black.opacity(0.06)

    static let heroAccent = Color(hex: 0xE56C4D)
    static let heroAccentDeep = Color(hex: 0xF48764)
    static let dueTodayTint = Color(hex: 0xD09A45)
    static let overdueTint = Color(hex: 0xDF7A66)
    static let completedTint = Color(hex: 0x8AA37D)
    static let progressTint = Color(hex: 0x7D966A)

    static let statsPillText = Color(hex: 0x6C4E35)
    static let statsPillBackground = Color(hex: 0xFFF5EA)
    static let navAccent = Color(hex: 0xE66A4C)

    static let captureTint = Color(hex: 0x2B7BC6)
    static let importExportTint = Color(hex: 0x7573B6)

    static let financeTint = Color(hex: 0x4D78AE)
    static let financeBackground = Color(hex: 0xEAF1FB)
    static let healthTint = Color(hex: 0xC06D58)
    static let healthBackground = Color(hex: 0xF8E8E1)
    static let workTint = Color(hex: 0x748C69)
    static let workBackground = Color(hex: 0xEDF4E7)
    static let homeTint = Color(hex: 0xC49A3E)
    static let homeBackground = Color(hex: 0xFBF0DA)
    static let personalTint = Color(hex: 0x8A74C6)
    static let personalBackground = Color(hex: 0xF0EBFA)
    static let otherTint = Color(hex: 0x80766F)
    static let otherBackground = Color(hex: 0xF2ECE6)

    static let warningTint = Color(hex: 0xBF7A2F)
    static let warningBackground = Color(hex: 0xFBF0DA)
    static let dangerBackground = Color(hex: 0xFAE6DF)
}

struct BetaFocusedDashboardCategoryVisuals {
    let tint: Color
    let background: Color
}

struct BetaFocusedDashboardPlanPreviewModel {
    let summary: String
    let detail: String
    let rescueCount: Int
    let busyBlockCount: Int
}

enum BetaFocusedDashboardTaskHealthState {
    case recurringMissed
    case blocked
    case stale
    case needsDate

    var title: String {
        switch self {
        case .recurringMissed: "Recurring missed"
        case .blocked: "Blocked"
        case .stale: "Stale"
        case .needsDate: "Needs date"
        }
    }

    var symbolName: String {
        switch self {
        case .recurringMissed: "repeat.circle"
        case .blocked: "hand.raised.fill"
        case .stale: "clock.badge.exclamationmark"
        case .needsDate: "calendar.badge.exclamationmark"
        }
    }

    var tint: Color {
        switch self {
        case .recurringMissed:
            BetaFocusedDashboardPalette.overdueTint
        case .blocked:
            BetaFocusedDashboardPalette.warningTint
        case .stale:
            BetaFocusedDashboardPalette.secondaryText
        case .needsDate:
            BetaFocusedDashboardPalette.captureTint
        }
    }

    var background: Color {
        switch self {
        case .recurringMissed:
            BetaFocusedDashboardPalette.dangerBackground
        case .blocked:
            BetaFocusedDashboardPalette.warningBackground
        case .stale:
            BetaFocusedDashboardPalette.otherBackground
        case .needsDate:
            BetaFocusedDashboardPalette.financeBackground
        }
    }
}

enum BetaFocusedDashboardTimeFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter
    }()

    static let dateAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM, h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter
    }()
}

extension LifeTask {
    func betaFocusedHealthState(referenceDate: Date = Date(), calendar: Calendar = .current) -> BetaFocusedDashboardTaskHealthState? {
        guard !isDeleted, !isCompleted else { return nil }

        if isOverdue, recurrence != .none {
            return .recurringMissed
        }

        let blockerText = ([notes] + Array(advancedFields.values))
            .joined(separator: " ")
            .lowercased()

        if blockerText.contains("blocked") ||
            blockerText.contains("waiting") ||
            blockerText.contains("on hold") ||
            blockerText.contains("stuck") ||
            blockerText.contains("depends") {
            return .blocked
        }

        let staleCutoff = calendar.date(byAdding: .day, value: -14, to: referenceDate) ?? referenceDate
        if updatedAt < staleCutoff || dueDate < staleCutoff {
            return .stale
        }

        let dueComponents = calendar.dateComponents([.hour, .minute], from: dueDate)
        let daysFromCreateToDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: createdAt),
            to: calendar.startOfDay(for: dueDate)
        ).day

        if daysFromCreateToDue == 1,
           dueComponents.hour == 9,
           dueComponents.minute == 0,
           priority == .normal,
           recurrence == .none {
            return .needsDate
        }

        return nil
    }
}
