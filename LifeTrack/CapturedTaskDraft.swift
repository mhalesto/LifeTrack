//
//  CapturedTaskDraft.swift
//  LifeTrack
//

import Foundation

struct CapturedTaskDraft: Identifiable, Equatable {
    let id = UUID()
    var source: InboxItemSource
    var rawText: String
    var structuredDraft: VoiceTaskDraft
    var createdAt: Date

    init(
        source: InboxItemSource,
        rawText: String,
        structuredDraft: VoiceTaskDraft? = nil,
        createdAt: Date = Date()
    ) {
        self.source = source
        self.rawText = rawText
        self.createdAt = createdAt
        self.structuredDraft = structuredDraft ?? VoiceTaskParser.parse(rawText, referenceDate: createdAt)
    }

    var normalizedRawText: String {
        rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canPersist: Bool {
        !normalizedRawText.isEmpty
    }

    var resolvedTitle: String {
        Self.quickTitle(for: normalizedRawText, preferred: structuredDraft.title)
    }

    var resolvedNotes: String {
        structuredDraft.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var resolvedCategory: TaskCategory {
        structuredDraft.category ?? .personal
    }

    var resolvedDueDate: Date {
        structuredDraft.dueDate ?? Self.defaultDueDate(referenceDate: createdAt)
    }

    var resolvedPriority: TaskPriority {
        structuredDraft.priority ?? .normal
    }

    mutating func replaceRawText(_ value: String) {
        rawText = value
        structuredDraft = VoiceTaskParser.parse(value, referenceDate: createdAt)
    }

    mutating func applyEnhancedDraft(_ enhanced: VoiceTaskDraft) {
        if let title = enhanced.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            structuredDraft.title = title
        }
        if let notes = enhanced.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            structuredDraft.notes = notes
        }
        if let category = enhanced.category {
            structuredDraft.category = category
        }
        if let dueDate = enhanced.dueDate {
            structuredDraft.dueDate = dueDate
        }
        if let priority = enhanced.priority {
            structuredDraft.priority = priority
        }
        if !enhanced.advancedFields.isEmpty {
            structuredDraft.advancedFields.merge(enhanced.advancedFields) { _, new in new }
        }
        if let financialEnabled = enhanced.financialEnabled {
            structuredDraft.financialEnabled = financialEnabled
        }
        if let financialType = enhanced.financialType {
            structuredDraft.financialType = financialType
        }
        if let plannedAmount = enhanced.plannedAmount {
            structuredDraft.plannedAmount = plannedAmount
        }
        if let actualAmount = enhanced.actualAmount {
            structuredDraft.actualAmount = actualAmount
        }
        if let currencyCode = enhanced.currencyCode {
            structuredDraft.currencyCode = currencyCode
        }
        if let budgetCategory = enhanced.budgetCategory {
            structuredDraft.budgetCategory = budgetCategory
        }
        if let paymentDate = enhanced.paymentDate {
            structuredDraft.paymentDate = paymentDate
        }
        if let linkedBudgetId = enhanced.linkedBudgetId {
            structuredDraft.linkedBudgetId = linkedBudgetId
        }
        if let linkedGoalId = enhanced.linkedGoalId {
            structuredDraft.linkedGoalId = linkedGoalId
        }
        if let includeInMonthlySpending = enhanced.includeInMonthlySpending {
            structuredDraft.includeInMonthlySpending = includeInMonthlySpending
        }
        if let markPlannedOnCreate = enhanced.markPlannedOnCreate {
            structuredDraft.markPlannedOnCreate = markPlannedOnCreate
        }
        if let financialNotes = enhanced.financialNotes,
           !financialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            structuredDraft.financialNotes = financialNotes
        }
    }

    func makeInboxItem() -> InboxItem {
        InboxItem(
            source: source,
            rawText: normalizedRawText,
            previewTitle: resolvedTitle,
            structuredDraft: structuredDraft,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    func makeTask() -> LifeTask {
        let task = LifeTask(
            title: resolvedTitle,
            category: resolvedCategory,
            dueDate: resolvedDueDate,
            notes: resolvedNotes,
            priority: resolvedPriority
        )
        task.advancedFields = structuredDraft.advancedFields
        applyFinancialDetails(to: task)
        return task
    }

    static func quickTitle(for rawText: String, preferred: String?) -> String {
        let preferredTitle = preferred?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !preferredTitle.isEmpty {
            return preferredTitle
        }

        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Untitled capture"
        }

        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        if firstLine.count <= 72 {
            return firstLine
        }
        return String(firstLine.prefix(72)) + "…"
    }

    static func defaultDueDate(referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func applyFinancialDetails(to task: LifeTask) {
        let shouldEnableFinancials =
            structuredDraft.financialEnabled == true ||
            structuredDraft.financialType != nil ||
            structuredDraft.plannedAmount != nil ||
            structuredDraft.actualAmount != nil ||
            structuredDraft.currencyCode != nil ||
            structuredDraft.budgetCategory != nil ||
            structuredDraft.paymentDate != nil ||
            structuredDraft.linkedBudgetId != nil ||
            structuredDraft.linkedGoalId != nil ||
            structuredDraft.includeInMonthlySpending != nil ||
            structuredDraft.markPlannedOnCreate != nil ||
            structuredDraft.financialNotes != nil

        guard shouldEnableFinancials else {
            return
        }

        task.financialEnabled = true
        if let financialType = structuredDraft.financialType {
            task.financialType = financialType
        }
        if let plannedAmount = structuredDraft.plannedAmount {
            task.plannedAmount = plannedAmount
        }
        if let actualAmount = structuredDraft.actualAmount {
            task.actualAmount = actualAmount
        }
        if let currencyCode = structuredDraft.currencyCode {
            task.currencyCode = MoneyCurrency.normalized(currencyCode)
        }
        if let budgetCategory = structuredDraft.budgetCategory {
            task.budgetCategory = budgetCategory
        }
        if let paymentDate = structuredDraft.paymentDate {
            task.paymentDate = paymentDate
        }
        if let linkedBudgetId = structuredDraft.linkedBudgetId {
            task.linkedBudgetId = linkedBudgetId
        }
        if let linkedGoalId = structuredDraft.linkedGoalId {
            task.linkedGoalId = linkedGoalId
        }
        if let includeInMonthlySpending = structuredDraft.includeInMonthlySpending {
            task.includeInMonthlySpending = includeInMonthlySpending
        }
        if let markPlannedOnCreate = structuredDraft.markPlannedOnCreate {
            task.markPlannedOnCreate = markPlannedOnCreate
        }
        if let financialNotes = structuredDraft.financialNotes {
            task.financialNotes = financialNotes
        }
    }
}
