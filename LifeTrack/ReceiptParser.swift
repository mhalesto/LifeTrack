//
//  ReceiptParser.swift
//  LifeTrack
//
//  Pure parsing for receipt OCR text. Extracts the most likely
//  total amount, date, merchant and category. Output feeds a
//  pre-filled MoneyEntry draft (source = .imported).
//

import Foundation

struct ReceiptDraft: Equatable {
    var amount: Double
    var currencyCode: String
    var date: Date
    var merchant: String
    var suggestedCategory: String?
    var rawText: String
}

enum ReceiptParser {
    /// Best-effort extraction. Always returns a draft — falls back to
    /// reasonable defaults when fields can't be detected so the UI can
    /// still pre-fill and let the user correct.
    static func parse(
        _ ocrText: String,
        defaultCurrencyCode: String = MoneyCurrency.defaultCode,
        now: Date = Date()
    ) -> ReceiptDraft {
        let collapsed = ocrText.replacingOccurrences(of: "\r", with: "\n")
        let lines = collapsed.split(whereSeparator: \.isNewline).map { String($0) }

        let amount = extractTotal(from: lines) ?? extractLargestAmount(from: lines) ?? 0
        let merchant = extractMerchant(from: lines) ?? "Receipt"
        let date = extractDate(from: lines) ?? now
        let category = BankStatementCategorizer.category(for: merchant, detail: nil)
        let currency = extractCurrencyCode(from: lines) ?? defaultCurrencyCode

        return ReceiptDraft(
            amount: amount,
            currencyCode: currency,
            date: date,
            merchant: merchant,
            suggestedCategory: category,
            rawText: ocrText
        )
    }

    // MARK: - Total

    // Strong matches (the actual grand total) win over weak ones (subtotal, balance).
    private static let strongTotalKeywords = ["grand total", "amount due", "total"]
    private static let weakTotalKeywords = ["subtotal", "balance", "tota"]

    private static let amountRegex = try! NSRegularExpression(
        pattern: #"-?[\$£€R]?\s*\d{1,3}(?:[ ,.]\d{3})*[.,]\d{2}"#
    )

    private static func extractTotal(from lines: [String]) -> Double? {
        if let value = scanForTotal(lines: lines, keywords: strongTotalKeywords) {
            return value
        }
        return scanForTotal(lines: lines, keywords: weakTotalKeywords)
    }

    private static func scanForTotal(lines: [String], keywords: [String]) -> Double? {
        // Walk bottom-up so the grand total at the foot of the receipt wins
        // over any earlier line that mentions "total".
        for index in lines.indices.reversed() {
            let lower = lines[index].lowercased()
            // Skip lines that match a stronger or weaker bucket we don't want here.
            guard keywords.contains(where: { lower.contains($0) }) else { continue }
            // For weak keywords, never match a line that also contains a strong one.
            if keywords == weakTotalKeywords,
               strongTotalKeywords.contains(where: { lower.contains($0) }) {
                continue
            }
            // Avoid matching "subtotal" when looking for "total" specifically.
            if keywords.contains("total"), lower.contains("subtotal"), !lower.contains("grand total") {
                continue
            }
            for offset in 0...1 {
                let i = index + offset
                guard i < lines.count else { continue }
                if let value = lastAmount(in: lines[i]) {
                    return value
                }
            }
        }
        return nil
    }

    private static func extractLargestAmount(from lines: [String]) -> Double? {
        var values: [Double] = []
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            amountRegex.enumerateMatches(in: line, range: range) { match, _, _ in
                guard let match,
                      let r = Range(match.range, in: line),
                      let v = parseAmount(String(line[r]))
                else { return }
                values.append(v)
            }
        }
        return values.max()
    }

    private static func lastAmount(in line: String) -> Double? {
        let range = NSRange(line.startIndex..., in: line)
        var matches: [Double] = []
        amountRegex.enumerateMatches(in: line, range: range) { match, _, _ in
            guard let match,
                  let r = Range(match.range, in: line),
                  let v = parseAmount(String(line[r]))
            else { return }
            matches.append(v)
        }
        return matches.last
    }

    private static func parseAmount(_ raw: String) -> Double? {
        // Strip currency symbols and spaces, normalise decimal/group separators.
        var cleaned = raw.trimmingCharacters(in: .whitespaces)
        for symbol in ["$", "£", "€", "R", " "] {
            cleaned = cleaned.replacingOccurrences(of: symbol, with: "")
        }

        // If both '.' and ',' appear, assume the last one is the decimal separator.
        if cleaned.contains(",") && cleaned.contains(".") {
            if let lastComma = cleaned.lastIndex(of: ","),
               let lastDot = cleaned.lastIndex(of: "."),
               lastComma > lastDot {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else if cleaned.contains(",") && !cleaned.contains(".") {
            // Treat comma as decimal separator if exactly two digits after.
            if let comma = cleaned.lastIndex(of: ","),
               cleaned.distance(from: comma, to: cleaned.endIndex) == 3 {
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        }

        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    // MARK: - Date

    private static let dateFormatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd", "yyyy/MM/dd",
            "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy",
            "MM/dd/yyyy", "MM-dd-yyyy",
            "d MMM yyyy", "dd MMM yyyy", "d MMM yy", "dd MMM yy",
            "MMM d yyyy", "MMM dd, yyyy",
            "dd/MM/yy", "MM/dd/yy"
        ]
        return patterns.map { pattern in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = pattern
            return f
        }
    }()

    private static let dateCandidateRegex = try! NSRegularExpression(
        pattern: #"\b(?:\d{1,4}[/\-. ][A-Za-z0-9]{1,4}[/\-. ]\d{1,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{2,4})\b"#
    )

    private static func extractDate(from lines: [String]) -> Date? {
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            var found: Date?
            dateCandidateRegex.enumerateMatches(in: line, range: range) { match, _, stop in
                guard let match, let r = Range(match.range, in: line) else { return }
                let candidate = String(line[r])
                for formatter in dateFormatters {
                    if let date = formatter.date(from: candidate) {
                        found = date
                        stop.pointee = true
                        return
                    }
                }
            }
            if let found { return found }
        }
        return nil
    }

    // MARK: - Merchant

    private static let merchantBlacklistTokens: Set<String> = [
        "RECEIPT", "INVOICE", "TAX INVOICE", "VAT", "DUPLICATE", "CASH", "DEBIT", "CREDIT"
    ]

    private static func extractMerchant(from lines: [String]) -> String? {
        // Heuristic: first non-empty line that has letters and isn't a header keyword.
        for line in lines.prefix(8) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else { continue }
            let upper = trimmed.uppercased()
            if merchantBlacklistTokens.contains(where: { upper.contains($0) }) { continue }
            // Skip obvious all-digit lines.
            let alphas = trimmed.filter { $0.isLetter }
            guard alphas.count >= 2 else { continue }
            return trimmed
        }
        return nil
    }

    // MARK: - Currency

    private static let currencyMap: [String: String] = [
        "$": "USD",
        "£": "GBP",
        "€": "EUR",
        "R": "ZAR"
    ]

    private static func extractCurrencyCode(from lines: [String]) -> String? {
        let codes = ["USD", "EUR", "GBP", "ZAR", "AUD", "CAD", "JPY", "INR"]
        for line in lines {
            let upper = line.uppercased()
            for code in codes where upper.contains(code) {
                return code
            }
        }
        for line in lines {
            for (symbol, code) in currencyMap where line.contains(symbol) {
                return code
            }
        }
        return nil
    }
}

// MARK: - Bridge to MoneyEntry

extension ReceiptDraft {
    /// Convert the parsed draft into a MoneyEntry ready to be inserted.
    func makeMoneyEntry(category: String? = nil) -> MoneyEntry {
        MoneyEntry(
            type: .expense,
            amount: amount,
            currencyCode: currencyCode,
            category: category ?? suggestedCategory ?? "Receipt",
            dateScope: .day,
            startDate: date,
            notes: merchant,
            includeInMonthlySpending: true,
            source: .imported
        )
    }
}
