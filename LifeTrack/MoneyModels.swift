//
//  MoneyModels.swift
//  LifeTrack
//
//  Created by Codex on 2026/04/23.
//

import Foundation
import SwiftData
import SwiftUI

enum MoneyTransactionType: String, CaseIterable, Codable, Identifiable {
    case expense
    case income
    case savings
    case transfer
    case debtPayment = "debt_payment"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        case .savings: "Savings"
        case .transfer: "Transfer"
        case .debtPayment: "Debt Payment"
        }
    }

    var symbolName: String {
        switch self {
        case .expense: "cart"
        case .income: "arrow.down.circle"
        case .savings: "banknote"
        case .transfer: "arrow.left.arrow.right"
        case .debtPayment: "creditcard"
        }
    }

    var tint: Color {
        switch self {
        case .expense: LifeTrackTheme.ColorPalette.danger
        case .income: LifeTrackTheme.ColorPalette.success
        case .savings: LifeTrackTheme.ColorPalette.accent
        case .transfer: LifeTrackTheme.ColorPalette.secondaryAccent
        case .debtPayment: LifeTrackTheme.ColorPalette.warning
        }
    }
}

enum TaskFinancialType: String, CaseIterable, Codable, Identifiable {
    case expense
    case income
    case savings
    case reimbursement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        case .savings: "Savings"
        case .reimbursement: "Reimbursement"
        }
    }

    var symbolName: String {
        switch self {
        case .expense: "cart"
        case .income: "arrow.down.circle"
        case .savings: "banknote"
        case .reimbursement: "arrow.uturn.backward.circle"
        }
    }

    var moneyEntryType: MoneyTransactionType {
        switch self {
        case .expense: .expense
        case .income, .reimbursement: .income
        case .savings: .savings
        }
    }

    var tint: Color {
        moneyEntryType.tint
    }
}

enum MoneyDateScope: String, CaseIterable, Codable, Identifiable {
    case day
    case range
    case week
    case month
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Day"
        case .range: "Range"
        case .week: "Week"
        case .month: "Month"
        case .custom: "Custom"
        }
    }
}

enum MoneyEntrySource: String, CaseIterable, Codable, Identifiable {
    case manual
    case task
    case recurring
    case imported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: "Manual"
        case .task: "Task"
        case .recurring: "Recurring"
        case .imported: "Imported"
        }
    }
}

enum MoneyLinkOption: String, CaseIterable, Identifiable {
    case none
    case monthlyEssentials
    case emergencyFund
    case debtPayoff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .monthlyEssentials: "Monthly Essentials"
        case .emergencyFund: "Emergency Fund"
        case .debtPayoff: "Debt Payoff"
        }
    }

    var budgetId: UUID? {
        switch self {
        case .monthlyEssentials:
            UUID(uuidString: "BD5E515D-080A-4550-84A8-B5EBD1A0F101")
        case .none, .emergencyFund, .debtPayoff:
            nil
        }
    }

    var goalId: UUID? {
        switch self {
        case .emergencyFund:
            UUID(uuidString: "C7C0458D-4C45-4F69-9B9B-A7635DEB706A")
        case .debtPayoff:
            UUID(uuidString: "79E58167-A71E-4C54-8E9D-C133355761B4")
        case .none, .monthlyEssentials:
            nil
        }
    }

    static func resolved(budgetId: UUID?, goalId: UUID?) -> MoneyLinkOption {
        if budgetId == MoneyLinkOption.monthlyEssentials.budgetId {
            return .monthlyEssentials
        }
        if goalId == MoneyLinkOption.emergencyFund.goalId {
            return .emergencyFund
        }
        if goalId == MoneyLinkOption.debtPayoff.goalId {
            return .debtPayoff
        }
        return .none
    }
}

@Model
final class MoneyEntry {
    @Attribute(.unique) var id: UUID
    var typeRawValue: String
    var amount: Double
    var currencyCode: String
    var category: String
    var dateScopeRawValue: String
    var startDate: Date
    var endDate: Date?
    var linkedTaskId: UUID?
    var notes: String
    var includeInMonthlySpending: Bool
    var distributeAcrossPeriod: Bool
    var sourceRawValue: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: MoneyTransactionType,
        amount: Double,
        currencyCode: String = MoneyCurrency.defaultCode,
        category: String,
        dateScope: MoneyDateScope,
        startDate: Date,
        endDate: Date? = nil,
        linkedTaskId: UUID? = nil,
        notes: String = "",
        includeInMonthlySpending: Bool = true,
        distributeAcrossPeriod: Bool = false,
        source: MoneyEntrySource = .manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.amount = amount
        self.currencyCode = MoneyCurrency.normalized(currencyCode)
        self.category = category
        self.dateScopeRawValue = dateScope.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.linkedTaskId = linkedTaskId
        self.notes = notes
        self.includeInMonthlySpending = includeInMonthlySpending
        self.distributeAcrossPeriod = distributeAcrossPeriod
        self.sourceRawValue = source.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: MoneyTransactionType {
        get { MoneyTransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var dateScope: MoneyDateScope {
        get { MoneyDateScope(rawValue: dateScopeRawValue) ?? .day }
        set { dateScopeRawValue = newValue.rawValue }
    }

    var source: MoneyEntrySource {
        get { MoneyEntrySource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    func effectiveEndDate(calendar: Calendar = .current) -> Date {
        if let endDate {
            return endDate
        }

        switch dateScope {
        case .day:
            return startDate
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: startDate)?.end.addingTimeInterval(-1) ?? startDate
        case .month:
            return calendar.dateInterval(of: .month, for: startDate)?.end.addingTimeInterval(-1) ?? startDate
        case .range, .custom:
            return startDate
        }
    }
}

enum MoneyCurrency {
    static var defaultCode: String {
        if let code = Locale.current.currency?.identifier, !code.isEmpty {
            return code.uppercased()
        }
        return "USD"
    }

    static var supportedCodes: [String] {
        Locale.commonISOCurrencyCodes.sorted()
    }

    static func normalized(_ code: String) -> String {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return cleaned.isEmpty ? defaultCode : cleaned
    }

    static func displayName(for code: String) -> String {
        let normalizedCode = normalized(code)
        let locale = Locale.current
        let name = locale.localizedString(forCurrencyCode: normalizedCode) ?? normalizedCode
        return "\(normalizedCode) · \(name)"
    }

    static func primaryCurrencyCode(entries: [MoneyEntry], tasks: [LifeTask]) -> String {
        let entryCurrencies = entries.map { normalized($0.currencyCode) }
        let taskCurrencies = tasks.filter(\.financialEnabled).map { normalized($0.currencyCode) }
        return (entryCurrencies + taskCurrencies).first ?? defaultCode
    }
}

enum MoneyFormatting {
    static func currency(_ amount: Double, code: String = MoneyCurrency.defaultCode) -> String {
        let normalizedCode = MoneyCurrency.normalized(code)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = normalizedCode
        formatter.locale = Locale.current
        formatter.minimumFractionDigits = amount.rounded(.down) == amount ? 0 : 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(normalizedCode) \(amount)"
    }

    static func signedCurrency(_ amount: Double, code: String = MoneyCurrency.defaultCode) -> String {
        let formatted = currency(abs(amount), code: code)
        if amount > 0 {
            return "+\(formatted)"
        }
        if amount < 0 {
            return "-\(formatted)"
        }
        return formatted
    }
}
