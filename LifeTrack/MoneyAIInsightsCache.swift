//
//  MoneyAIInsightsCache.swift
//  LifeTrack
//

import Foundation

enum MoneyAIInsightsCache {
    struct Entry: Codable {
        let insight: MoneyAIDeepInsight
        let fingerprint: String
        let createdAt: Date
    }

    private static let defaults = UserDefaults.standard
    private static let keyPrefix = "LifeTrack.moneyAI.deepInsight."

    static func storageKey(month: Date, currencyCode: String) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: month)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        return "\(keyPrefix)\(y)-\(String(format: "%02d", m)).\(currencyCode.uppercased())"
    }

    static func load(month: Date, currencyCode: String) -> Entry? {
        let key = storageKey(month: month, currencyCode: currencyCode)
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    static func save(_ entry: Entry, month: Date, currencyCode: String) {
        let key = storageKey(month: month, currencyCode: currencyCode)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: key)
    }

    static func fingerprint(
        summary: MoneyMonthlySummary,
        categoryTotals: [MoneyCategoryTotal],
        plannedBills: [MoneyBillSnapshot],
        projectedBalance: Double
    ) -> String {
        func r(_ v: Double) -> Int { Int((v * 100).rounded()) }

        var parts: [String] = []
        parts.append("inc:\(r(summary.actualIncome))/\(r(summary.plannedIncome))")
        parts.append("spd:\(r(summary.actualSpending))/\(r(summary.plannedSpending))")
        parts.append("sav:\(r(summary.actualSavings))/\(r(summary.plannedSavings))")
        parts.append("proj:\(r(projectedBalance))")

        let cats = categoryTotals
            .sorted { $0.id < $1.id }
            .map { "\($0.id):\(r($0.planned)):\(r($0.actual))" }
            .joined(separator: "|")
        parts.append("cats:\(cats)")

        let bills = plannedBills
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString):\($0.status.rawValue):\(r($0.plannedAmount)):\(r($0.actualAmount ?? 0))" }
            .joined(separator: "|")
        parts.append("bills:\(bills)")

        return parts.joined(separator: ";")
    }
}
