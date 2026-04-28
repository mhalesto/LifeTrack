//
//  NewTaskFormState.swift
//  LifeTrack
//
//  Holds the persistable form data that NewTaskView is editing. Pulled out of
//  the view so cards can read/write through a single observable model rather
//  than receiving 30+ bindings each.
//

import Foundation
import Observation
import SwiftUI

@Observable
final class NewTaskFormState {
    var title: String
    var categoryRawValue: String
    var dueDate: Date
    var isCompleted: Bool
    var notes: String
    var templateAction: TaskTemplateAction
    var priority: TaskPriority
    var recurrence: TaskRecurrence
    var durationMinutes: Int

    var documentStorageName: String?
    var documentDisplayName: String?
    var documentExtractedText: String
    var documentAnalysisSummary: String?
    var documentSuggestedTitle: String?
    var documentSuggestedDueDate: Date?
    var documentKeywords: [String]

    var locationConfig: LocationReminderConfig?

    var advancedFieldValues: [String: String]

    var financialEnabled: Bool
    var financialType: TaskFinancialType
    var plannedAmountText: String
    var actualAmountText: String
    var currencyCode: String
    var budgetCategory: String
    var hasPaymentDate: Bool
    var paymentDate: Date
    var financialLinkOption: MoneyLinkOption
    var financialNotes: String
    var includeInMonthlySpending: Bool
    var markPlannedOnCreate: Bool

    var voiceTranscript: String

    init(task: LifeTask? = nil, template: TaskTemplate? = nil, captureDraft: CapturedTaskDraft? = nil) {
        let structuredCaptureDraft = captureDraft?.structuredDraft
        let captureCategoryRawValue = structuredCaptureDraft?.category?.rawValue ?? captureDraft?.resolvedCategory.rawValue
        let captureDueDate = structuredCaptureDraft?.dueDate ?? captureDraft?.resolvedDueDate
        let capturePriority = structuredCaptureDraft?.priority ?? captureDraft?.resolvedPriority
        let captureAdvancedFields = structuredCaptureDraft?.advancedFields ?? [:]
        let captureFinancialEnabled =
            structuredCaptureDraft?.financialEnabled == true ||
            structuredCaptureDraft?.financialType != nil ||
            structuredCaptureDraft?.plannedAmount != nil ||
            structuredCaptureDraft?.actualAmount != nil ||
            structuredCaptureDraft?.budgetCategory != nil ||
            structuredCaptureDraft?.paymentDate != nil
        let templateWantsFinance = template?.id == "bill"

        title = task?.title ?? captureDraft?.resolvedTitle ?? template?.title ?? ""
        categoryRawValue = task?.categoryRawValue ?? captureCategoryRawValue ?? template?.category.rawValue ?? TaskCategory.personal.rawValue
        dueDate = task?.dueDate ?? captureDueDate ?? template?.dueDate ?? Date()
        isCompleted = task?.isCompleted ?? false
        notes = task?.notes ?? captureDraft?.resolvedNotes ?? template?.notes ?? ""
        templateAction = task?.templateAction ?? template?.action ?? .none
        priority = task?.priority ?? capturePriority ?? template?.priority ?? .normal
        recurrence = task?.recurrence ?? template?.recurrence ?? .none
        durationMinutes = task?.scheduledDurationMinutes ?? template?.estimatedDurationMinutes ?? 30
        documentStorageName = task?.documentStorageName
        documentDisplayName = task?.documentDisplayName
        documentExtractedText = task?.documentExtractedText ?? ""
        documentAnalysisSummary = task?.documentAnalysisSummary
        documentSuggestedTitle = task?.documentSuggestedTitle
        documentSuggestedDueDate = task?.documentSuggestedDueDate
        documentKeywords = task?.documentKeywords ?? []
        if let lat = task?.locationReminderLatitude, let lon = task?.locationReminderLongitude {
            locationConfig = LocationReminderConfig(
                name: task?.locationReminderName ?? "",
                latitude: lat,
                longitude: lon,
                radius: task?.locationReminderRadius ?? 150,
                onArrival: task?.locationReminderOnArrival ?? true
            )
        } else {
            locationConfig = nil
        }
        advancedFieldValues = task?.advancedFields ?? captureAdvancedFields
        financialEnabled = task?.financialEnabled ?? (captureFinancialEnabled || templateWantsFinance)
        financialType = task?.financialType ?? structuredCaptureDraft?.financialType ?? .expense
        plannedAmountText = NewTaskFormState.amountInputString(task?.plannedAmount ?? structuredCaptureDraft?.plannedAmount)
        actualAmountText = NewTaskFormState.amountInputString(task?.actualAmount ?? structuredCaptureDraft?.actualAmount)
        currencyCode = task?.currencyCode ?? structuredCaptureDraft?.currencyCode ?? NewTaskFormState.currentMoneyCurrencyCode
        budgetCategory = task?.budgetCategory ?? structuredCaptureDraft?.budgetCategory ?? (templateWantsFinance ? "Bills" : "")
        hasPaymentDate = task?.paymentDate != nil || structuredCaptureDraft?.paymentDate != nil
        paymentDate = task?.paymentDate ?? structuredCaptureDraft?.paymentDate ?? task?.dueDate ?? captureDueDate ?? template?.dueDate ?? Date()
        financialLinkOption = MoneyLinkOption.resolved(
            budgetId: task?.linkedBudgetId ?? structuredCaptureDraft?.linkedBudgetId,
            goalId: task?.linkedGoalId ?? structuredCaptureDraft?.linkedGoalId
        )
        financialNotes = task?.financialNotes ?? structuredCaptureDraft?.financialNotes ?? ""
        includeInMonthlySpending = task?.includeInMonthlySpending ?? structuredCaptureDraft?.includeInMonthlySpending ?? true
        markPlannedOnCreate = task?.markPlannedOnCreate ?? structuredCaptureDraft?.markPlannedOnCreate ?? templateWantsFinance
        voiceTranscript = captureDraft?.rawText ?? ""
    }

    static var currentMoneyCurrencyCode: String {
        MoneyCurrency.normalized(UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.moneyCurrencyCode) ?? MoneyCurrency.defaultCode)
    }

    static func amountInputString(_ amount: Double?) -> String {
        guard let amount, amount > 0 else { return "" }
        if amount.rounded(.down) == amount {
            return String(Int(amount))
        }
        return String(format: "%.2f", amount)
    }
}
