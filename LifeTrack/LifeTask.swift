//
//  LifeTask.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import SwiftData

nonisolated enum TaskCategory: String, CaseIterable, Identifiable, Sendable, Codable {
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

nonisolated enum TaskTemplateAction: String, Sendable {
    case none
    case email
}

nonisolated enum TaskPriority: String, CaseIterable, Identifiable, Sendable, Codable {
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

nonisolated enum TaskRecurrence: String, CaseIterable, Identifiable, Sendable {
    case none
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var shortTitle: String {
        switch self {
        case .none: "No repeat"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .biweekly: "Biweekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var symbolName: String {
        switch self {
        case .none: "circle"
        case .daily: "sun.max"
        case .weekly: "calendar.badge.clock"
        case .biweekly: "calendar.badge.clock"
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
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
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
    var templateMetadataRawValue: String = ""
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    // Habit tracking
    var habitGroupID: UUID?
    var completedAt: Date?
    // When set, completing this task contributes to the streak of the habit
    // identified by `habitContributionID` (the habit group ID, which equals
    // either the habit's id or its habitGroupID).
    var habitContributionID: UUID?
    // Location reminder
    var locationReminderName: String?
    var locationReminderLatitude: Double?
    var locationReminderLongitude: Double?
    var locationReminderRadius: Double?
    var locationReminderOnArrival: Bool = true
    // Optional money tracking. These defaults keep normal tasks unchanged.
    var financialEnabled: Bool = false
    var financialTypeRawValue: String = TaskFinancialType.expense.rawValue
    var plannedAmount: Double = 0
    var actualAmount: Double?
    var currencyCode: String = MoneyCurrency.defaultCode
    var budgetCategory: String = ""
    var paymentDate: Date?
    var linkedBudgetId: UUID?
    var linkedGoalId: UUID?
    var includeInMonthlySpending: Bool = true
    var markPlannedOnCreate: Bool = false
    var financialNotes: String = ""

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
        financialEnabled: Bool = false,
        financialType: TaskFinancialType = .expense,
        plannedAmount: Double = 0,
        actualAmount: Double? = nil,
        currencyCode: String = MoneyCurrency.defaultCode,
        budgetCategory: String = "",
        paymentDate: Date? = nil,
        linkedBudgetId: UUID? = nil,
        linkedGoalId: UUID? = nil,
        includeInMonthlySpending: Bool = true,
        markPlannedOnCreate: Bool = false,
        financialNotes: String = "",
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
        self.financialEnabled = financialEnabled
        self.financialTypeRawValue = financialType.rawValue
        self.plannedAmount = plannedAmount
        self.actualAmount = actualAmount
        self.currencyCode = MoneyCurrency.normalized(currencyCode)
        self.budgetCategory = budgetCategory
        self.paymentDate = paymentDate
        self.linkedBudgetId = linkedBudgetId
        self.linkedGoalId = linkedGoalId
        self.includeInMonthlySpending = includeInMonthlySpending
        self.markPlannedOnCreate = markPlannedOnCreate
        self.financialNotes = financialNotes
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

    var financialType: TaskFinancialType {
        get { TaskFinancialType(rawValue: financialTypeRawValue) ?? .expense }
        set { financialTypeRawValue = newValue.rawValue }
    }

    var financialVariance: Double? {
        guard let actualAmount else { return nil }
        return actualAmount - plannedAmount
    }

    var hasFinancialActivity: Bool {
        financialEnabled && (plannedAmount > 0 || actualAmount != nil)
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

    var advancedFields: [String: String] {
        get {
            guard !templateMetadataRawValue.isEmpty,
                  let data = templateMetadataRawValue.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            let cleaned = newValue.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard !cleaned.isEmpty,
                  let data = try? JSONEncoder().encode(cleaned),
                  let string = String(data: data, encoding: .utf8) else {
                templateMetadataRawValue = ""
                return
            }
            templateMetadataRawValue = string
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

        let next = LifeTask(
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
        next.habitGroupID = habitGroupID ?? id
        next.locationReminderName = locationReminderName
        next.locationReminderLatitude = locationReminderLatitude
        next.locationReminderLongitude = locationReminderLongitude
        next.locationReminderRadius = locationReminderRadius
        next.locationReminderOnArrival = locationReminderOnArrival
        next.financialEnabled = financialEnabled
        next.financialType = financialType
        next.plannedAmount = plannedAmount
        next.actualAmount = nil
        next.currencyCode = MoneyCurrency.normalized(currencyCode)
        next.budgetCategory = budgetCategory
        next.paymentDate = nil
        next.linkedBudgetId = linkedBudgetId
        next.linkedGoalId = linkedGoalId
        next.includeInMonthlySpending = includeInMonthlySpending
        next.markPlannedOnCreate = markPlannedOnCreate
        next.financialNotes = financialNotes
        return next
    }

    var hasLocationReminder: Bool {
        locationReminderLatitude != nil && locationReminderLongitude != nil
    }

    func reminderDetailLine(categoryTitle: String) -> String {
        alertDetailLine(categoryTitle: categoryTitle, includeLocationFallback: true)
    }

    func alertDetailLine(categoryTitle: String, includeLocationFallback: Bool) -> String {
        if financialEnabled {
            if let detail = notificationLine(from: financialNotes) {
                return detail
            }

            let trackedAmount = actualAmount ?? (plannedAmount > 0 ? plannedAmount : nil)
            if let trackedAmount {
                let amountKind = actualAmount == nil ? "Planned" : "Actual"
                var parts = [
                    "\(amountKind) \(financialType.title.lowercased())",
                    MoneyFormatting.currency(trackedAmount, code: currencyCode)
                ]
                if let budget = notificationLine(from: budgetCategory) {
                    parts.append(budget)
                }
                return conciseNotificationLine(parts.joined(separator: " • "))
            }
        }

        if let detail = notificationLine(from: notes) {
            return detail
        }

        if let detail = notificationLine(from: documentAnalysisSummary) {
            return "Document: \(detail)"
        }

        if includeLocationFallback, let location = notificationLine(from: locationReminderName) {
            return "Location reminder • \(location)"
        }

        if priority == .high {
            return "High priority • \(categoryTitle) • \(durationTitle)"
        }

        if recurrence != .none {
            return "\(recurrence.shortTitle) • \(categoryTitle) • \(durationTitle)"
        }

        return "\(categoryTitle) • \(durationTitle)"
    }

    private func notificationLine(from value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return conciseNotificationLine(collapsed)
    }

    private func conciseNotificationLine(_ value: String) -> String {
        guard value.count > 96 else { return value }
        return "\(value.prefix(93))..."
    }

    var isHabit: Bool { recurrence != .none }
}
