//
//  TaskLifecycleManager.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import SwiftData

@MainActor
enum TaskLifecycleManager {
    static func toggleCompletion(
        for task: LifeTask,
        in modelContext: ModelContext,
        customCategories: [CustomTaskCategory]
    ) {
        let wasCompleted = task.isCompleted
        let now = Date()

        task.isCompleted.toggle()
        task.updatedAt = now

        if wasCompleted {
            synchronizeReminder(for: task, customCategories: customCategories)
        } else {
            ReminderScheduler.cancel(taskID: task.id)

            if let nextTask = task.nextRecurringTask(completedAt: now) {
                modelContext.insert(nextTask)
                synchronizeReminder(for: nextTask, customCategories: customCategories)
            }
        }

        try? modelContext.save()
    }

    @discardableResult
    static func delete(
        _ task: LifeTask,
        in modelContext: ModelContext,
        retentionPeriod: TaskBinRetentionPeriod = .current
    ) -> Bool {
        if retentionPeriod == .immediately {
            permanentlyDelete(task, in: modelContext)
            return false
        }

        ReminderScheduler.cancel(taskID: task.id)
        task.deletedAt = Date()
        task.updatedAt = Date()
        try? modelContext.save()
        return true
    }

    static func restore(
        _ task: LifeTask,
        in modelContext: ModelContext,
        customCategories: [CustomTaskCategory]
    ) {
        task.deletedAt = nil
        task.updatedAt = Date()
        try? modelContext.save()
        synchronizeReminder(for: task, customCategories: customCategories)
    }

    static func permanentlyDelete(
        _ task: LifeTask,
        in modelContext: ModelContext
    ) {
        ReminderScheduler.cancel(taskID: task.id)
        DocumentStore.delete(storageName: task.documentStorageName)
        modelContext.delete(task)
        try? modelContext.save()
    }

    static func purgeExpiredBinItems(
        from tasks: [LifeTask],
        in modelContext: ModelContext,
        retentionPeriod: TaskBinRetentionPeriod = .current
    ) {
        let expiredTasks = tasks.filter { task in
            guard let deletedAt = task.deletedAt else {
                return false
            }

            return retentionPeriod.isExpired(deletedAt: deletedAt)
        }

        guard !expiredTasks.isEmpty else {
            return
        }

        for task in expiredTasks {
            ReminderScheduler.cancel(taskID: task.id)
            DocumentStore.delete(storageName: task.documentStorageName)
            modelContext.delete(task)
        }

        try? modelContext.save()
    }

    static func applySchedule(
        _ plan: [(LifeTask, Date)],
        in modelContext: ModelContext,
        customCategories: [CustomTaskCategory]
    ) {
        let now = Date()

        for (task, date) in plan {
            task.dueDate = date
            task.updatedAt = now
            synchronizeReminder(for: task, customCategories: customCategories)
        }

        try? modelContext.save()
    }

    static func synchronizeReminder(
        for task: LifeTask,
        customCategories: [CustomTaskCategory]
    ) {
        guard !task.isDeleted else {
            ReminderScheduler.cancel(taskID: task.id)
            return
        }

        ReminderScheduler.synchronizeReminder(
            taskID: task.id,
            title: task.title,
            categoryTitle: task.categoryOption(customCategories: customCategories).title,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted
        )
    }
}
