//
//  RecurringTaskCatchUp.swift
//  LifeTrack
//
//  When a recurring task has been overdue for more than one full cycle,
//  shift its dueDate forward to the next on/after-today occurrence.
//  Avoids piling up dozens of historical instances on the dashboard
//  while still surfacing the most recent missed cycle.
//

import Foundation
import SwiftData

enum RecurringTaskCatchUp {
    @MainActor
    @discardableResult
    static func runCatchUp(
        tasks: [LifeTask],
        modelContext: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        var advanced = 0

        for task in tasks where task.recurrence != .none && !task.isCompleted && task.deletedAt == nil {
            guard task.dueDate < today else { continue }
            guard let firstNext = task.recurrence.nextDate(after: task.dueDate, calendar: calendar) else { continue }
            guard firstNext < today else { continue }

            var next = firstNext
            var safety = 366
            while next < today && safety > 0 {
                guard let further = task.recurrence.nextDate(after: next, calendar: calendar) else { break }
                next = further
                safety -= 1
            }
            task.dueDate = next
            task.updatedAt = now
            advanced += 1
        }

        if advanced > 0 {
            try? modelContext.save()
        }
        return advanced
    }
}
