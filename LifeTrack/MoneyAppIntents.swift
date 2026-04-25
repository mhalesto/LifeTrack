//
//  MoneyAppIntents.swift
//  LifeTrack
//
//  App Intents for money-tracking — log expenses and ask "what did I
//  spend today?" via Siri or Shortcuts without opening the app.
//

import AppIntents
import Foundation
import SwiftData

// MARK: - Type parameter

enum MoneyTransactionTypeAppEnum: String, AppEnum {
    case expense, income, savings, debtPayment

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Money Type")
    }

    static var caseDisplayRepresentations: [MoneyTransactionTypeAppEnum: DisplayRepresentation] = [
        .expense:     "Expense",
        .income:      "Income",
        .savings:     "Savings",
        .debtPayment: "Debt payment"
    ]

    var bridged: MoneyTransactionType {
        switch self {
        case .expense:     .expense
        case .income:      .income
        case .savings:     .savings
        case .debtPayment: .debtPayment
        }
    }
}

// MARK: - Log expense / income

struct LogMoneyEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Money"
    static var description = IntentDescription("Adds a money entry to LifeTrack.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Type", default: .expense)
    var type: MoneyTransactionTypeAppEnum

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Category", default: "")
    var category: String

    @Parameter(title: "Notes", default: "")
    var notes: String

    @Parameter(title: "Date", default: nil)
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) \(\.$type) in LifeTrack") {
            \.$category
            \.$date
            \.$notes
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            throw $amount.needsValueError("How much should I log?")
        }
        let context = LifeTrackDataStore.sharedModelContainer.mainContext
        let currency = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.moneyCurrencyCode)
            ?? MoneyCurrency.defaultCode

        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCategory = trimmedCategory.isEmpty ? defaultCategory(for: type.bridged) : trimmedCategory

        let entry = MoneyEntry(
            type: type.bridged,
            amount: amount,
            currencyCode: currency,
            category: resolvedCategory,
            dateScope: .day,
            startDate: date ?? Date(),
            notes: notes,
            includeInMonthlySpending: type.bridged != .income,
            source: .manual
        )
        context.insert(entry)
        try? context.save()

        let formatted = MoneyFormatting.currency(amount, code: currency)
        return .result(dialog: IntentDialog("Logged \(formatted) \(type.bridged.title.lowercased()) in \(resolvedCategory)."))
    }

    private func defaultCategory(for type: MoneyTransactionType) -> String {
        switch type {
        case .expense:     "Uncategorized"
        case .income:      "Income"
        case .savings:     "Savings"
        case .transfer:    "Transfer"
        case .debtPayment: "Debt"
        }
    }
}

// MARK: - Spent today

struct SpentTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Money Spent Today"
    static var description = IntentDescription("Reads the total amount you've spent today.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let context = LifeTrackDataStore.sharedModelContainer.mainContext
        let entryDescriptor = FetchDescriptor<MoneyEntry>()
        let entries = (try? context.fetch(entryDescriptor)) ?? []
        let taskDescriptor = FetchDescriptor<LifeTask>()
        let tasks = (try? context.fetch(taskDescriptor)) ?? []
        let currency = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.moneyCurrencyCode)
            ?? MoneyCurrency.primaryCurrencyCode(entries: entries, tasks: tasks)

        let calendar = Calendar.current
        let day = calendar.dateInterval(of: .day, for: Date())
            ?? DateInterval(start: Date(), duration: 86_400)

        var total: Double = 0
        for entry in entries {
            guard MoneyCurrency.normalized(entry.currencyCode) == MoneyCurrency.normalized(currency) else { continue }
            guard entry.includeInMonthlySpending else { continue }
            switch entry.type {
            case .expense, .debtPayment:
                total += MoneyAnalytics.amount(for: entry, in: day, calendar: calendar)
            case .income, .savings, .transfer:
                continue
            }
        }

        let formatted = MoneyFormatting.currency(total, code: currency)
        let dialog: IntentDialog = total > 0
            ? IntentDialog("You've spent \(formatted) today.")
            : IntentDialog("Nothing logged yet today.")
        return .result(value: total, dialog: dialog)
    }
}

// MARK: - Spent this month

struct SpentThisMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "Money Spent This Month"
    static var description = IntentDescription("Reads your spending vs plan for the current month.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = LifeTrackDataStore.sharedModelContainer.mainContext
        let entries = (try? context.fetch(FetchDescriptor<MoneyEntry>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<LifeTask>())) ?? []
        let currency = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.moneyCurrencyCode)
            ?? MoneyCurrency.primaryCurrencyCode(entries: entries, tasks: tasks)

        let summary = MoneyAnalytics.monthlySummary(
            for: Date(),
            entries: entries,
            tasks: tasks,
            currencyCode: currency
        )

        let actual = MoneyFormatting.currency(summary.actualSpending, code: currency)
        let planned = MoneyFormatting.currency(summary.plannedSpending, code: currency)
        let dialog: IntentDialog
        if summary.plannedSpending > 0 {
            dialog = IntentDialog("This month: \(actual) spent against a \(planned) plan.")
        } else {
            dialog = IntentDialog("This month: \(actual) spent so far.")
        }
        return .result(dialog: dialog)
    }
}
