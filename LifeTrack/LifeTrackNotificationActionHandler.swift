//
//  LifeTrackNotificationActionHandler.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import SwiftData
@preconcurrency import UserNotifications

final class LifeTrackNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LifeTrackNotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        // Extract String? here (Sendable) so non-Sendable [AnyHashable:Any] is never captured
        let taskIDString = response.notification.request.content.userInfo["taskID"] as? String

        Task { @MainActor in
            LifeTrackNotificationActionHandler.handle(
                actionIdentifier: actionIdentifier,
                taskIDString: taskIDString
            )
            completionHandler()
        }
    }
}

@MainActor
enum LifeTrackNotificationActionHandler {
    private static let pendingOpenTaskIDKey = "lifetrack.pendingOpenTaskID"

    static func handle(actionIdentifier: String, taskIDString: String?) {
        guard let taskID = taskID(from: taskIDString) else {
            return
        }

        switch actionIdentifier {
        case ReminderScheduler.markCompleteActionIdentifier:
            markTaskComplete(taskID: taskID)
        case ReminderScheduler.snoozeTenMinutesActionIdentifier:
            snoozeTaskReminder(taskID: taskID)
        case ReminderScheduler.openTaskActionIdentifier, UNNotificationDefaultActionIdentifier:
            setPendingOpenTaskID(taskID)
        default:
            break
        }
    }

    static func consumePendingOpenTask(in tasks: [LifeTask]) -> LifeTask? {
        let defaults = UserDefaults.standard
        guard
            let rawValue = defaults.string(forKey: pendingOpenTaskIDKey),
            let taskID = UUID(uuidString: rawValue),
            let task = tasks.first(where: { $0.id == taskID && !$0.isDeleted })
        else {
            return nil
        }

        defaults.removeObject(forKey: pendingOpenTaskIDKey)
        return task
    }

    private static func markTaskComplete(taskID: UUID) {
        let modelContext = LifeTrackDataStore.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<LifeTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard
            let task = try? modelContext.fetch(descriptor).first,
            !task.isDeleted
        else {
            ReminderScheduler.cancel(taskID: taskID)
            return
        }

        guard !task.isCompleted else {
            ReminderScheduler.cancel(taskID: taskID)
            return
        }

        let now = Date()
        task.isCompleted = true
        task.updatedAt = now
        ReminderScheduler.cancel(taskID: task.id)

        let nextRecurringTask = task.nextRecurringTask(completedAt: now)
        if let nextRecurringTask {
            modelContext.insert(nextRecurringTask)
        }

        try? modelContext.save()

        if let nextRecurringTask {
            let customCategories = (try? modelContext.fetch(FetchDescriptor<CustomTaskCategory>())) ?? []
            TaskLifecycleManager.synchronizeReminder(
                for: nextRecurringTask,
                customCategories: customCategories
            )
        }
    }

    private static func snoozeTaskReminder(taskID: UUID) {
        let modelContext = LifeTrackDataStore.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<LifeTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )

        guard
            let task = try? modelContext.fetch(descriptor).first,
            !task.isDeleted,
            !task.isCompleted
        else {
            ReminderScheduler.cancel(taskID: taskID)
            return
        }

        let customCategories = (try? modelContext.fetch(FetchDescriptor<CustomTaskCategory>())) ?? []
        let categoryTitle = task.categoryOption(customCategories: customCategories).title
        ReminderScheduler.snoozeReminder(
            taskID: task.id,
            title: task.title,
            categoryTitle: categoryTitle,
            dueDate: task.dueDate,
            isHighPriority: task.priority == .high,
            detailLine: task.reminderDetailLine(categoryTitle: categoryTitle)
        )
    }

    private static func setPendingOpenTaskID(_ taskID: UUID) {
        UserDefaults.standard.set(taskID.uuidString, forKey: pendingOpenTaskIDKey)
    }

    private static func taskID(from rawValue: String?) -> UUID? {
        guard let rawValue else {
            return nil
        }

        return UUID(uuidString: rawValue)
    }
}
