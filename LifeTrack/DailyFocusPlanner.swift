//
//  DailyFocusPlanner.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation

struct DailyFocusRecommendation: Identifiable {
    let task: LifeTask
    let reason: DailyFocusReason
    let score: Int

    var id: UUID { task.id }
}

enum DailyFocusReason: String {
    case overdue
    case dueToday
    case highPriority
    case routine
    case documentReminder
    case upcoming

    var title: String {
        switch self {
        case .overdue: "Overdue"
        case .dueToday: "Due today"
        case .highPriority: "High priority"
        case .routine: "Part of your routine"
        case .documentReminder: "Document reminder"
        case .upcoming: "Coming up"
        }
    }

    var symbolName: String {
        switch self {
        case .overdue: "exclamationmark.circle.fill"
        case .dueToday: "sun.max.fill"
        case .highPriority: "flag.fill"
        case .routine: "repeat"
        case .documentReminder: "doc.text.magnifyingglass"
        case .upcoming: "calendar"
        }
    }
}

@MainActor
enum DailyFocusPlanner {
    static func recommendations(from tasks: [LifeTask], calendar: Calendar = .current) -> [DailyFocusRecommendation] {
        let openTasks = tasks.filter { !$0.isCompleted }

        let rankedTasks = openTasks
            .map { task in
                DailyFocusRecommendation(
                    task: task,
                    reason: reason(for: task, calendar: calendar),
                    score: score(for: task, calendar: calendar)
                )
            }
            .sorted { first, second in
                if first.score != second.score {
                    return first.score > second.score
                }

                return first.task.dueDate < second.task.dueDate
            }

        let limit = min(max(openTasks.count, 3), 5)
        return Array(rankedTasks.prefix(limit))
    }

    static func shouldOfferReset(for tasks: [LifeTask], calendar: Calendar = .current) -> Bool {
        let openTasks = tasks.filter { !$0.isCompleted }
        let overdueCount = openTasks.filter { $0.dueDate < Date() }.count
        let dueTodayCount = openTasks.filter { calendar.isDateInToday($0.dueDate) }.count
        return overdueCount >= 3 || dueTodayCount >= 5 || openTasks.count >= 12
    }

    static func shouldOfferOverdueReschedule(for tasks: [LifeTask]) -> Bool {
        tasks.contains(where: \.isOverdue)
    }

    static func resetSchedule(for tasks: [LifeTask], focusIDs: Set<UUID>, referenceDate: Date = Date(), calendar: Calendar = .current) -> [(LifeTask, Date)] {
        let openTasks = tasks
            .filter { !$0.isCompleted }
            .sorted { first, second in
                if focusIDs.contains(first.id) != focusIDs.contains(second.id) {
                    return focusIDs.contains(first.id)
                }

                return first.dueDate < second.dueDate
            }

        return openTasks.enumerated().compactMap { index, task in
            if focusIDs.contains(task.id) {
                return (task, focusSlotDate(index: index, referenceDate: referenceDate, calendar: calendar))
            }

            guard task.isOverdue else {
                return nil
            }

            let deferredIndex = max(index - focusIDs.count, 0)
            return (task, deferredDate(index: deferredIndex, referenceDate: referenceDate, calendar: calendar))
        }
    }

    static func overdueReschedulePlan(for tasks: [LifeTask], referenceDate: Date = Date(), calendar: Calendar = .current) -> [(LifeTask, Date)] {
        tasks
            .filter(\.isOverdue)
            .sorted { $0.dueDate < $1.dueDate }
            .enumerated()
            .map { index, task in
                (task, deferredDate(index: index, referenceDate: referenceDate, calendar: calendar))
            }
    }

    private static func score(for task: LifeTask, calendar: Calendar) -> Int {
        let now = Date()
        let dayDistance = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: task.dueDate)
        ).day ?? 0

        var score = task.priority.focusScore + task.recurrence.focusScore

        if task.dueDate < now {
            score += 120 + min(abs(dayDistance) * 4, 36)
        } else if calendar.isDateInToday(task.dueDate) {
            score += 100
        } else if dayDistance == 1 {
            score += 70
        } else if dayDistance <= 7 {
            score += 46 - max(dayDistance, 0) * 3
        } else {
            score += max(18 - dayDistance, 0)
        }

        if task.documentSuggestedDueDate != nil || !task.documentKeywords.isEmpty {
            score += 10
        }

        return score
    }

    private static func reason(for task: LifeTask, calendar: Calendar) -> DailyFocusReason {
        if task.isOverdue {
            return .overdue
        }

        if calendar.isDateInToday(task.dueDate) {
            return .dueToday
        }

        if task.priority == .high {
            return .highPriority
        }

        if task.recurrence != .none {
            return .routine
        }

        if task.documentSuggestedDueDate != nil || !task.documentKeywords.isEmpty {
            return .documentReminder
        }

        return .upcoming
    }

    private static func focusSlotDate(index: Int, referenceDate: Date, calendar: Calendar) -> Date {
        let hours = [9, 11, 14, 16, 18]
        let hour = hours[min(index, hours.count - 1)]
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let target = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfDay) ?? referenceDate

        if target > referenceDate {
            return target
        }

        return calendar.date(byAdding: .minute, value: 90 + (index * 30), to: referenceDate) ?? referenceDate
    }

    private static func deferredDate(index: Int, referenceDate: Date, calendar: Calendar) -> Date {
        let dayOffset = max(index / 3, 0) + 1
        let slot = index % 3
        let hours = [10, 14, 17]
        let baseDay = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        return calendar.date(bySettingHour: hours[slot], minute: 0, second: 0, of: baseDay) ?? baseDay
    }
}
