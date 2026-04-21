//
//  TaskLifecycleManager.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import CoreLocation
import Foundation
import SwiftData

@MainActor
enum TaskLifecycleManager {
    struct PendingToggle {
        let task: LifeTask
        let wasCompleted: Bool
        let now: Date
    }

    /// Flips the in-memory completion state only. Safe to call inside
    /// `withAnimation` — no reminders, CoreLocation, or save happen here.
    static func beginToggleCompletion(for task: LifeTask) -> PendingToggle {
        let wasCompleted = task.isCompleted
        let now = Date()

        task.isCompleted.toggle()
        task.updatedAt = now

        if wasCompleted {
            task.completedAt = nil
        } else {
            task.completedAt = now
            if task.isHabit && task.habitGroupID == nil {
                task.habitGroupID = task.id
            }
        }

        return PendingToggle(task: task, wasCompleted: wasCompleted, now: now)
    }

    /// Runs the side effects (reminders, location regions, next recurring
    /// task, save). Kept off the animation transaction so the tick/fade
    /// commits immediately.
    static func finishToggleCompletion(
        _ pending: PendingToggle,
        in modelContext: ModelContext,
        customCategories: [CustomTaskCategory]
    ) {
        let task = pending.task

        if pending.wasCompleted {
            synchronizeReminder(for: task, customCategories: customCategories)
        } else {
            ReminderScheduler.cancel(taskID: task.id)
            LocationReminderManager.shared.cancelRegion(for: task.id)

            if let nextTask = task.nextRecurringTask(completedAt: pending.now) {
                modelContext.insert(nextTask)
                synchronizeReminder(for: nextTask, customCategories: customCategories)
                if nextTask.hasLocationReminder {
                    LocationReminderManager.shared.scheduleRegion(for: nextTask)
                }
            }
        }

        try? modelContext.save()
    }

    static func toggleCompletion(
        for task: LifeTask,
        in modelContext: ModelContext,
        customCategories: [CustomTaskCategory]
    ) {
        let pending = beginToggleCompletion(for: task)
        finishToggleCompletion(pending, in: modelContext, customCategories: customCategories)
    }

    @discardableResult
    static func delete(
        _ task: LifeTask,
        in modelContext: ModelContext,
        retentionPeriod: TaskBinRetentionPeriod? = nil
    ) -> Bool {
        let retentionPeriod = retentionPeriod ?? .current
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

    static func archiveOldCompletedTasks(
        from tasks: [LifeTask],
        in modelContext: ModelContext,
        archivePeriod: CompletedArchivePeriod? = nil
    ) {
        let archivePeriod = archivePeriod ?? .current
        guard archivePeriod.ageLimit != nil else {
            return
        }

        let now = Date()
        let candidates = tasks.filter { task in
            guard task.isCompleted, task.deletedAt == nil, let completedAt = task.completedAt else {
                return false
            }
            return archivePeriod.shouldArchive(completedAt: completedAt, referenceDate: now)
        }

        guard !candidates.isEmpty else {
            return
        }

        for task in candidates {
            ReminderScheduler.cancel(taskID: task.id)
            task.deletedAt = now
            task.updatedAt = now
        }

        try? modelContext.save()
    }

    static func purgeExpiredBinItems(
        from tasks: [LifeTask],
        in modelContext: ModelContext,
        retentionPeriod: TaskBinRetentionPeriod? = nil
    ) {
        let retentionPeriod = retentionPeriod ?? .current
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
        var reminderSnapshots: [ReminderSyncSnapshot] = []
        reminderSnapshots.reserveCapacity(plan.count)

        for (task, date) in plan {
            task.dueDate = date
            task.updatedAt = now
            reminderSnapshots.append(
                ReminderSyncSnapshot(
                    id: task.id,
                    title: task.title,
                    categoryTitle: task.categoryOption(customCategories: customCategories).title,
                    dueDate: task.dueDate,
                    isCompleted: task.isCompleted,
                    isDeleted: task.isDeleted
                )
            )
        }

        try? modelContext.save()

        let snapshots = reminderSnapshots
        Task { @MainActor in
            for snapshot in snapshots {
                if snapshot.isDeleted {
                    ReminderScheduler.cancel(taskID: snapshot.id)
                } else {
                    ReminderScheduler.synchronizeReminder(
                        taskID: snapshot.id,
                        title: snapshot.title,
                        categoryTitle: snapshot.categoryTitle,
                        dueDate: snapshot.dueDate,
                        isCompleted: snapshot.isCompleted
                    )
                }
            }
        }
    }

    private struct ReminderSyncSnapshot: Sendable {
        let id: UUID
        let title: String
        let categoryTitle: String
        let dueDate: Date
        let isCompleted: Bool
        let isDeleted: Bool
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
