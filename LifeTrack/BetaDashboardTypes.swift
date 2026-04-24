//
//  BetaDashboardTypes.swift
//  LifeTrack
//
//  Navigation routes, tabs, and data models used by the beta dashboard.
//

import SwiftUI

// MARK: - Routes

enum BetaHomeRoute: Hashable {
    case statistics
    case calendar
    case documents
    case importTasks
    case exportTasks
    case money
}

// MARK: - Quick Action Model

struct BetaQuickAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let iconBg: Color
    let iconTint: Color
    var isLocked: Bool = false
    let action: () -> Void
}

// MARK: - Tabs & Sort

enum BetaTab: Hashable {
    case home, tasks, focus, habits, more
}

enum DashboardSortOrder: String, CaseIterable {
    case today = "Today"
    case dueDate = "Due Date"
    case priority = "Priority"
    case title = "Title"
}

// MARK: - Stat Summary Kind

enum BetaSummaryKind: String, CaseIterable, Identifiable {
    case dueToday, upcoming, completed, overdue
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dueToday: "Due Today"
        case .upcoming: "Upcoming"
        case .completed: "Completed"
        case .overdue: "Overdue"
        }
    }

    var subtitle: String {
        switch self {
        case .dueToday: "Needs attention"
        case .upcoming: "Planned ahead"
        case .completed: "Finished"
        case .overdue: "Past due"
        }
    }

    var sheetSubtitle: String {
        switch self {
        case .dueToday: "Tasks that need attention before the day closes."
        case .upcoming: "Planned work coming up after today."
        case .completed: "Finished tasks you can review or move back to open."
        case .overdue: "Past-due tasks that need a new decision."
        }
    }

    var emptyTitle: String {
        switch self {
        case .dueToday: "Nothing due today"
        case .upcoming: "No upcoming tasks"
        case .completed: "No completed tasks yet"
        case .overdue: "Nothing overdue"
        }
    }

    var emptyMessage: String {
        switch self {
        case .dueToday: "Your day is clear. Create a task if something needs attention."
        case .upcoming: "Add due dates to see what is planned beyond today."
        case .completed: "Completed tasks will appear here once you finish them."
        case .overdue: "No past-due items. Keep the dashboard current by updating due dates."
        }
    }

    var symbolName: String {
        switch self {
        case .dueToday: "sun.max.fill"
        case .upcoming: "calendar"
        case .completed: "checkmark.seal.fill"
        case .overdue: "exclamationmark.triangle.fill"
        }
    }

    var iconTint: Color {
        switch self {
        case .dueToday: BetaPalette.statDueToday
        case .upcoming: BetaPalette.statUpcoming
        case .completed: BetaPalette.statCompleted
        case .overdue: BetaPalette.statOverdue
        }
    }

    var iconBg: Color {
        switch self {
        case .dueToday: BetaPalette.statDueTodayBg
        case .upcoming: BetaPalette.statUpcomingBg
        case .completed: BetaPalette.statCompletedBg
        case .overdue: BetaPalette.statOverdueBg
        }
    }
}
