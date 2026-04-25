//
//  MoneyFeatureTests.swift
//  LifeTrackTests
//
//  Coverage for the recurring-transaction expander, the receipt parser
//  and the habit-task contribution path.
//

import Foundation
import Testing
@testable import LifeTrack

struct MoneyFeatureTests {

    // MARK: - RecurringMoneyExpander

    @Test func dailyTemplateProducesOneEntryPerDay() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_766_016_000) // fixed
        let template = RecurringMoneyTransaction(
            label: "Coffee",
            type: .expense,
            amount: 35,
            category: "Food",
            cadence: .daily,
            anchorDate: start
        )

        // Three days later we expect 4 entries (start day + next 3).
        let now = calendar.date(byAdding: .day, value: 3, to: start)!
        let entries = RecurringMoneyExpander.entriesToCreate(from: template, through: now, calendar: calendar)
        #expect(entries.count == 4)
        #expect(entries.first?.amount == 35)
        #expect(entries.first?.source == .recurring)
    }

    @Test func monthlyTemplateRespectsEndDate() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_766_016_000)
        let endDate = calendar.date(byAdding: .month, value: 2, to: start)!
        let template = RecurringMoneyTransaction(
            label: "Rent",
            type: .expense,
            amount: 9000,
            category: "Bills",
            cadence: .monthly,
            anchorDate: start,
            endDate: endDate
        )

        let later = calendar.date(byAdding: .year, value: 1, to: start)!
        let entries = RecurringMoneyExpander.entriesToCreate(from: template, through: later, calendar: calendar)
        #expect(entries.count == 3) // start, +1 month, +2 months
    }

    @Test func inactiveTemplateProducesNothing() {
        let template = RecurringMoneyTransaction(
            label: "Gym",
            type: .expense,
            amount: 100,
            category: "Wellness",
            cadence: .weekly,
            anchorDate: Date(timeIntervalSince1970: 1_700_000_000),
            isActive: false
        )
        let entries = RecurringMoneyExpander.entriesToCreate(from: template, through: Date())
        #expect(entries.isEmpty)
    }

    @Test func upcomingDateIsAfterNowAndAdvancesByCadence() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let template = RecurringMoneyTransaction(
            label: "Salary",
            type: .income,
            amount: 25_000,
            category: "Income",
            cadence: .monthly,
            anchorDate: start
        )

        let now = calendar.date(byAdding: .month, value: 2, to: start)!
        let upcoming = RecurringMoneyExpander.upcomingDate(for: template, after: now, calendar: calendar)
        #expect(upcoming != nil)
        if let upcoming {
            #expect(upcoming > now)
        }
    }

    @Test func endedTemplateHasNoUpcoming() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        let template = RecurringMoneyTransaction(
            label: "Trial",
            type: .expense,
            amount: 99,
            category: "Subscriptions",
            cadence: .monthly,
            anchorDate: start,
            endDate: end
        )
        let upcoming = RecurringMoneyExpander.upcomingDate(for: template, after: end.addingTimeInterval(86_400 * 60))
        #expect(upcoming == nil)
    }

    // MARK: - ReceiptParser

    @Test func receiptParserDetectsTotalAndMerchant() {
        let text = """
        Woolworths Green Point
        2025-09-12
        Bread        24.50
        Milk         18.00
        Cheese       65.00
        Subtotal    107.50
        VAT         16.13
        Total      R123.63
        """

        let draft = ReceiptParser.parse(text, defaultCurrencyCode: "ZAR")
        #expect(draft.amount == 123.63)
        #expect(draft.merchant.contains("Woolworths"))
        #expect(draft.suggestedCategory == "Groceries")
    }

    @Test func receiptParserFallsBackToLargestAmountWhenNoTotalKeyword() {
        let text = """
        Coffee Bar
        Latte 32.50
        Croissant 28.00
        45.50
        """
        let draft = ReceiptParser.parse(text, defaultCurrencyCode: "ZAR")
        #expect(draft.amount == 45.50)
    }

    @Test func receiptParserHandlesEuropeanDecimalSeparator() {
        let text = """
        Boulangerie
        Total: 12,50
        """
        let draft = ReceiptParser.parse(text, defaultCurrencyCode: "EUR")
        #expect(draft.amount == 12.50)
    }

    @Test func receiptParserExtractsDateInISOFormat() {
        let text = """
        Pick n Pay
        2025-08-15
        Total 250.00
        """
        let draft = ReceiptParser.parse(text)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: draft.date)
        #expect(comps.year == 2025)
        #expect(comps.month == 8)
        #expect(comps.day == 15)
    }

    @Test func receiptDraftBridgesToMoneyEntry() {
        let draft = ReceiptDraft(
            amount: 56.20,
            currencyCode: "ZAR",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            merchant: "Spar",
            suggestedCategory: "Groceries",
            rawText: ""
        )
        let entry = draft.makeMoneyEntry()
        #expect(entry.type == .expense)
        #expect(entry.amount == 56.20)
        #expect(entry.category == "Groceries")
        #expect(entry.source == .imported)
    }

    // MARK: - HabitEngine contributions

    @Test func habitEngineCountsContributionsTowardStreak() {
        let now = Date()
        let habit = LifeTask(
            title: "Read",
            category: .personal,
            dueDate: now.addingTimeInterval(-3600),
            isCompleted: true,
            recurrence: .daily
        )
        habit.completedAt = now.addingTimeInterval(-3600)

        let yesterday = LifeTask(
            title: "Read 30 pages of Atomic Habits",
            category: .personal,
            dueDate: now.addingTimeInterval(-86_400),
            isCompleted: true
        )
        yesterday.habitContributionID = habit.id
        yesterday.completedAt = now.addingTimeInterval(-86_400)

        let streak = HabitEngine.currentStreak(for: habit, in: [habit, yesterday])
        #expect(streak >= 2)
    }

    @Test func habitEngineIgnoresContributionsFromIncompleteTasks() {
        let now = Date()
        let habit = LifeTask(
            title: "Run",
            category: .health,
            dueDate: now,
            recurrence: .daily
        )

        let pending = LifeTask(
            title: "Quick jog",
            category: .health,
            dueDate: now.addingTimeInterval(-86_400)
        )
        pending.habitContributionID = habit.id
        // not completed

        let streak = HabitEngine.currentStreak(for: habit, in: [habit, pending])
        #expect(streak == 0)
    }

    // MARK: - MoneyAnalytics

    @Test func moneyAnalyticsAmountIncludesEntryWithinInterval() {
        let calendar = Calendar(identifier: .gregorian)
        let interval = calendar.dateInterval(of: .month, for: Date())!
        let entry = MoneyEntry(
            type: .expense,
            amount: 200,
            category: "Food",
            dateScope: .day,
            startDate: interval.start.addingTimeInterval(86_400)
        )
        let value = MoneyAnalytics.amount(for: entry, in: interval, calendar: calendar)
        #expect(value == 200)
    }

    @Test func moneyAnalyticsAmountExcludesEntryOutsideInterval() {
        let calendar = Calendar(identifier: .gregorian)
        let interval = calendar.dateInterval(of: .month, for: Date())!
        let outsideDate = interval.end.addingTimeInterval(86_400)
        let entry = MoneyEntry(
            type: .expense,
            amount: 200,
            category: "Food",
            dateScope: .day,
            startDate: outsideDate
        )
        let value = MoneyAnalytics.amount(for: entry, in: interval, calendar: calendar)
        #expect(value == 0)
    }

    // MARK: - SensitiveTextRedactor

    @Test func redactorStripsEmailAndPhone() {
        let input = "Call John at +27 82 555 1212 or john.doe@example.com"
        let redacted = SensitiveTextRedactor.redact(input)
        #expect(!redacted.contains("john.doe@example.com"))
        #expect(!redacted.contains("82 555 1212"))
        #expect(redacted.contains("[email]"))
        #expect(redacted.contains("[phone]"))
    }

    @Test func redactorStripsLongDigitRuns() {
        let input = "Account 1234567890 balance"
        let redacted = SensitiveTextRedactor.redact(input)
        #expect(!redacted.contains("1234567890"))
    }

    @Test func redactorPreservesShortNumbers() {
        let input = "Pay 50 for lunch"
        let redacted = SensitiveTextRedactor.redact(input)
        #expect(redacted.contains("50"))
    }

    // MARK: - BudgetRollover

    @Test func budgetRolloverReportsUnspentFromPreviousMonth() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now) else {
            Issue.record("Could not compute previous month")
            return
        }

        let plannedTask = LifeTask(
            title: "Groceries plan",
            category: .home,
            dueDate: previousMonthDate
        )
        plannedTask.financialEnabled = true
        plannedTask.financialType = .expense
        plannedTask.includeInMonthlySpending = true
        plannedTask.plannedAmount = 1000
        plannedTask.actualAmount = 600
        plannedTask.currencyCode = "ZAR"
        plannedTask.budgetCategory = "Groceries"

        let rollovers = BudgetRollover.carryOver(
            intoMonth: now,
            entries: [],
            tasks: [plannedTask],
            currencyCode: "ZAR",
            calendar: calendar
        )
        let match = rollovers.first { $0.category.caseInsensitiveCompare("Groceries") == .orderedSame }
        #expect(match != nil)
        #expect(match?.carryOver == 400)
    }

    @Test func budgetRolloverIgnoresOverSpendsByDefault() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now) else {
            Issue.record("Could not compute previous month")
            return
        }

        let plannedTask = LifeTask(
            title: "Eating out plan",
            category: .home,
            dueDate: previousMonthDate
        )
        plannedTask.financialEnabled = true
        plannedTask.financialType = .expense
        plannedTask.includeInMonthlySpending = true
        plannedTask.plannedAmount = 500
        plannedTask.actualAmount = 800
        plannedTask.currencyCode = "ZAR"
        plannedTask.budgetCategory = "Eating Out"

        let rollovers = BudgetRollover.carryOver(
            intoMonth: now,
            entries: [],
            tasks: [plannedTask],
            currencyCode: "ZAR",
            calendar: calendar
        )
        #expect(rollovers.allSatisfy { $0.category.caseInsensitiveCompare("Eating Out") != .orderedSame })
    }

    @Test func budgetRolloverAdjustedPlannedAddsCarryOver() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now) else {
            Issue.record("Could not compute previous month")
            return
        }

        let plannedTask = LifeTask(
            title: "Transport plan",
            category: .home,
            dueDate: previousMonthDate
        )
        plannedTask.financialEnabled = true
        plannedTask.financialType = .expense
        plannedTask.includeInMonthlySpending = true
        plannedTask.plannedAmount = 700
        plannedTask.actualAmount = 200
        plannedTask.currencyCode = "ZAR"
        plannedTask.budgetCategory = "Transport"

        let adjusted = BudgetRollover.adjustedPlanned(
            basePlanned: 700,
            category: "Transport",
            intoMonth: now,
            entries: [],
            tasks: [plannedTask],
            currencyCode: "ZAR",
            calendar: calendar
        )
        #expect(adjusted == 1200)
    }

    @Test func moneyAnalyticsDistributesAmountAcrossPeriod() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let monthInterval = calendar.dateInterval(of: .month, for: now)!
        let entryStart = monthInterval.start
        let entryEnd = calendar.date(byAdding: .day, value: 9, to: entryStart)!
        let entry = MoneyEntry(
            type: .expense,
            amount: 100,
            category: "Spread",
            dateScope: .range,
            startDate: entryStart,
            endDate: entryEnd,
            distributeAcrossPeriod: true
        )
        let week = calendar.dateInterval(of: .weekOfYear, for: entryStart)!
        let value = MoneyAnalytics.amount(for: entry, in: week, calendar: calendar)
        #expect(value > 0)
        #expect(value < 100)
    }
}
