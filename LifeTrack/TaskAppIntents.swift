//
//  TaskAppIntents.swift
//  LifeTrack
//
//  Parameterized App Intents that read/write LifeTask directly via SwiftData
//  without opening the app. Used by Siri, Shortcuts and Spotlight.
//

import AppIntents
import Foundation
import SwiftData

// MARK: - Category parameter

enum TaskCategoryAppEnum: String, AppEnum {
    case health, finance, work, home, personal, other

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Category")
    }

    static var caseDisplayRepresentations: [TaskCategoryAppEnum: DisplayRepresentation] = [
        .health:   "Health",
        .finance:  "Finance",
        .work:     "Work",
        .home:     "Home",
        .personal: "Personal",
        .other:    "Other"
    ]

    var bridged: TaskCategory {
        TaskCategory(rawValue: rawValue) ?? .other
    }
}

// MARK: - Create Task

struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Creates a new task in LifeTrack.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var taskTitle: String

    @Parameter(title: "Notes", default: "")
    var notes: String

    @Parameter(title: "Due Date", default: nil)
    var dueDate: Date?

    @Parameter(title: "Category", default: .personal)
    var category: TaskCategoryAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle) to LifeTrack") {
            \.$category
            \.$dueDate
            \.$notes
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<TaskEntity> & ProvidesDialog {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw $taskTitle.needsValueError("What should the task be called?")
        }

        let effectiveDate = dueDate ?? defaultDueDate()
        let task = LifeTask(
            title: trimmed,
            category: category.bridged,
            dueDate: effectiveDate,
            notes: notes
        )

        let context = LifeTrackDataStore.sharedModelContainer.mainContext
        context.insert(task)
        try? context.save()

        let entity = TaskEntity(from: task)
        return .result(
            value: entity,
            dialog: IntentDialog("Added \"\(trimmed)\" to LifeTrack.")
        )
    }

    private func defaultDueDate() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}

// MARK: - Complete Task

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Marks a task as done in LifeTrack.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task")
    var task: TaskEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$task) as done")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = LifeTrackDataStore.sharedModelContainer.mainContext
        let id = task.id
        let descriptor = FetchDescriptor<LifeTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let match = (try? context.fetch(descriptor))?.first else {
            return .result(dialog: IntentDialog("I couldn't find that task anymore."))
        }

        match.isCompleted = true
        match.completedAt = Date()
        match.updatedAt = Date()
        try? context.save()

        return .result(dialog: IntentDialog("Nice — marked \"\(match.title)\" as done."))
    }
}

// MARK: - Today's Tasks snippet

struct GetTodaysTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Tasks"
    static var description = IntentDescription("Reads your top tasks for today.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[TaskEntity]> & ProvidesDialog {
        let context = LifeTrackDataStore.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<LifeTask>(
            sortBy: [SortDescriptor(\.dueDate)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let cal = Calendar.current
        let endOfToday = cal.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()

        let todays = all.filter {
            !$0.isCompleted && $0.deletedAt == nil && $0.dueDate <= endOfToday
        }.prefix(5)

        let entities = todays.map(TaskEntity.init(from:))

        let dialog: IntentDialog
        if entities.isEmpty {
            dialog = IntentDialog("You're clear — no tasks scheduled for today.")
        } else {
            let lines = entities.enumerated().map { i, t in "\(i + 1). \(t.title)" }.joined(separator: ". ")
            dialog = IntentDialog("\(entities.count) on your plate: \(lines)")
        }
        return .result(value: Array(entities), dialog: dialog)
    }
}
