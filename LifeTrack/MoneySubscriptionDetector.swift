//
//  MoneySubscriptionDetector.swift
//  LifeTrack
//
//  Scans MoneyEntry rows for repeating merchant + amount patterns and
//  surfaces them as suggestions to convert into RecurringMoneyTransaction
//  templates. Pure detection logic; persistence of dismissals is keyed by
//  the suggestion fingerprint so noise doesn't grow back after dismissal.
//

import Foundation

struct MoneySubscriptionSuggestion: Identifiable, Equatable {
    /// Stable fingerprint used both as identity and as the dismissal key.
    var id: String
    var label: String
    var category: String
    var currencyCode: String
    var averageAmount: Double
    var occurrences: Int
    var cadence: RecurringMoneyCadence
    var firstSeen: Date
    var lastSeen: Date
    var nextExpected: Date
    var matchingEntryIDs: [UUID]
}

enum MoneySubscriptionDetector {
    static let dismissalsKey = "LifeTrack.money.subscriptionDismissals.v1"
    private static let minimumOccurrences = 3
    private static let amountBucketRatio = 0.04

    static func detect(
        entries: [MoneyEntry],
        existingTemplates: [RecurringMoneyTransaction] = [],
        dismissedFingerprints: Set<String> = loadDismissals(),
        currencyCode: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MoneySubscriptionSuggestion] {
        let normalizedCurrency = MoneyCurrency.normalized(currencyCode)
        let candidates = entries.filter { entry in
            guard MoneyCurrency.normalized(entry.currencyCode) == normalizedCurrency else { return false }
            guard entry.source != .recurring else { return false }
            switch entry.type {
            case .expense, .debtPayment: return true
            case .income, .savings, .transfer: return false
            }
        }

        let templateFingerprints = Set(existingTemplates.map { templateFingerprint($0) })

        var buckets: [String: [MoneyEntry]] = [:]
        for entry in candidates {
            let merchant = normalizedMerchant(for: entry)
            guard !merchant.isEmpty else { continue }
            let bucketAmount = bucketAmount(for: entry.amount)
            let key = "\(merchant)|\(bucketAmount)"
            buckets[key, default: []].append(entry)
        }

        var suggestions: [MoneySubscriptionSuggestion] = []
        for (_, group) in buckets where group.count >= minimumOccurrences {
            let sorted = group.sorted { $0.startDate < $1.startDate }
            guard let cadence = detectCadence(from: sorted, calendar: calendar) else { continue }

            let merchant = normalizedMerchant(for: sorted[0])
            let amounts = sorted.map(\.amount)
            let average = amounts.reduce(0, +) / Double(amounts.count)
            let lastDate = sorted.last?.startDate ?? now
            let nextExpected = cadence.nextDate(after: lastDate, calendar: calendar)

            let fingerprint = "\(merchant)|\(bucketAmount(for: average))|\(cadence.rawValue)"
            if dismissedFingerprints.contains(fingerprint) { continue }
            if templateFingerprints.contains(fingerprint) { continue }

            suggestions.append(
                MoneySubscriptionSuggestion(
                    id: fingerprint,
                    label: displayLabel(from: sorted[0]),
                    category: sorted[0].category,
                    currencyCode: normalizedCurrency,
                    averageAmount: average,
                    occurrences: sorted.count,
                    cadence: cadence,
                    firstSeen: sorted[0].startDate,
                    lastSeen: lastDate,
                    nextExpected: nextExpected,
                    matchingEntryIDs: sorted.map(\.id)
                )
            )
        }

        return suggestions.sorted { $0.averageAmount > $1.averageAmount }
    }

    static func loadDismissals() -> Set<String> {
        let raw = UserDefaults.standard.array(forKey: dismissalsKey) as? [String] ?? []
        return Set(raw)
    }

    static func dismiss(_ fingerprint: String) {
        var current = loadDismissals()
        current.insert(fingerprint)
        UserDefaults.standard.set(Array(current), forKey: dismissalsKey)
    }

    static func recurringTemplate(from suggestion: MoneySubscriptionSuggestion) -> RecurringMoneyTransaction {
        RecurringMoneyTransaction(
            label: suggestion.label,
            type: .expense,
            amount: roundedAmount(suggestion.averageAmount),
            currencyCode: suggestion.currencyCode,
            category: suggestion.category,
            cadence: suggestion.cadence,
            anchorDate: suggestion.nextExpected
        )
    }

    // MARK: - Helpers

    private static func displayLabel(from entry: MoneyEntry) -> String {
        let trimmedNotes = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            let firstLine = trimmedNotes.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmedNotes
            return firstLine
        }
        return entry.category
    }

    private static func normalizedMerchant(for entry: MoneyEntry) -> String {
        let raw: String = {
            let notes = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty { return notes }
            return entry.category
        }()

        let firstLine = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? raw
        let lowered = firstLine.lowercased()

        var result = ""
        result.reserveCapacity(lowered.count)
        for character in lowered {
            if character.isLetter || character == " " {
                result.append(character)
            } else if character == "-" || character == "_" || character == "/" || character == "." {
                result.append(" ")
            }
        }

        let collapsed = result.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(40))
    }

    private static func bucketAmount(for amount: Double) -> Int {
        let tolerance = max(amount * amountBucketRatio, 1.0)
        return Int((amount / tolerance).rounded()) * Int(tolerance.rounded())
    }

    private static func roundedAmount(_ amount: Double) -> Double {
        if amount >= 100 {
            return (amount / 1).rounded()
        }
        return (amount * 100).rounded() / 100
    }

    private static func detectCadence(
        from entries: [MoneyEntry],
        calendar: Calendar
    ) -> RecurringMoneyCadence? {
        guard entries.count >= minimumOccurrences else { return nil }
        var gaps: [Double] = []
        for index in 1..<entries.count {
            let previous = entries[index - 1].startDate
            let current = entries[index].startDate
            let days = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
            guard days > 0 else { continue }
            gaps.append(Double(days))
        }
        guard !gaps.isEmpty else { return nil }

        let median = medianValue(of: gaps)
        let stddev = standardDeviation(of: gaps, mean: gaps.reduce(0, +) / Double(gaps.count))

        // Reject wildly inconsistent spacings — likely just two unrelated charges.
        guard stddev <= max(median * 0.45, 2) else { return nil }

        switch median {
        case 0.5..<2.5:    return .daily
        case 5..<10:       return .weekly
        case 11..<18:      return .biweekly
        case 25..<35:      return .monthly
        case 350..<380:    return .yearly
        default:           return nil
        }
    }

    private static func medianValue(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        if count == 0 { return 0 }
        if count % 2 == 1 { return sorted[count / 2] }
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
    }

    private static func standardDeviation(of values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return (squaredDiffs.reduce(0, +) / Double(values.count - 1)).squareRoot()
    }

    private static func templateFingerprint(_ template: RecurringMoneyTransaction) -> String {
        let merchant = template.label.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return "\(merchant)|\(bucketAmount(for: template.amount))|\(template.cadence.rawValue)"
    }
}
