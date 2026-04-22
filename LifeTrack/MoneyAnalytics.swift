//
//  MoneyAnalytics.swift
//  LifeTrack
//
//  Created by Codex on 2026/04/23.
//

import Foundation
import SwiftData

struct MoneyMonthlySummary: Equatable {
    var currencyCode: String
    var plannedIncome: Double = 0
    var actualIncome: Double = 0
    var plannedSpending: Double = 0
    var actualSpending: Double = 0
    var plannedSavings: Double = 0
    var actualSavings: Double = 0
    var transfers: Double = 0
    var debtPayments: Double = 0

    var plannedRemaining: Double {
        plannedIncome - plannedSpending - plannedSavings
    }

    var actualRemaining: Double {
        actualIncome - actualSpending - actualSavings
    }

    var spendingVariance: Double {
        actualSpending - plannedSpending
    }

    var savingsVariance: Double {
        actualSavings - plannedSavings
    }
}

struct MoneyCategoryTotal: Identifiable, Equatable {
    var category: String
    var planned: Double
    var actual: Double
    var currencyCode: String
    var kind: MoneyTransactionType

    var id: String {
        "\(kind.rawValue)-\(currencyCode)-\(category)"
    }

    var progress: Double {
        guard planned > 0 else { return actual > 0 ? 1 : 0 }
        return min(actual / planned, 1)
    }
}

enum MoneyBillStatus: String {
    case paid
    case upcoming
    case atRisk

    var title: String {
        switch self {
        case .paid: "Paid"
        case .upcoming: "Upcoming"
        case .atRisk: "At Risk"
        }
    }
}

struct MoneyBillSnapshot: Identifiable, Equatable {
    var id: UUID
    var title: String
    var category: String
    var plannedAmount: Double
    var actualAmount: Double?
    var currencyCode: String
    var dueDate: Date
    var status: MoneyBillStatus

    var variance: Double? {
        guard let actualAmount else { return nil }
        return actualAmount - plannedAmount
    }
}

struct MoneyImpactPreview: Equatable {
    var monthlySpendingDelta: Double
    var weeklySpendingDelta: Double
    var categoryDelta: Double
    var savingsDelta: Double
    var currencyCode: String
}

struct MoneyProjectionPoint: Identifiable, Equatable {
    var date: Date
    var balance: Double

    var id: Date { date }
}

enum MoneyAnalytics {
    static func availableCurrencies(entries: [MoneyEntry], tasks: [LifeTask]) -> [String] {
        let entryCodes = entries.map { MoneyCurrency.normalized($0.currencyCode) }
        let taskCodes = tasks
            .filter(\.financialEnabled)
            .map { MoneyCurrency.normalized($0.currencyCode) }
        let codes = Set(entryCodes + taskCodes)
        return codes.isEmpty ? [MoneyCurrency.defaultCode] : codes.sorted()
    }

    static func monthInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 86_400)
    }

    static func weekInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
    }

    static func monthlySummary(
        for date: Date,
        entries: [MoneyEntry],
        tasks: [LifeTask],
        currencyCode: String,
        calendar: Calendar = .current
    ) -> MoneyMonthlySummary {
        let normalizedCurrency = MoneyCurrency.normalized(currencyCode)
        let interval = monthInterval(containing: date, calendar: calendar)
        let relevantEntries = entries.filter { MoneyCurrency.normalized($0.currencyCode) == normalizedCurrency }
        let relevantTasks = tasks.filter {
            $0.financialEnabled &&
            !$0.isDeleted &&
            MoneyCurrency.normalized($0.currencyCode) == normalizedCurrency
        }
        let linkedEntryTaskIDs = Set(relevantEntries.compactMap(\.linkedTaskId))

        var summary = MoneyMonthlySummary(currencyCode: normalizedCurrency)

        for entry in relevantEntries {
            let amount = amount(for: entry, in: interval, calendar: calendar)
            guard amount > 0 else { continue }

            switch entry.type {
            case .expense:
                if entry.includeInMonthlySpending { summary.actualSpending += amount }
            case .income:
                summary.actualIncome += amount
            case .savings:
                summary.actualSavings += amount
            case .transfer:
                summary.transfers += amount
            case .debtPayment:
                summary.debtPayments += amount
                if entry.includeInMonthlySpending { summary.actualSpending += amount }
            }
        }

        for task in relevantTasks {
            let date = task.paymentDate ?? task.dueDate
            guard intervalContains(interval, date) else { continue }

            switch task.financialType {
            case .expense:
                if task.includeInMonthlySpending {
                    summary.plannedSpending += max(task.plannedAmount, 0)
                    if !linkedEntryTaskIDs.contains(task.id), let actual = task.actualAmount {
                        summary.actualSpending += max(actual, 0)
                    }
                }
            case .income, .reimbursement:
                summary.plannedIncome += max(task.plannedAmount, 0)
                if !linkedEntryTaskIDs.contains(task.id), let actual = task.actualAmount {
                    summary.actualIncome += max(actual, 0)
                }
            case .savings:
                summary.plannedSavings += max(task.plannedAmount, 0)
                if !linkedEntryTaskIDs.contains(task.id), let actual = task.actualAmount {
                    summary.actualSavings += max(actual, 0)
                }
            }
        }

        return summary
    }

    static func weeklySpending(
        for date: Date,
        entries: [MoneyEntry],
        tasks: [LifeTask],
        currencyCode: String,
        calendar: Calendar = .current
    ) -> Double {
        let interval = weekInterval(containing: date, calendar: calendar)
        let normalizedCurrency = MoneyCurrency.normalized(currencyCode)
        let linkedEntryTaskIDs = Set(entries.compactMap(\.linkedTaskId))
        let entrySpend = entries
            .filter { MoneyCurrency.normalized($0.currencyCode) == normalizedCurrency }
            .reduce(0) { partial, entry in
                guard entry.includeInMonthlySpending else { return partial }
                switch entry.type {
                case .expense, .debtPayment:
                    return partial + amount(for: entry, in: interval, calendar: calendar)
                case .income, .savings, .transfer:
                    return partial
                }
            }

        let taskSpend = tasks
            .filter {
                $0.financialEnabled &&
                !$0.isDeleted &&
                $0.financialType == .expense &&
                $0.includeInMonthlySpending &&
                MoneyCurrency.normalized($0.currencyCode) == normalizedCurrency &&
                !linkedEntryTaskIDs.contains($0.id)
            }
            .reduce(0) { partial, task in
                let date = task.paymentDate ?? task.dueDate
                guard intervalContains(interval, date), let actual = task.actualAmount else { return partial }
                return partial + max(actual, 0)
            }

        return entrySpend + taskSpend
    }

    static func categoryTotals(
        for date: Date,
        entries: [MoneyEntry],
        tasks: [LifeTask],
        currencyCode: String,
        calendar: Calendar = .current
    ) -> [MoneyCategoryTotal] {
        let normalizedCurrency = MoneyCurrency.normalized(currencyCode)
        let interval = monthInterval(containing: date, calendar: calendar)
        let linkedEntryTaskIDs = Set(entries.compactMap(\.linkedTaskId))
        var buckets: [String: MoneyCategoryTotal] = [:]

        func add(category: String, kind: MoneyTransactionType, planned: Double = 0, actual: Double = 0) {
            let cleanedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Uncategorized" : category
            let key = "\(kind.rawValue)-\(cleanedCategory)"
            var bucket = buckets[key] ?? MoneyCategoryTotal(
                category: cleanedCategory,
                planned: 0,
                actual: 0,
                currencyCode: normalizedCurrency,
                kind: kind
            )
            bucket.planned += planned
            bucket.actual += actual
            buckets[key] = bucket
        }

        for entry in entries where MoneyCurrency.normalized(entry.currencyCode) == normalizedCurrency {
            let actual = amount(for: entry, in: interval, calendar: calendar)
            guard actual > 0 else { continue }
            add(category: entry.category, kind: entry.type, actual: actual)
        }

        for task in tasks where task.financialEnabled && !task.isDeleted && MoneyCurrency.normalized(task.currencyCode) == normalizedCurrency {
            let date = task.paymentDate ?? task.dueDate
            guard intervalContains(interval, date) else { continue }
            let kind = task.financialType.moneyEntryType
            let actual = linkedEntryTaskIDs.contains(task.id) ? 0 : max(task.actualAmount ?? 0, 0)
            add(
                category: task.budgetCategory.isEmpty ? task.category.title : task.budgetCategory,
                kind: kind,
                planned: max(task.plannedAmount, 0),
                actual: actual
            )
        }

        return buckets.values.sorted {
            if $0.kind == $1.kind {
                return $0.actual > $1.actual
            }
            return $0.kind.rawValue < $1.kind.rawValue
        }
    }

    static func plannedBills(
        for date: Date,
        tasks: [LifeTask],
        currencyCode: String,
        calendar: Calendar = .current
    ) -> [MoneyBillSnapshot] {
        let interval = monthInterval(containing: date, calendar: calendar)
        let normalizedCurrency = MoneyCurrency.normalized(currencyCode)
        return tasks
            .filter {
                $0.financialEnabled &&
                !$0.isDeleted &&
                $0.financialType == .expense &&
                MoneyCurrency.normalized($0.currencyCode) == normalizedCurrency &&
                intervalContains(interval, $0.paymentDate ?? $0.dueDate)
            }
            .sorted { ($0.paymentDate ?? $0.dueDate) < ($1.paymentDate ?? $1.dueDate) }
            .map { task in
                MoneyBillSnapshot(
                    id: task.id,
                    title: task.title,
                    category: task.budgetCategory.isEmpty ? task.category.title : task.budgetCategory,
                    plannedAmount: max(task.plannedAmount, 0),
                    actualAmount: task.actualAmount,
                    currencyCode: normalizedCurrency,
                    dueDate: task.paymentDate ?? task.dueDate,
                    status: billStatus(for: task, referenceDate: date, calendar: calendar)
                )
            }
    }

    static func impactPreview(
        type: MoneyTransactionType,
        amount: Double,
        category: String,
        startDate: Date,
        endDate: Date?,
        dateScope: MoneyDateScope,
        includeInMonthlySpending: Bool,
        distributeAcrossPeriod: Bool,
        currencyCode: String,
        calendar: Calendar = .current
    ) -> MoneyImpactPreview {
        let entry = MoneyEntry(
            type: type,
            amount: max(amount, 0),
            currencyCode: currencyCode,
            category: category,
            dateScope: dateScope,
            startDate: startDate,
            endDate: endDate,
            includeInMonthlySpending: includeInMonthlySpending,
            distributeAcrossPeriod: distributeAcrossPeriod
        )
        let monthAmount = Self.amount(for: entry, in: monthInterval(containing: startDate, calendar: calendar), calendar: calendar)
        let weekAmount = Self.amount(for: entry, in: weekInterval(containing: startDate, calendar: calendar), calendar: calendar)
        let spendingAmount: Double
        switch type {
        case .expense, .debtPayment:
            spendingAmount = includeInMonthlySpending ? monthAmount : 0
        case .income, .savings, .transfer:
            spendingAmount = 0
        }

        return MoneyImpactPreview(
            monthlySpendingDelta: spendingAmount,
            weeklySpendingDelta: (type == .expense || type == .debtPayment) && includeInMonthlySpending ? weekAmount : 0,
            categoryDelta: monthAmount,
            savingsDelta: type == .savings ? monthAmount : 0,
            currencyCode: MoneyCurrency.normalized(currencyCode)
        )
    }

    static func amount(for entry: MoneyEntry, in interval: DateInterval, calendar: Calendar = .current) -> Double {
        if entry.distributeAcrossPeriod {
            let entryInterval = inclusiveInterval(start: entry.startDate, end: entry.effectiveEndDate(calendar: calendar), calendar: calendar)
            let overlapStart = max(entryInterval.start, interval.start)
            let overlapEnd = min(entryInterval.end, interval.end)
            let overlap = overlapEnd.timeIntervalSince(overlapStart)
            guard overlap > 0, entryInterval.duration > 0 else { return 0 }
            return max(entry.amount, 0) * (overlap / entryInterval.duration)
        }

        return intervalContains(interval, entry.startDate) ? max(entry.amount, 0) : 0
    }

    static func monthTitle(for date: Date) -> String {
        date.formatted(Date.FormatStyle().month(.wide).year())
    }

    static func projectionPoints(
        from startDate: Date,
        days: Int,
        entries: [MoneyEntry],
        tasks: [LifeTask],
        currencyCode: String,
        calendar: Calendar = .current
    ) -> [MoneyProjectionPoint] {
        let normalizedCurrency = MoneyCurrency.normalized(currencyCode)
        let startDay = calendar.startOfDay(for: startDate)
        let monthSummary = monthlySummary(for: startDate, entries: entries, tasks: tasks, currencyCode: normalizedCurrency, calendar: calendar)
        var runningBalance = monthSummary.actualRemaining
        let linkedEntryTaskIDs = Set(entries.compactMap(\.linkedTaskId))

        return (0..<max(days, 1)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }

            let dayInterval = DateInterval(start: day, end: nextDay)

            for entry in entries where MoneyCurrency.normalized(entry.currencyCode) == normalizedCurrency {
                let value = amount(for: entry, in: dayInterval, calendar: calendar)
                guard value > 0 else { continue }
                switch entry.type {
                case .income:
                    runningBalance += value
                case .expense, .debtPayment:
                    if entry.includeInMonthlySpending { runningBalance -= value }
                case .savings:
                    runningBalance -= value
                case .transfer:
                    break
                }
            }

            for task in tasks where task.financialEnabled && !task.isDeleted && MoneyCurrency.normalized(task.currencyCode) == normalizedCurrency {
                guard !linkedEntryTaskIDs.contains(task.id) else { continue }
                let taskDate = task.paymentDate ?? task.dueDate
                guard intervalContains(dayInterval, taskDate) else { continue }
                let amount = max(task.actualAmount ?? task.plannedAmount, 0)
                switch task.financialType {
                case .income, .reimbursement:
                    runningBalance += amount
                case .expense:
                    if task.includeInMonthlySpending { runningBalance -= amount }
                case .savings:
                    runningBalance -= amount
                }
            }

            return MoneyProjectionPoint(date: day, balance: runningBalance)
        }
    }

    private static func billStatus(for task: LifeTask, referenceDate: Date, calendar: Calendar) -> MoneyBillStatus {
        if task.actualAmount != nil || task.isCompleted {
            return .paid
        }

        let dueDate = task.paymentDate ?? task.dueDate
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let dueDay = calendar.startOfDay(for: dueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: startOfToday, to: dueDay).day ?? 0
        return daysUntilDue < 0 || daysUntilDue <= 3 ? .atRisk : .upcoming
    }

    private static func inclusiveInterval(start: Date, end: Date, calendar: Calendar) -> DateInterval {
        let normalizedStart = calendar.startOfDay(for: min(start, end))
        let normalizedEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(start, end))) ?? max(start, end)
        return DateInterval(start: normalizedStart, end: normalizedEnd)
    }

    static func intervalContains(_ interval: DateInterval, _ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }
}

@MainActor
enum MoneySeedData {
    private static let seedKey = "MoneySeedData.seeded.v1"

    static func seedIfNeeded(modelContext: ModelContext, entries: [MoneyEntry], tasks: [LifeTask]) {
        guard !UserDefaults.standard.bool(forKey: seedKey),
              entries.isEmpty,
              !tasks.contains(where: \.financialEnabled) else {
            return
        }

        let currencyCode = MoneyCurrency.defaultCode
        for entry in sampleEntries(currencyCode: currencyCode) {
            modelContext.insert(entry)
        }
        for task in sampleFinanceTasks(currencyCode: currencyCode) {
            modelContext.insert(task)
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: seedKey)
    }

    private static func sampleEntries(currencyCode: String) -> [MoneyEntry] {
        [
            MoneyEntry(type: .income, amount: 26_400, currencyCode: currencyCode, category: "Income", dateScope: .day, startDate: date(day: 20), notes: "Salary", includeInMonthlySpending: false),
            MoneyEntry(type: .expense, amount: 456, currencyCode: currencyCode, category: "Groceries", dateScope: .day, startDate: date(day: 22, hour: 11), notes: "Woolworths Green Point"),
            MoneyEntry(type: .expense, amount: 87, currencyCode: currencyCode, category: "Transport", dateScope: .day, startDate: date(day: 22, hour: 8), notes: "Uber trip"),
            MoneyEntry(type: .expense, amount: 179, currencyCode: currencyCode, category: "Subscriptions", dateScope: .day, startDate: date(day: 21, hour: 18), notes: "Netflix"),
            MoneyEntry(type: .savings, amount: 1_500, currencyCode: currencyCode, category: "Emergency Fund", dateScope: .month, startDate: date(day: 25), distributeAcrossPeriod: false)
        ]
    }

    private static func sampleFinanceTasks(currencyCode: String) -> [LifeTask] {
        [
            sampleTask(title: "Rent", category: "Bills", planned: 6_500, actual: nil, dueDay: 5, currencyCode: currencyCode),
            sampleTask(title: "Vodacom Fibre", category: "Bills", planned: 739, actual: 739, dueDay: 7, currencyCode: currencyCode),
            sampleTask(title: "Electricity", category: "Bills", planned: 1_350, actual: 1_451, dueDay: 25, currencyCode: currencyCode),
            sampleTask(title: "School Fees", category: "Kids", planned: 1_800, actual: nil, dueDay: 20, currencyCode: currencyCode)
        ]
    }

    private static func sampleTask(
        title: String,
        category: String,
        planned: Double,
        actual: Double?,
        dueDay: Int,
        currencyCode: String
    ) -> LifeTask {
        LifeTask(
            title: title,
            category: .finance,
            dueDate: date(day: dueDay, hour: 9),
            isCompleted: actual != nil,
            notes: "Monthly finance item seeded for the money dashboard.",
            recurrence: .monthly,
            estimatedDurationMinutes: 15,
            financialEnabled: true,
            financialType: .expense,
            plannedAmount: planned,
            actualAmount: actual,
            currencyCode: currencyCode,
            budgetCategory: category,
            paymentDate: date(day: dueDay, hour: 9),
            linkedBudgetId: MoneyLinkOption.monthlyEssentials.budgetId,
            includeInMonthlySpending: true,
            markPlannedOnCreate: true,
            financialNotes: actual == nil ? "" : "Paid and reconciled.",
            createdAt: date(day: 1),
            updatedAt: Date()
        )
    }

    private static func date(day: Int, hour: Int = 9) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        let range = calendar.range(of: .day, in: .month, for: now) ?? 1..<29
        components.day = min(max(day, range.lowerBound), range.upperBound - 1)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? now
    }
}
