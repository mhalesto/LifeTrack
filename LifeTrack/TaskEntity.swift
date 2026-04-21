//
//  TaskEntity.swift
//  LifeTrack
//
//  AppEntity wrapper for LifeTask so Siri, Spotlight and the Shortcuts app
//  can reference individual tasks as structured values.
//

import AppIntents
import Foundation
import SwiftData

struct TaskEntity: AppEntity, Identifiable {
    let id: UUID
    let title: String
    let dueDate: Date
    let isCompleted: Bool
    let categoryTitle: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Task")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(categoryTitle) · \(Self.dueFormatter.string(from: dueDate))"
        )
    }

    static var defaultQuery = TaskEntityQuery()

    private static let dueFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

struct TaskEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [TaskEntity.ID]) async throws -> [TaskEntity] {
        let context = LifeTrackDataStore.sharedModelContainer.mainContext
        let ids = Set(identifiers)
        let descriptor = FetchDescriptor<LifeTask>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let tasks = (try? context.fetch(descriptor)) ?? []
        return tasks.map(TaskEntity.init(from:))
    }

    @MainActor
    func entities(matching string: String) async throws -> [TaskEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return try await suggestedEntities() }

        let context = LifeTrackDataStore.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<LifeTask>(
            sortBy: [SortDescriptor(\.dueDate)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all
            .filter { !$0.isCompleted && $0.deletedAt == nil && $0.title.lowercased().contains(needle) }
            .prefix(25)
            .map(TaskEntity.init(from:))
    }

    @MainActor
    func suggestedEntities() async throws -> [TaskEntity] {
        let context = LifeTrackDataStore.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<LifeTask>(
            sortBy: [SortDescriptor(\.dueDate)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all
            .filter { !$0.isCompleted && $0.deletedAt == nil }
            .prefix(10)
            .map(TaskEntity.init(from:))
    }
}

// MARK: - Bridging

extension TaskEntity {
    init(from task: LifeTask) {
        self.id = task.id
        self.title = task.title
        self.dueDate = task.dueDate
        self.isCompleted = task.isCompleted
        self.categoryTitle = task.category.title
    }
}
