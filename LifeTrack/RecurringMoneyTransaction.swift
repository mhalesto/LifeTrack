//
//  RecurringMoneyTransaction.swift
//  LifeTrack
//
//  Persisted template for transactions that repeat on a fixed cadence
//  (subscriptions, salary, rent). The expander turns each template into
//  concrete MoneyEntry rows on app launch and on demand.
//

import Foundation
import SwiftData

enum RecurringMoneyCadence: String, CaseIterable, Codable, Identifiable {
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

@Model
final class RecurringMoneyTransaction {
    @Attribute(.unique) var id: UUID
    var label: String
    var typeRawValue: String
    var amount: Double
    var currencyCode: String
    var category: String
    var cadenceRawValue: String
    var anchorDate: Date
    var nextRunDate: Date
    var endDate: Date?
    var includeInMonthlySpending: Bool
    var notes: String
    var isActive: Bool
    var lastGeneratedDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        type: MoneyTransactionType,
        amount: Double,
        currencyCode: String = MoneyCurrency.defaultCode,
        category: String,
        cadence: RecurringMoneyCadence,
        anchorDate: Date,
        endDate: Date? = nil,
        includeInMonthlySpending: Bool = true,
        notes: String = "",
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.typeRawValue = type.rawValue
        self.amount = amount
        self.currencyCode = MoneyCurrency.normalized(currencyCode)
        self.category = category
        self.cadenceRawValue = cadence.rawValue
        self.anchorDate = anchorDate
        self.nextRunDate = anchorDate
        self.endDate = endDate
        self.includeInMonthlySpending = includeInMonthlySpending
        self.notes = notes
        self.isActive = isActive
        self.lastGeneratedDate = nil
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var type: MoneyTransactionType {
        get { MoneyTransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var cadence: RecurringMoneyCadence {
        get { RecurringMoneyCadence(rawValue: cadenceRawValue) ?? .monthly }
        set { cadenceRawValue = newValue.rawValue }
    }
}

// MARK: - Expander

enum RecurringMoneyExpander {
    /// Produce the MoneyEntry rows that should exist for `template` between
    /// `anchorDate` and `now` (inclusive). Pure — does not insert into a context.
    static func entriesToCreate(
        from template: RecurringMoneyTransaction,
        through now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MoneyEntry] {
        guard template.isActive, template.amount > 0 else { return [] }

        let cutoff = template.endDate.map { min($0, now) } ?? now
        var nextDate = template.nextRunDate
        var emitted: [MoneyEntry] = []

        // Hard safety bound — never emit more than 366 entries per template per pass.
        var safety = 366
        while nextDate <= cutoff && safety > 0 {
            let entry = MoneyEntry(
                type: template.type,
                amount: template.amount,
                currencyCode: template.currencyCode,
                category: template.category,
                dateScope: .day,
                startDate: nextDate,
                notes: template.notes.isEmpty ? template.label : "\(template.label) — \(template.notes)",
                includeInMonthlySpending: template.includeInMonthlySpending,
                source: .recurring
            )
            emitted.append(entry)
            nextDate = template.cadence.nextDate(after: nextDate, calendar: calendar)
            safety -= 1
        }

        return emitted
    }

    /// Returns the date the template would next emit after `now`.
    static func upcomingDate(
        for template: RecurringMoneyTransaction,
        after now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard template.isActive else { return nil }
        var date = template.nextRunDate
        while date <= now {
            date = template.cadence.nextDate(after: date, calendar: calendar)
            if let endDate = template.endDate, date > endDate { return nil }
        }
        if let endDate = template.endDate, date > endDate { return nil }
        return date
    }

    /// Inserts generated entries into the model context and advances the template.
    @MainActor
    static func runPendingExpansions(
        templates: [RecurringMoneyTransaction],
        modelContext: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        var inserted = 0
        for template in templates {
            let entries = entriesToCreate(from: template, through: now, calendar: calendar)
            guard !entries.isEmpty else { continue }
            for entry in entries {
                modelContext.insert(entry)
                inserted += 1
            }
            // Advance nextRunDate past `now`.
            var advance = template.nextRunDate
            while advance <= now {
                advance = template.cadence.nextDate(after: advance, calendar: calendar)
            }
            template.nextRunDate = advance
            template.lastGeneratedDate = entries.last?.startDate ?? now
            template.updatedAt = now
        }
        if inserted > 0 {
            try? modelContext.save()
        }
        return inserted
    }
}
