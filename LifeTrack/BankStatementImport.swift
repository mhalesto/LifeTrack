//
//  BankStatementImport.swift
//  LifeTrack
//
//  Pure parsing layer for bank statements. Takes extracted text, emits
//  `ParsedStatement` with transactions ready to be staged into
//  `MoneyEntry` rows (source = .imported). Keep this file free of
//  UIKit/PDFKit/SwiftUI so it stays unit-testable.
//

import Foundation

// MARK: - Models

struct ParsedTransaction: Identifiable, Equatable {
    let id: UUID
    var date: Date
    var descriptionText: String
    var detailText: String?
    var amount: Double
    var currencyCode: String
    var balanceAfter: Double?
    var suggestedCategory: String?

    init(
        id: UUID = UUID(),
        date: Date,
        descriptionText: String,
        detailText: String? = nil,
        amount: Double,
        currencyCode: String,
        balanceAfter: Double? = nil,
        suggestedCategory: String? = nil
    ) {
        self.id = id
        self.date = date
        self.descriptionText = descriptionText
        self.detailText = detailText
        self.amount = amount
        self.currencyCode = currencyCode
        self.balanceAfter = balanceAfter
        self.suggestedCategory = suggestedCategory
    }

    var isDeposit: Bool { amount > 0 }
    var moneyTransactionType: MoneyTransactionType { isDeposit ? .income : .expense }
    var absoluteAmount: Double { abs(amount) }

    func duplicateKey() -> String {
        let day = ISO8601DateFormatter.dayKey.string(from: date)
        let amountKey = String(format: "%.2f", amount)
        let desc = descriptionText
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(day)|\(amountKey)|\(desc)"
    }
}

struct ParsedStatement: Equatable {
    let bankName: String
    let accountNumber: String?
    let accountHolder: String?
    let periodStart: Date?
    let periodEnd: Date?
    let currencyCode: String
    let openingBalance: Double?
    var transactions: [ParsedTransaction]

    var totalPayments: Double {
        transactions.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount }
    }

    var totalDeposits: Double {
        transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }
}

enum BankStatementParseError: Error, Equatable {
    case unsupportedFormat
    case noTransactionsFound
    case malformed(String)
}

// MARK: - Parser protocol

protocol BankStatementParser {
    static var bankName: String { get }
    static func canParse(_ text: String) -> Bool
    static func parse(_ text: String) throws -> ParsedStatement
}

// MARK: - Dispatcher

enum BankStatementImporter {
    static let registered: [BankStatementParser.Type] = [
        StandardBankSAStatementParser.self
    ]

    static func parse(_ text: String) throws -> ParsedStatement {
        for parser in registered where parser.canParse(text) {
            return try parser.parse(text)
        }
        return try GenericBankStatementParser.parse(text)
    }
}

// MARK: - SBSA parser

enum StandardBankSAStatementParser: BankStatementParser {
    static let bankName = "Standard Bank of South Africa"

    static func canParse(_ text: String) -> Bool {
        let needles = ["standardbank.co.za", "Standard Bank", "STANDARD BANK"]
        return needles.contains { text.contains($0) }
    }

    static func parse(_ text: String) throws -> ParsedStatement {
        let lines = text.split(whereSeparator: \.isNewline).map { String($0) }
        let accountNumber = firstCapture(in: lines, pattern: #"Account number:\s*([\d\s]+)"#)?
            .trimmingCharacters(in: .whitespaces)
        let accountHolder = firstCapture(in: lines, pattern: #"Account holder:\s*(.+)"#)?
            .trimmingCharacters(in: .whitespaces)
        let periodStart = BankStatementDates.sbsaShort(firstCapture(in: lines, pattern: #"From:\s*(\d{1,2} [A-Za-z]{3} \d{2})"#))
        let periodEnd = BankStatementDates.sbsaShort(firstCapture(in: lines, pattern: #"To:\s*(\d{1,2} [A-Za-z]{3} \d{2})"#))
        let openingBalance = parseOpeningBalance(in: lines)

        var transactions: [ParsedTransaction] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard let dateMatch = Self.dateLineRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  dateMatch.numberOfRanges >= 3,
                  let dateRange = Range(dateMatch.range(at: 1), in: line),
                  let tailRange = Range(dateMatch.range(at: 2), in: line) else {
                index += 1
                continue
            }

            guard let date = BankStatementDates.sbsaShort(String(line[dateRange])) else {
                index += 1
                continue
            }

            var description = String(line[tailRange]).trimmingCharacters(in: .whitespaces)
            var detailLines: [String] = []
            var amountLine: String?
            var lookahead = index + 1

            while lookahead < lines.count {
                let candidate = lines[lookahead].trimmingCharacters(in: .whitespaces)
                if candidate.isEmpty {
                    lookahead += 1
                    continue
                }
                if Self.amountLineRegex.firstMatch(in: candidate, range: NSRange(candidate.startIndex..., in: candidate)) != nil {
                    amountLine = candidate
                    lookahead += 1
                    break
                }
                if Self.dateLineRegex.firstMatch(in: candidate, range: NSRange(candidate.startIndex..., in: candidate)) != nil {
                    break
                }
                detailLines.append(candidate)
                lookahead += 1
            }

            guard let amountLine,
                  let (amount, balance) = parseAmountAndBalance(from: amountLine) else {
                index = max(index + 1, lookahead)
                continue
            }

            if description.isEmpty, let first = detailLines.first {
                description = first
                detailLines.removeFirst()
            }

            let detailText = detailLines.isEmpty ? nil : detailLines.joined(separator: " ")

            transactions.append(ParsedTransaction(
                date: date,
                descriptionText: description,
                detailText: detailText,
                amount: amount,
                currencyCode: "ZAR",
                balanceAfter: balance,
                suggestedCategory: BankStatementCategorizer.category(
                    for: description,
                    detail: detailText
                )
            ))

            index = lookahead
        }

        guard !transactions.isEmpty else { throw BankStatementParseError.noTransactionsFound }

        return ParsedStatement(
            bankName: bankName,
            accountNumber: accountNumber,
            accountHolder: accountHolder,
            periodStart: periodStart,
            periodEnd: periodEnd,
            currencyCode: "ZAR",
            openingBalance: openingBalance,
            transactions: transactions
        )
    }

    private static let dateLineRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"^(\d{1,2}\s+[A-Za-z]{3}\s+\d{2})\s*(.*)$"#)
    }()

    private static let amountLineRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"^-?\d[\d,]*\.\d{2}\s+-?\d[\d,]*\.\d{2}$"#)
    }()

    private static func parseAmountAndBalance(from line: String) -> (amount: Double, balance: Double)? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 2,
              let amount = Double(parts[0].replacingOccurrences(of: ",", with: "")),
              let balance = Double(parts[1].replacingOccurrences(of: ",", with: "")) else {
            return nil
        }
        return (amount, balance)
    }

    private static func parseOpeningBalance(in lines: [String]) -> Double? {
        guard let idx = lines.firstIndex(where: { $0.uppercased().contains("STATEMENT OPENING BALANCE") }) else {
            return nil
        }
        let candidates = [lines[idx], idx + 1 < lines.count ? lines[idx + 1] : ""]
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let trailing = trimmed.split(separator: " ").last.map(String.init) ?? trimmed
            if let value = Double(trailing.replacingOccurrences(of: ",", with: "")) {
                return value
            }
        }
        return nil
    }

    private static func firstCapture(in lines: [String], pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range),
               match.numberOfRanges >= 2,
               let captured = Range(match.range(at: 1), in: line) {
                return String(line[captured])
            }
        }
        return nil
    }
}

// MARK: - Generic fallback

enum GenericBankStatementParser {
    static let bankName = "Bank Statement"

    static func parse(_ text: String) throws -> ParsedStatement {
        let lines = text.split(whereSeparator: \.isNewline).map { String($0) }
        var transactions: [ParsedTransaction] = []

        for line in lines {
            guard let transaction = parseLine(line) else { continue }
            transactions.append(transaction)
        }

        guard !transactions.isEmpty else { throw BankStatementParseError.noTransactionsFound }

        return ParsedStatement(
            bankName: bankName,
            accountNumber: nil,
            accountHolder: nil,
            periodStart: transactions.map(\.date).min(),
            periodEnd: transactions.map(\.date).max(),
            currencyCode: MoneyCurrency.defaultCode,
            openingBalance: nil,
            transactions: transactions
        )
    }

    private static let combinedLineRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"^(\d{1,4}[/\-\. ][A-Za-z0-9]{1,4}[/\-\. ]\d{1,4})\s+(.+?)\s+(-?\d[\d,]*\.\d{2})$"#)
    }()

    private static func parseLine(_ line: String) -> ParsedTransaction? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = combinedLineRegex.firstMatch(in: trimmed, range: range),
              match.numberOfRanges >= 4,
              let dateRange = Range(match.range(at: 1), in: trimmed),
              let descRange = Range(match.range(at: 2), in: trimmed),
              let amountRange = Range(match.range(at: 3), in: trimmed) else {
            return nil
        }
        guard let date = BankStatementDates.flexible(String(trimmed[dateRange])) else { return nil }
        let description = String(trimmed[descRange])
        guard let amount = Double(String(trimmed[amountRange]).replacingOccurrences(of: ",", with: "")) else {
            return nil
        }
        return ParsedTransaction(
            date: date,
            descriptionText: description,
            amount: amount,
            currencyCode: MoneyCurrency.defaultCode,
            suggestedCategory: BankStatementCategorizer.category(for: description, detail: nil)
        )
    }
}

// MARK: - Date helpers

enum BankStatementDates {
    private static let sbsaShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_ZA_POSIX")
        f.timeZone = TimeZone(identifier: "Africa/Johannesburg")
        f.dateFormat = "d MMM yy"
        return f
    }()

    private static let flexibleFormatters: [DateFormatter] = {
        let patterns = ["d MMM yy", "d MMM yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy", "dd.MM.yyyy"]
        return patterns.map { pattern in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = pattern
            return f
        }
    }()

    static func sbsaShort(_ string: String?) -> Date? {
        guard let string else { return nil }
        return sbsaShortFormatter.date(from: string.trimmingCharacters(in: .whitespaces))
    }

    static func flexible(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        for formatter in flexibleFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
}

extension ISO8601DateFormatter {
    static let dayKey: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}

// MARK: - Categorizer

enum BankStatementCategorizer {
    static func category(for description: String, detail: String?) -> String? {
        let haystack = "\(description) \(detail ?? "")".uppercased()
        for (keyword, category) in rules {
            if haystack.contains(keyword) {
                return category
            }
        }
        return nil
    }

    private static let rules: [(String, String)] = [
        ("EXCESS INTEREST", "Bank fees"),
        ("FIXED MONTHLY FEE", "Bank fees"),
        ("MEMBERSHIP FEE", "Bank fees"),
        ("UCOUNT", "Bank fees"),
        ("POS DECLINED", "Bank fees"),
        ("ATM", "Cash withdrawal"),
        ("IB TRANSFER FROM", "Transfer in"),
        ("IB TRANSFER TO", "Transfer out"),
        ("IMMEDIATE PAYMENT", "Transfer out"),
        ("DEBIT ORDER", "Debit order"),
        ("SALARY", "Income"),
        ("MTN", "Telecoms"),
        ("VODACOM", "Telecoms"),
        ("TELKOM", "Telecoms"),
        ("CELL C", "Telecoms"),
        ("PREPAID", "Telecoms"),
        ("ESKOM", "Utilities"),
        ("MUNICIPALITY", "Utilities"),
        ("WATER", "Utilities"),
        ("CHECKERS", "Groceries"),
        ("PICK N PAY", "Groceries"),
        ("WOOLWORTHS", "Groceries"),
        ("SPAR", "Groceries"),
        ("UBER", "Transport"),
        ("BOLT", "Transport"),
        ("FUEL", "Transport"),
        ("PETROL", "Transport"),
        ("SHELL", "Transport"),
        ("BP ", "Transport"),
        ("NETFLIX", "Subscriptions"),
        ("SPOTIFY", "Subscriptions"),
        ("APPLE.COM", "Subscriptions"),
        ("GOOGLE", "Subscriptions"),
        ("GODADD", "Subscriptions"),
        ("AWS", "Subscriptions"),
        ("MCDONALD", "Dining"),
        ("KFC", "Dining"),
        ("NANDO", "Dining"),
        ("STEERS", "Dining"),
        ("FOOD", "Dining"),
        ("RESTAURANT", "Dining")
    ]
}
