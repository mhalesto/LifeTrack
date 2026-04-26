//
//  BillAutoMatcher.swift
//  LifeTrack
//
//  Pairs bank-imported MoneyEntry rows with planned bill LifeTasks
//  by amount tolerance, due-date window, and fuzzy payee match. When
//  a match is confident, the task's actualAmount is set and the
//  entry's linkedTaskId is populated so the bill flips to "paid".
//

import Foundation
import SwiftData

struct BillMatchResult: Equatable {
    let entryID: UUID
    let taskID: UUID
}

enum BillAutoMatcher {
    /// How close (in days) the entry date must be to the bill's due date.
    static let dateWindowDays = 5

    /// Allow up to 2% (or R10 minimum) variance to absorb fees.
    static let amountTolerancePercent = 0.02
    static let amountToleranceMinimum = 10.0

    /// Run matching against all unpaid bills using the supplied entries.
    /// Mutates the SwiftData model context — caller is responsible for save().
    @discardableResult
    static func runMatch(
        entries: [MoneyEntry],
        tasks: [LifeTask],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [BillMatchResult] {
        var alreadyLinked = Set(entries.compactMap(\.linkedTaskId))
        var consumedEntryIDs = Set<UUID>()
        var results: [BillMatchResult] = []

        let unpaidBills = tasks.filter(isUnpaidBill)
        let importedExpenses = entries.filter {
            $0.source == .imported &&
            ($0.type == .expense || $0.type == .debtPayment) &&
            $0.linkedTaskId == nil
        }

        for bill in unpaidBills {
            guard !alreadyLinked.contains(bill.id) else { continue }
            let billDue = bill.paymentDate ?? bill.dueDate
            let billCurrency = MoneyCurrency.normalized(bill.currencyCode)

            let candidates = importedExpenses
                .filter { !consumedEntryIDs.contains($0.id) }
                .filter { MoneyCurrency.normalized($0.currencyCode) == billCurrency }
                .filter { isWithinDateWindow($0.startDate, target: billDue, calendar: calendar) }
                .filter { isAmountMatch(entry: $0.amount, planned: bill.plannedAmount) }

            guard let match = bestPayeeMatch(in: candidates, for: bill) else { continue }

            match.linkedTaskId = bill.id
            bill.actualAmount = match.amount
            bill.updatedAt = now

            consumedEntryIDs.insert(match.id)
            alreadyLinked.insert(bill.id)
            results.append(BillMatchResult(entryID: match.id, taskID: bill.id))
        }

        return results
    }

    private static func isUnpaidBill(_ task: LifeTask) -> Bool {
        task.financialEnabled &&
        !task.isDeleted &&
        task.financialType == .expense &&
        !task.isCompleted &&
        task.actualAmount == nil &&
        task.plannedAmount > 0
    }

    private static func isWithinDateWindow(_ date: Date, target: Date, calendar: Calendar) -> Bool {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: target)
        ).day ?? Int.max
        return abs(days) <= dateWindowDays
    }

    private static func isAmountMatch(entry: Double, planned: Double) -> Bool {
        guard planned > 0 else { return false }
        let tolerance = max(planned * amountTolerancePercent, amountToleranceMinimum)
        return abs(entry - planned) <= tolerance
    }

    /// Picks the best payee match by token overlap between entry notes/category
    /// and bill title/category. Returns nil if no candidate scores high enough.
    private static func bestPayeeMatch(in candidates: [MoneyEntry], for bill: LifeTask) -> MoneyEntry? {
        let billTokens = tokens(from: [bill.title, bill.budgetCategory, bill.category.title])
        guard !billTokens.isEmpty else { return candidates.first }

        var best: (entry: MoneyEntry, score: Int)?
        for entry in candidates {
            let entryTokens = tokens(from: [entry.notes, entry.category])
            let overlap = billTokens.intersection(entryTokens).count
            if overlap == 0 { continue }
            if best == nil || overlap > best!.score {
                best = (entry, overlap)
            }
        }

        if let best { return best.entry }

        // No payee overlap but exactly one amount/date candidate — accept it.
        return candidates.count == 1 ? candidates.first : nil
    }

    private static func tokens(from strings: [String]) -> Set<String> {
        var result = Set<String>()
        for string in strings {
            let lower = string.lowercased()
            for token in lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
                let str = String(token)
                if str.count >= 3, !stopwords.contains(str) {
                    result.insert(str)
                }
            }
        }
        return result
    }

    private static let stopwords: Set<String> = [
        "the", "and", "for", "from", "bill", "payment", "monthly",
        "auto", "debit", "card", "fee", "ltd", "pty", "inc"
    ]
}
