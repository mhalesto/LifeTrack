//
//  AppMaintenanceCoordinator.swift
//  LifeTrack
//
//  Centralizes launch / foreground maintenance so we can avoid
//  re-running broad side effects when the underlying data has not
//  materially changed.
//

import Foundation
import SwiftData

enum AppMaintenanceTrigger {
    case initialLaunch
    case sceneBecameActive
}

struct AppMaintenanceSnapshot: Equatable {
    let dayStamp: Int
    let recurringTemplateDigest: Int
    let recurringTaskDigest: Int
    let billMatchingDigest: Int
    let moneyPresentationDigest: Int
    let spotlightDigest: Int

    init(
        dayStamp: Int,
        recurringTemplateDigest: Int,
        recurringTaskDigest: Int,
        billMatchingDigest: Int,
        moneyPresentationDigest: Int,
        spotlightDigest: Int
    ) {
        self.dayStamp = dayStamp
        self.recurringTemplateDigest = recurringTemplateDigest
        self.recurringTaskDigest = recurringTaskDigest
        self.billMatchingDigest = billMatchingDigest
        self.moneyPresentationDigest = moneyPresentationDigest
        self.spotlightDigest = spotlightDigest
    }

    static func capture(
        recurringTemplates: [RecurringMoneyTransaction],
        moneyEntries: [MoneyEntry],
        tasks: [LifeTask],
        now: Date,
        calendar: Calendar = .current
    ) -> AppMaintenanceSnapshot {
        AppMaintenanceSnapshot(
            dayStamp: dayStamp(for: now, calendar: calendar),
            recurringTemplateDigest: recurringTemplateDigest(for: recurringTemplates),
            recurringTaskDigest: recurringTaskDigest(for: tasks),
            billMatchingDigest: billMatchingDigest(for: moneyEntries, tasks: tasks),
            moneyPresentationDigest: moneyPresentationDigest(for: moneyEntries, tasks: tasks),
            spotlightDigest: spotlightDigest(for: tasks)
        )
    }

    private static func recurringTemplateDigest(for templates: [RecurringMoneyTransaction]) -> Int {
        var hasher = Hasher()
        for template in templates.sorted(by: { $0.id.uuidString < $1.id.uuidString }) where template.isActive {
            hasher.combine(template.id)
            hasher.combine(template.label)
            hasher.combine(template.typeRawValue)
            hasher.combine(template.category)
            hasher.combine(template.cadenceRawValue)
            hasher.combine(template.amount.bitPattern)
            hasher.combine(template.currencyCode)
            hasher.combine(template.anchorDate.timeIntervalSinceReferenceDate)
            hasher.combine(template.nextRunDate.timeIntervalSinceReferenceDate)
            hasher.combine(template.endDate?.timeIntervalSinceReferenceDate)
            hasher.combine(template.includeInMonthlySpending)
        }
        return hasher.finalize()
    }

    private static func recurringTaskDigest(for tasks: [LifeTask]) -> Int {
        var hasher = Hasher()
        for task in tasks.sorted(by: { $0.id.uuidString < $1.id.uuidString })
        where task.recurrence != .none && !task.isCompleted && task.deletedAt == nil {
            hasher.combine(task.id)
            hasher.combine(task.recurrenceRawValue)
            hasher.combine(task.dueDate.timeIntervalSinceReferenceDate)
            hasher.combine(task.isCompleted)
            hasher.combine(task.deletedAt?.timeIntervalSinceReferenceDate)
        }
        return hasher.finalize()
    }

    private static func billMatchingDigest(for entries: [MoneyEntry], tasks: [LifeTask]) -> Int {
        var hasher = Hasher()

        for task in tasks.sorted(by: { $0.id.uuidString < $1.id.uuidString })
        where task.financialEnabled &&
            task.financialType == .expense &&
            !task.isDeleted &&
            !task.isCompleted &&
            task.actualAmount == nil &&
            task.plannedAmount > 0 {
            hasher.combine(task.id)
            hasher.combine(task.title)
            hasher.combine(task.budgetCategory)
            hasher.combine(task.categoryRawValue)
            hasher.combine(task.plannedAmount.bitPattern)
            hasher.combine(task.currencyCode)
            hasher.combine((task.paymentDate ?? task.dueDate).timeIntervalSinceReferenceDate)
        }

        for entry in entries.sorted(by: { $0.id.uuidString < $1.id.uuidString })
        where entry.source == .imported &&
            (entry.type == .expense || entry.type == .debtPayment) &&
            entry.linkedTaskId == nil {
            hasher.combine(entry.id)
            hasher.combine(entry.amount.bitPattern)
            hasher.combine(entry.currencyCode)
            hasher.combine(entry.category)
            hasher.combine(entry.startDate.timeIntervalSinceReferenceDate)
            hasher.combine(entry.notes)
        }

        return hasher.finalize()
    }

    private static func moneyPresentationDigest(for entries: [MoneyEntry], tasks: [LifeTask]) -> Int {
        var hasher = Hasher()
        hasher.combine(UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.moneyCurrencyCode))

        for task in tasks.sorted(by: { $0.id.uuidString < $1.id.uuidString }) where task.financialEnabled && !task.isDeleted {
            hasher.combine(task.id)
            hasher.combine(task.title)
            hasher.combine(task.financialTypeRawValue)
            hasher.combine(task.plannedAmount.bitPattern)
            hasher.combine(task.actualAmount?.bitPattern)
            hasher.combine(task.currencyCode)
            hasher.combine(task.includeInMonthlySpending)
            hasher.combine(task.isCompleted)
            hasher.combine((task.paymentDate ?? task.dueDate).timeIntervalSinceReferenceDate)
        }

        for entry in entries.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(entry.id)
            hasher.combine(entry.typeRawValue)
            hasher.combine(entry.amount.bitPattern)
            hasher.combine(entry.currencyCode)
            hasher.combine(entry.category)
            hasher.combine(entry.startDate.timeIntervalSinceReferenceDate)
            hasher.combine(entry.endDate?.timeIntervalSinceReferenceDate)
            hasher.combine(entry.includeInMonthlySpending)
            hasher.combine(entry.linkedTaskId)
        }

        return hasher.finalize()
    }

    private static func spotlightDigest(for tasks: [LifeTask]) -> Int {
        var hasher = Hasher()
        for task in tasks.sorted(by: { $0.id.uuidString < $1.id.uuidString }) where !task.isDeleted {
            hasher.combine(task.id)
            hasher.combine(task.title)
            hasher.combine(String(task.notes.prefix(140)))
            hasher.combine(task.categoryRawValue)
            hasher.combine(task.recurrenceRawValue)
            hasher.combine(task.financialEnabled)
            hasher.combine(task.dueDate.timeIntervalSinceReferenceDate)
        }
        return hasher.finalize()
    }

    private static func dayStamp(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return (components.year ?? 0) * 10_000
            + (components.month ?? 0) * 100
            + (components.day ?? 0)
    }
}

struct AppMaintenancePlan: Equatable {
    let runRecurringMoneyExpansion: Bool
    let runRecurringTaskCatchUp: Bool
    let runBillAutoMatch: Bool
    let publishMoneyOutputs: Bool
    let reindexSpotlight: Bool

    var shouldRunAnyWork: Bool {
        runRecurringMoneyExpansion || runRecurringTaskCatchUp || runBillAutoMatch || publishMoneyOutputs || reindexSpotlight
    }

    static func make(
        previous: AppMaintenanceSnapshot?,
        current: AppMaintenanceSnapshot,
        trigger: AppMaintenanceTrigger
    ) -> AppMaintenancePlan {
        guard let previous else {
            return AppMaintenancePlan(
                runRecurringMoneyExpansion: true,
                runRecurringTaskCatchUp: true,
                runBillAutoMatch: true,
                publishMoneyOutputs: true,
                reindexSpotlight: true
            )
        }

        let dayChanged = previous.dayStamp != current.dayStamp
        let recurringMoneyChanged = previous.recurringTemplateDigest != current.recurringTemplateDigest
        let recurringTasksChanged = previous.recurringTaskDigest != current.recurringTaskDigest
        let billMatchChanged = previous.billMatchingDigest != current.billMatchingDigest
        let moneyPresentationChanged = previous.moneyPresentationDigest != current.moneyPresentationDigest
        let spotlightChanged = previous.spotlightDigest != current.spotlightDigest

        let runRecurringMoneyExpansion = dayChanged || recurringMoneyChanged
        let runRecurringTaskCatchUp = dayChanged || recurringTasksChanged
        let runBillAutoMatch = billMatchChanged || trigger == .initialLaunch
        let publishMoneyOutputs = dayChanged || moneyPresentationChanged || runRecurringMoneyExpansion || runBillAutoMatch
        let reindexSpotlight = spotlightChanged || runRecurringTaskCatchUp

        return AppMaintenancePlan(
            runRecurringMoneyExpansion: runRecurringMoneyExpansion,
            runRecurringTaskCatchUp: runRecurringTaskCatchUp,
            runBillAutoMatch: runBillAutoMatch,
            publishMoneyOutputs: publishMoneyOutputs,
            reindexSpotlight: reindexSpotlight
        )
    }
}

@MainActor
final class AppMaintenanceCoordinator {
    static let shared = AppMaintenanceCoordinator()

    private var lastSnapshot: AppMaintenanceSnapshot?

    private init() {}

    func run(
        trigger: AppMaintenanceTrigger,
        modelContext: ModelContext,
        recurringTemplates: [RecurringMoneyTransaction],
        moneyEntries: [MoneyEntry],
        tasks: [LifeTask],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let initialSnapshot = AppMaintenanceSnapshot.capture(
            recurringTemplates: recurringTemplates,
            moneyEntries: moneyEntries,
            tasks: tasks,
            now: now,
            calendar: calendar
        )
        let plan = AppMaintenancePlan.make(previous: lastSnapshot, current: initialSnapshot, trigger: trigger)

        guard plan.shouldRunAnyWork else {
            lastSnapshot = initialSnapshot
            return
        }

        if plan.runRecurringMoneyExpansion {
            _ = RecurringMoneyExpander.runPendingExpansions(
                templates: recurringTemplates.filter(\.isActive),
                modelContext: modelContext,
                now: now,
                calendar: calendar
            )
        }

        if plan.runRecurringTaskCatchUp {
            _ = RecurringTaskCatchUp.runCatchUp(
                tasks: tasks,
                modelContext: modelContext,
                now: now,
                calendar: calendar
            )
        }

        if plan.runBillAutoMatch {
            let matched = BillAutoMatcher.runMatch(
                entries: moneyEntries,
                tasks: tasks,
                now: now,
                calendar: calendar
            )
            if !matched.isEmpty {
                try? modelContext.save()
            }
        }

        let latestTasks: [LifeTask]
        let latestEntries: [MoneyEntry]
        if plan.publishMoneyOutputs || plan.reindexSpotlight {
            latestTasks = fetchTasks(using: modelContext)
            latestEntries = fetchMoneyEntries(using: modelContext)
        } else {
            latestTasks = tasks
            latestEntries = moneyEntries
        }

        if plan.publishMoneyOutputs {
            publishMoneyOutputs(entries: latestEntries, tasks: latestTasks, now: now, calendar: calendar)
        }

        if plan.reindexSpotlight {
            TaskSpotlightIndexer.reindex(latestTasks)
        }

        lastSnapshot = AppMaintenanceSnapshot.capture(
            recurringTemplates: recurringTemplates,
            moneyEntries: latestEntries,
            tasks: latestTasks,
            now: now,
            calendar: calendar
        )
    }

    private func publishMoneyOutputs(
        entries: [MoneyEntry],
        tasks: [LifeTask],
        now: Date,
        calendar: Calendar
    ) {
        let currency = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.moneyCurrencyCode)
            ?? MoneyCurrency.primaryCurrencyCode(entries: entries, tasks: tasks)

        let bills = MoneyAnalytics.plannedBills(
            for: now,
            tasks: tasks,
            currencyCode: currency,
            calendar: calendar
        )
        let summary = MoneyAnalytics.monthlySummary(
            for: now,
            entries: entries,
            tasks: tasks,
            currencyCode: currency,
            calendar: calendar
        )
        let rollovers = BudgetRollover.carryOver(
            intoMonth: now,
            entries: entries,
            tasks: tasks,
            currencyCode: currency,
            calendar: calendar
        )
        let rolloverTotal = rollovers
            .filter { $0.carryOver > 0 }
            .reduce(0) { $0 + $1.carryOver }
        let adjustedPlanned = max(summary.plannedSpending + rolloverTotal, 0)

        MoneyReminderScheduler.synchronize(
            bills: bills,
            monthlyActualSpending: summary.actualSpending,
            monthlyAdjustedPlannedSpending: adjustedPlanned,
            currencyCode: currency,
            now: now,
            calendar: calendar
        )

        let day = calendar.dateInterval(of: .day, for: now)
            ?? DateInterval(start: now, duration: 86_400)
        var spentToday: Double = 0
        for entry in entries {
            guard MoneyCurrency.normalized(entry.currencyCode) == MoneyCurrency.normalized(currency) else { continue }
            guard entry.includeInMonthlySpending else { continue }
            switch entry.type {
            case .expense, .debtPayment:
                spentToday += MoneyAnalytics.amount(for: entry, in: day, calendar: calendar)
            case .income, .savings, .transfer:
                continue
            }
        }

        let categoryTotals = MoneyAnalytics.categoryTotals(
            for: now,
            entries: entries,
            tasks: tasks,
            currencyCode: currency,
            calendar: calendar
        )
        let topExpense = categoryTotals
            .filter { $0.kind == .expense }
            .max(by: { $0.actual < $1.actual })

        MoneyWidgetSnapshotPublisher.publish(
            spentToday: spentToday,
            spentThisMonth: summary.actualSpending,
            plannedThisMonth: summary.plannedSpending,
            topCategoryName: topExpense?.category,
            topCategoryAmount: topExpense?.actual ?? 0,
            currencyCode: currency,
            referenceDate: now
        )
    }

    private func fetchTasks(using modelContext: ModelContext) -> [LifeTask] {
        let descriptor = FetchDescriptor<LifeTask>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchMoneyEntries(using modelContext: ModelContext) -> [MoneyEntry] {
        let descriptor = FetchDescriptor<MoneyEntry>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
