//
//  HabitEngine.swift
//  LifeTrack
//

import Foundation

struct HabitSummary {
    let task: LifeTask
    let currentStreak: Int
    let longestStreak: Int
    let completionDates: [Date]
    let recurrence: TaskRecurrence
    let filledDateStrings: Set<String>
    let cellCount: Int
}

enum HabitEngine {
    static func summaries(from tasks: [LifeTask]) -> [HabitSummary] {
        let habits = tasks.filter { $0.isHabit && !$0.isDeleted }

        var groupMap: [UUID: [LifeTask]] = [:]
        for task in habits {
            let key = task.habitGroupID ?? task.id
            groupMap[key, default: []].append(task)
        }

        var results: [HabitSummary] = []

        for (_, group) in groupMap {
            guard let representative = group
                .filter({ !$0.isCompleted })
                .sorted(by: { $0.dueDate < $1.dueDate })
                .first ?? group.sorted(by: { $0.dueDate > $1.dueDate }).first
            else { continue }

            let completed = group
                .filter { $0.isCompleted && $0.completedAt != nil }
                .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }

            let dates = completed.compactMap { $0.completedAt ?? ($0.isCompleted ? $0.updatedAt : nil) }
            let current = currentStreak(dates: dates, recurrence: representative.recurrence)
            let longest = longestStreak(dates: dates, recurrence: representative.recurrence)
            let count = cellCount(for: representative.recurrence)
            let filled = filledDateStrings(dates: dates, recurrence: representative.recurrence, cellCount: count)

            results.append(HabitSummary(
                task: representative,
                currentStreak: current,
                longestStreak: longest,
                completionDates: dates,
                recurrence: representative.recurrence,
                filledDateStrings: filled,
                cellCount: count
            ))
        }

        return results.sorted { $0.currentStreak > $1.currentStreak }
    }

    static func currentStreak(for task: LifeTask, in tasks: [LifeTask]) -> Int {
        let groupID = task.habitGroupID ?? task.id
        let completed = tasks
            .filter { ($0.habitGroupID ?? $0.id) == groupID && $0.isCompleted }
            .compactMap { $0.completedAt ?? ($0.isCompleted ? $0.updatedAt : nil) }
            .sorted(by: >)
        return currentStreak(dates: completed, recurrence: task.recurrence)
    }

    // MARK: - Private

    private static func currentStreak(dates: [Date], recurrence: TaskRecurrence) -> Int {
        guard !dates.isEmpty else { return 0 }
        let sorted = dates.sorted(by: >)
        var streak = 0
        var reference = Date()

        for date in sorted {
            if isWithinPeriod(date, before: reference, recurrence: recurrence) {
                streak += 1
                reference = date
            } else {
                break
            }
        }
        return streak
    }

    private static func longestStreak(dates: [Date], recurrence: TaskRecurrence) -> Int {
        guard !dates.isEmpty else { return 0 }
        let sorted = dates.sorted(by: <)
        var longest = 1
        var current = 1

        for i in 1..<sorted.count {
            let gap = Calendar.current.dateComponents(
                [intervalComponent(for: recurrence)],
                from: sorted[i - 1],
                to: sorted[i]
            )
            let units = gap.value(for: intervalComponent(for: recurrence)) ?? 0
            if units <= 2 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private static func isWithinPeriod(_ date: Date, before reference: Date, recurrence: TaskRecurrence) -> Bool {
        let component = intervalComponent(for: recurrence)
        let diff = Calendar.current.dateComponents([component], from: date, to: reference)
        let units = diff.value(for: component) ?? Int.max
        return units >= 0 && units <= 2
    }

    private static func cellCount(for recurrence: TaskRecurrence) -> Int {
        switch recurrence {
        case .none, .daily: return 91  // 13 columns × 7 rows
        case .weekly: return 52        // 13 columns × 4 rows
        case .monthly: return 26       // 13 columns × 2 rows
        case .yearly: return 13        // 13 columns × 1 row
        }
    }

    private static func filledDateStrings(dates: [Date], recurrence: TaskRecurrence, cellCount: Int) -> Set<String> {
        let cal = Calendar.current
        let component = intervalComponent(for: recurrence)
        let now = Date()
        var filled = Set<String>()
        for date in dates {
            let diff = cal.dateComponents([component], from: date, to: now)
            if let units = diff.value(for: component), units >= 0 && units < cellCount {
                filled.insert("\(units)")
            }
        }
        return filled
    }

    private static func intervalComponent(for recurrence: TaskRecurrence) -> Calendar.Component {
        switch recurrence {
        case .none, .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }
}
