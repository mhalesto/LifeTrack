//
//  TaskSpotlightIndexer.swift
//  LifeTrack
//
//  Publishes open LifeTask rows to Core Spotlight so iOS search can
//  surface them. Strategy: wholesale rebuild of the LifeTrack domain
//  on app launch / scene active. Cheap for the volumes a personal
//  task app sees, and guarantees deletes/edits are reflected without
//  threading hooks through every save site.
//

import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

enum TaskSpotlightIndexer {
    static let domainIdentifier = "com.currenttech.LifeTrack.tasks"

    /// Fired by ContentView's `.onContinueUserActivity(CSSearchableItemActionType)`
    /// with userInfo `["taskID": UUID]`. BetaDashboardView observes and opens the editor.
    static let openTaskNotification = Notification.Name("LifeTrack.spotlight.openTask")
    static let openTaskUserInfoKey = "taskID"

    static func reindex(_ tasks: [LifeTask]) {
        let index = CSSearchableIndex.default()
        let items: [CSSearchableItem] = tasks.compactMap(makeItem)

        index.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { _ in
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items) { _ in }
        }
    }

    static func extractTaskID(from activity: NSUserActivity) -> UUID? {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else {
            return nil
        }
        return UUID(uuidString: identifier)
    }

    private static func makeItem(for task: LifeTask) -> CSSearchableItem? {
        guard task.deletedAt == nil else { return nil }

        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = task.title
        attrs.contentDescription = description(for: task)
        attrs.keywords = keywords(for: task)
        attrs.dueDate = task.dueDate

        return CSSearchableItem(
            uniqueIdentifier: task.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attrs
        )
    }

    private static func description(for task: LifeTask) -> String {
        var parts: [String] = [task.category.title]
        if !task.notes.isEmpty {
            parts.append(String(task.notes.prefix(140)))
        }
        return parts.joined(separator: " — ")
    }

    private static func keywords(for task: LifeTask) -> [String] {
        var words: [String] = [task.category.title]
        if task.recurrence != .none {
            words.append(task.recurrence.shortTitle)
        }
        if task.financialEnabled {
            words.append(contentsOf: ["bill", "money"])
        }
        return words
    }
}
