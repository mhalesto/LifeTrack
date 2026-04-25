//
//  BudgetRollover.swift
//  LifeTrack
//
//  Envelope-style carry-over: unspent budget from the previous month
//  becomes additional headroom in the current month for the same
//  category. Negative variance (over-spend) optionally carries forward
//  as a debt against the next month.
//

import Foundation

struct BudgetRolloverResult: Equatable {
    var category: String
    var carryOver: Double          // signed; positive means unspent → extra headroom this month
    var fromMonth: DateInterval
    var intoMonth: DateInterval
}

enum BudgetRollover {
    /// Per-category unspent (positive) or over-spent (negative) amount from the
    /// month immediately preceding `intoMonth`. Only expense categories are
    /// considered. A positive value means there is leftover budget to roll in.
    static func carryOver(
        intoMonth: Date,
        entries: [MoneyEntry],
        tasks: [LifeTask],
        currencyCode: String,
        carryDeficits: Bool = false,
        calendar: Calendar = .current
    ) -> [BudgetRolloverResult] {
        let intoInterval = MoneyAnalytics.monthInterval(containing: intoMonth, calendar: calendar)
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: intoMonth) else {
            return []
        }
        let fromInterval = MoneyAnalytics.monthInterval(containing: previousMonth, calendar: calendar)

        let previousTotals = MoneyAnalytics.categoryTotals(
            for: previousMonth,
            entries: entries,
            tasks: tasks,
            currencyCode: currencyCode,
            calendar: calendar
        )

        var results: [BudgetRolloverResult] = []
        for total in previousTotals where total.kind == .expense {
            guard total.planned > 0 else { continue }
            let unspent = total.planned - total.actual
            if unspent > 0 || (carryDeficits && unspent < 0) {
                results.append(
                    BudgetRolloverResult(
                        category: total.category,
                        carryOver: unspent,
                        fromMonth: fromInterval,
                        intoMonth: intoInterval
                    )
                )
            }
        }
        return results.sorted { $0.carryOver > $1.carryOver }
    }

    /// Adjusted planned spending for a category in `intoMonth`, after applying
    /// rollover from the previous month. Pass the raw planned amount you would
    /// otherwise display for the category.
    static func adjustedPlanned(
        basePlanned: Double,
        category: String,
        intoMonth: Date,
        entries: [MoneyEntry],
        tasks: [LifeTask],
        currencyCode: String,
        carryDeficits: Bool = false,
        calendar: Calendar = .current
    ) -> Double {
        let rollovers = carryOver(
            intoMonth: intoMonth,
            entries: entries,
            tasks: tasks,
            currencyCode: currencyCode,
            carryDeficits: carryDeficits,
            calendar: calendar
        )
        let match = rollovers.first { $0.category.caseInsensitiveCompare(category) == .orderedSame }
        return max(basePlanned + (match?.carryOver ?? 0), 0)
    }
}
