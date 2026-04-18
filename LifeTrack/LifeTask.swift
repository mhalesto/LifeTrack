//
//  LifeTask.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import SwiftData

enum TaskCategory: String, CaseIterable, Identifiable {
    case health
    case finance
    case work
    case home
    case personal
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .health: "Health"
        case .finance: "Finance"
        case .work: "Work"
        case .home: "Home"
        case .personal: "Personal"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .health: "heart.text.square"
        case .finance: "creditcard"
        case .work: "briefcase"
        case .home: "house"
        case .personal: "person.crop.circle"
        case .other: "tag"
        }
    }
}

enum TaskTemplateAction: String {
    case none
    case email
}

enum TaskPriority: String, CaseIterable, Identifiable {
    case low
    case normal
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        }
    }

    var symbolName: String {
        switch self {
        case .low: "arrow.down.circle"
        case .normal: "equal.circle"
        case .high: "exclamationmark.circle"
        }
    }

    var focusScore: Int {
        switch self {
        case .low: 0
        case .normal: 12
        case .high: 34
        }
    }
}

enum TaskRecurrence: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var shortTitle: String {
        switch self {
        case .none: "No repeat"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var symbolName: String {
        switch self {
        case .none: "circle"
        case .daily: "sun.max"
        case .weekly: "calendar.badge.clock"
        case .monthly: "calendar"
        case .yearly: "calendar.badge.exclamationmark"
        }
    }

    var focusScore: Int {
        self == .none ? 0 : 18
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}

@Model
final class LifeTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var categoryRawValue: String
    var dueDate: Date
    var isCompleted: Bool
    var notes: String
    var templateActionRawValue: String
    var priorityRawValue: String = TaskPriority.normal.rawValue
    var recurrenceRawValue: String = TaskRecurrence.none.rawValue
    var estimatedDurationMinutes: Int?
    var documentStorageName: String?
    var documentDisplayName: String?
    var documentExtractedText: String = ""
    var documentAnalysisSummary: String?
    var documentSuggestedTitle: String?
    var documentSuggestedDueDate: Date?
    var documentKeywordsRawValue: String = ""
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        category: TaskCategory,
        categoryRawValue: String? = nil,
        dueDate: Date,
        isCompleted: Bool = false,
        notes: String = "",
        templateAction: TaskTemplateAction = .none,
        priority: TaskPriority = .normal,
        recurrence: TaskRecurrence = .none,
        estimatedDurationMinutes: Int? = 30,
        documentStorageName: String? = nil,
        documentDisplayName: String? = nil,
        documentExtractedText: String = "",
        documentAnalysisSummary: String? = nil,
        documentSuggestedTitle: String? = nil,
        documentSuggestedDueDate: Date? = nil,
        documentKeywords: [String] = [],
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.categoryRawValue = categoryRawValue ?? category.rawValue
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.notes = notes
        self.templateActionRawValue = templateAction.rawValue
        self.priorityRawValue = priority.rawValue
        self.recurrenceRawValue = recurrence.rawValue
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.documentStorageName = documentStorageName
        self.documentDisplayName = documentDisplayName
        self.documentExtractedText = documentExtractedText
        self.documentAnalysisSummary = documentAnalysisSummary
        self.documentSuggestedTitle = documentSuggestedTitle
        self.documentSuggestedDueDate = documentSuggestedDueDate
        self.documentKeywordsRawValue = documentKeywords.joined(separator: "\n")
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var templateAction: TaskTemplateAction {
        get { TaskTemplateAction(rawValue: templateActionRawValue) ?? .none }
        set { templateActionRawValue = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRawValue) ?? .normal }
        set { priorityRawValue = newValue.rawValue }
    }

    var recurrence: TaskRecurrence {
        get { TaskRecurrence(rawValue: recurrenceRawValue) ?? .none }
        set { recurrenceRawValue = newValue.rawValue }
    }

    var scheduledDurationMinutes: Int {
        get { max(5, estimatedDurationMinutes ?? 30) }
        set { estimatedDurationMinutes = max(5, newValue) }
    }

    var scheduledEndDate: Date {
        dueDate.addingTimeInterval(TimeInterval(scheduledDurationMinutes * 60))
    }

    var durationTitle: String {
        let minutes = scheduledDurationMinutes
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(minutes) min"
        }

        if remainingMinutes == 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    var documentKeywords: [String] {
        get {
            documentKeywordsRawValue
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            documentKeywordsRawValue = newValue.joined(separator: "\n")
        }
    }

    var isOverdue: Bool {
        !isDeleted && !isCompleted && dueDate < Date()
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    var hasDocument: Bool {
        documentStorageName != nil && documentDisplayName != nil
    }

    var hasDocumentIntelligence: Bool {
        !documentExtractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            documentSuggestedDueDate != nil ||
            documentSuggestedTitle != nil ||
            !documentKeywords.isEmpty
    }

    func nextRecurringTask(completedAt: Date = Date(), calendar: Calendar = .current) -> LifeTask? {
        guard let nextDueDate = recurrence.nextDate(after: dueDate, calendar: calendar) else {
            return nil
        }

        var normalizedDueDate = nextDueDate
        while normalizedDueDate <= completedAt {
            guard let followingDate = recurrence.nextDate(after: normalizedDueDate, calendar: calendar) else {
                break
            }
            normalizedDueDate = followingDate
        }

        return LifeTask(
            title: title,
            category: category,
            categoryRawValue: categoryRawValue,
            dueDate: normalizedDueDate,
            isCompleted: false,
            notes: notes,
            templateAction: templateAction,
            priority: priority,
            recurrence: recurrence,
            estimatedDurationMinutes: scheduledDurationMinutes,
            createdAt: completedAt,
            updatedAt: completedAt
        )
    }
}
