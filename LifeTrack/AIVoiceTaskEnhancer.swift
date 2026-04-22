//
//  AIVoiceTaskEnhancer.swift
//  LifeTrack
//

import Combine
import Foundation

@MainActor
final class AIVoiceTaskEnhancer: ObservableObject {
    @Published var isEnhancing = false
    @Published var error: String?

    var isConfigured: Bool { ClaudeAPIClient.shared.isConfigured }

    // MARK: - Single enhance

    func enhance(transcript: String) async -> VoiceTaskDraft? {
        guard isConfigured, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        isEnhancing = true
        error = nil
        defer { isEnhancing = false }

        do {
            let text = try await ClaudeAPIClient.shared.send(
                system: Self.singleSystemPrompt,
                userContent: Self.userContent(forTranscript: transcript),
                maxTokens: 650,
                cacheTTL: 60 * 60
            )
            return try parse(text)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    private static func userContent(forTranscript transcript: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .current
        let nowISO = formatter.string(from: Date())

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
        let weekday = weekdayFormatter.string(from: Date())

        let tz = TimeZone.current.identifier

        return """
        Current date/time: \(nowISO) (\(weekday), timezone \(tz))
        Transcript: "\(transcript)"
        """
    }

    // MARK: - Batch enhance (one API call for N transcripts)

    /// Enhance several transcripts in a single API call. Returns drafts in the same order as input,
    /// with nil for any entry that couldn't be parsed.
    func enhance(transcripts: [String]) async -> [VoiceTaskDraft?] {
        let cleaned = transcripts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let filledIndexes = cleaned.enumerated().compactMap { $1.isEmpty ? nil : $0 }

        guard isConfigured, !filledIndexes.isEmpty else {
            return Array(repeating: nil, count: transcripts.count)
        }

        if filledIndexes.count == 1, let only = filledIndexes.first {
            let single = await enhance(transcript: cleaned[only])
            var result: [VoiceTaskDraft?] = Array(repeating: nil, count: transcripts.count)
            result[only] = single
            return result
        }

        isEnhancing = true
        error = nil
        defer { isEnhancing = false }

        let numbered = filledIndexes.enumerated().map { i, idx in
            "\(i + 1). \"\(cleaned[idx])\""
        }.joined(separator: "\n")

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        isoFormatter.timeZone = .current
        let nowISO = isoFormatter.string(from: Date())
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
        let weekday = weekdayFormatter.string(from: Date())
        let tz = TimeZone.current.identifier

        let userContent = """
        Current date/time: \(nowISO) (\(weekday), timezone \(tz))

        Enhance each transcript below. Return a JSON array in the same order as the numbered input.

        Transcripts:
        \(numbered)
        """

        do {
            let text = try await ClaudeAPIClient.shared.send(
                system: Self.batchSystemPrompt,
                userContent: userContent,
                maxTokens: 650 * filledIndexes.count,
                cacheTTL: 60 * 60
            )
            let drafts = parseBatch(text, expected: filledIndexes.count)
            var result: [VoiceTaskDraft?] = Array(repeating: nil, count: transcripts.count)
            for (offset, idx) in filledIndexes.enumerated() where offset < drafts.count {
                result[idx] = drafts[offset]
            }
            return result
        } catch {
            self.error = error.localizedDescription
            return Array(repeating: nil, count: transcripts.count)
        }
    }

    // MARK: - Prompts

    private static let sharedRules = """
    Polishing (CRITICAL — do NOT echo the transcript verbatim):
    - The transcript is raw speech. Your job is to REWRITE it into clean, \
    readable fields. Never copy the user's words unchanged.
    - Fix grammar, tense, and capitalization. Use proper sentence case in notes.
    - Drop speech filler and hedging: "um", "uh", "yeah", "you know", \
    "I think", "maybe", "I guess", "let's see", "so that", "like".
    - Remove repeated phrases ("in the morning in the morning" → once).
    - Remove self-corrections entirely — keep only the final intended value.
    - Convert first-person narrative into imperative task language. \
    E.g. "I think I will have to go to the doctor" → title "See doctor", \
    not "Think about going to doctor".
    - Expand contractions only if they sound awkward; otherwise keep natural.
    - Notes must read like clean bullet points an assistant wrote, not a transcript.

    Self-correction handling (CRITICAL):
    - If the speaker corrects themselves ("at 12 no no not 12 it's 10", \
    "tomorrow, sorry, on Friday", "actually make it 2pm", "I mean 3 o'clock"), \
    ALWAYS use the final/corrected value and ignore the cancelled value.
    - Corrections always come AFTER the mistake. Trust the last value mentioned.
    - Filler repetitions ("in the morning in the morning") mean the same thing once.

    Title rules (STRICT):
    - Max 5 words, max 32 characters.
    - Start with a verb (e.g. "See", "Book", "Call", "Buy", "Email").
    - NEVER include time/date words: no "today", "tomorrow", "tonight", \
    "next week", weekday names, "at 10", "10am", "morning", "afternoon", \
    "evening", "this week", etc. Those live on the due date field.
    - Keep it a short action phrase. Prefer "See doctor" over "Schedule doctor appointment".
    - Do not add filler like "task", "reminder", "please".

    Due date rules:
    - Use the provided Current date/time as the reference for all relative phrases.
    - "tomorrow" = the next calendar day after the reference date.
    - "tonight" = same day, around 19:00 local.
    - Weekday names ("Friday") = next upcoming occurrence of that weekday.
    - If an explicit hour is given (e.g. "at 10", "10 o'clock", "2pm"), USE it exactly.
    - "in the morning" without an explicit hour = 09:00. "afternoon" = 14:00. \
    "evening" = 19:00. "night" = 20:00.
    - If an hour is given without am/pm, use context: "morning" → AM, \
    "evening/night" → PM. "in the morning at 10" → 10:00, not 22:00.
    - If NO date or time is mentioned at all, return "dueDate": null.
    - Output format: ISO 8601 LOCAL time with offset, e.g. "2026-04-23T10:00:00+02:00". \
    Match the timezone of the Current date/time.

    Priority rules:
    - high: urgent, asap, critical, must, important, deadline, overdue
    - low: sometime, maybe, eventually, when possible, no rush
    - normal: everything else

    Notes rules:
    - Use • as the bullet prefix, one bullet per line.
    - Notes must ADD information the Title + Due Date fields cannot express.
    - Do NOT repeat the time or date in notes when you've already set dueDate \
    — the UI shows the time next to the date. Only include a time bullet if \
    the transcript has a time qualifier the dueDate cannot capture \
    (e.g. "after lunch", "before my 3pm meeting", "between 10 and 11").
    - Add notes if ANY of these apply:
      1. Context, reasons, or sub-steps beyond the action itself \
         (e.g. "pass by friend's place to pick up orders").
      2. Implicit unknowns the user will need at execution time \
         (e.g. "pick up documents" → which ones? where?).
      3. Qualifiers or conditions not expressible as a single datetime \
         (e.g. "if possible", "after lunch", "between 10 and 11").
    - If the transcript is longer than the title can hold, put the remaining detail here.
    - Keep each bullet concise (under 12 words).
    - Do not include cancelled values from self-corrections in the notes.
    - null if the only extra info beyond the title was a specific time and \
    that time is already captured in dueDate.
    - If a piece of info belongs in advancedFields (see below), put it there \
    INSTEAD of notes — do not duplicate it in a bullet.

    Advanced fields (category-driven, OPTIONAL):
    - Fill only the keys listed under the category you chose. Use short,
    cleaned values (rewrite, don't echo). Omit any key with no value.
    - Health  (category="health"):
        "provider"  — Doctor/clinic/hospital name, cleaned.
        "dosage"    — Medication dosage (e.g. "500mg", "2 tablets twice daily").
    - Finance (category="finance"):
        "amount"    — Monetary amount with currency sign if known ("$42.50", "R1500").
        "payee"     — Vendor, biller, or person receiving payment ("Con Edison").
    - Work    (category="work"):
        "recipient"   — Email address or recipient name for emails/messages.
        "meetingLink" — Full meeting URL (zoom/meet/teams).
    - Home    (category="home"):
        "area"     — Room or zone ("kitchen", "garage, bathroom").
        "supplies" — Items/tools needed, comma-separated.
    - Personal (category="personal"):
        "withWhom" — Names of people involved.
    - Other   (category="other"): no advanced fields; return {}.
    - Return advancedFields as a JSON object. Empty object {} if nothing applies.
    - Never put keys from other categories. Never invent keys not listed above.

    Financial details (OPTIONAL):
    - Return financialDetails only when the transcript is clearly about money:
      bills, invoices, purchases, subscriptions, payments, income, savings, refunds, or reimbursements.
    - Use type "expense" for spending/bills, "income" for received money,
      "savings" for money moved into savings, and "reimbursement" for refunds owed or received.
    - plannedAmount is for money the user expects/plans to pay or receive later.
    - actualAmount is for money already paid, spent, saved, received, or logged.
    - Use an ISO 4217 currencyCode only if the transcript states a clear currency code,
      currency word, or unambiguous symbol. Use null when uncertain.
    - budgetCategory should be short and report-friendly ("Rent", "Transport", "Groceries").
    - paymentDate follows the same ISO 8601 local date-time rule as dueDate. Use null when unknown.
    - includeInMonthlySpending is true for expense bills/purchases that should count as spending;
      false for income, savings, and reimbursements unless the user explicitly wants them counted.
    - markPlannedOnCreate is true for planned bills or forecast items, false for already-paid actuals.
    - Do not invent linkedBudgetId or linkedGoalId. Return null unless the user explicitly gives a known ID.
    - Return financialDetails as null when no money metadata belongs on the task.
    """

    private static let singleSystemPrompt = """
    You structure a spoken task transcript into clean fields.

    Reply ONLY with this JSON (no markdown, no extra text):
    {
      "title": "Short imperative action, max 5 words and 32 chars, NO time/date words",
      "notes": null or "Bullet-pointed notes using • prefix for each point.",
      "dueDate": null or "ISO 8601 local date-time with timezone offset, e.g. 2026-04-23T10:00:00+02:00",
      "priority": "low|normal|high",
      "category": "health|finance|work|home|personal|other",
      "advancedFields": {} or { "key": "value", ... },
      "financialDetails": null or {
        "enabled": true,
        "type": "expense|income|savings|reimbursement",
        "plannedAmount": null or number,
        "actualAmount": null or number,
        "currencyCode": null or "ISO 4217 code",
        "budgetCategory": null or "short category",
        "paymentDate": null or "ISO 8601 local date-time with timezone offset",
        "linkedBudgetId": null,
        "linkedGoalId": null,
        "includeInMonthlySpending": true or false,
        "markPlannedOnCreate": true or false,
        "financialNotes": null or "short note"
      }
    }

    \(sharedRules)

    Worked example:
    Current date/time: 2026-04-22T13:55:00+02:00 (Wednesday, timezone Europe/Berlin)
    Transcript: "Tomorrow I think I will have to go to the doctor Dr Okafor around 2 pm yeah I will need to pass by my friends so that I can pick up some orders also"

    Correct output:
    {
      "title": "See doctor",
      "notes": "• Pass by friend's place to pick up orders",
      "dueDate": "2026-04-23T14:00:00+02:00",
      "priority": "normal",
      "category": "health",
      "advancedFields": { "provider": "Dr. Okafor" },
      "financialDetails": null
    }

    Notice: hedging ("I think", "maybe", "yeah") is gone, the side errand is rewritten \
    in clean imperative English, the doctor's name goes into advancedFields.provider \
    (NOT into the title or notes), and the time is NOT duplicated in notes because \
    dueDate already holds it.
    """

    private static let batchSystemPrompt = """
    You structure multiple spoken task transcripts into clean fields in one response.

    Reply ONLY with a JSON array (no markdown, no extra text). Each element mirrors the single-task schema and \
    appears in the same order as the numbered input transcripts:
    [
      {
        "title": "Short imperative action, max 5 words and 32 chars, NO time/date words",
        "notes": null or "Bullet-pointed notes using • prefix for each point.",
        "dueDate": null or "ISO 8601 local date-time with timezone offset, e.g. 2026-04-23T10:00:00+02:00",
        "priority": "low|normal|high",
        "category": "health|finance|work|home|personal|other",
        "advancedFields": {} or { "key": "value", ... },
        "financialDetails": null or {
          "enabled": true,
          "type": "expense|income|savings|reimbursement",
          "plannedAmount": null or number,
          "actualAmount": null or number,
          "currencyCode": null or "ISO 4217 code",
          "budgetCategory": null or "short category",
          "paymentDate": null or "ISO 8601 local date-time with timezone offset",
          "linkedBudgetId": null,
          "linkedGoalId": null,
          "includeInMonthlySpending": true or false,
          "markPlannedOnCreate": true or false,
          "financialNotes": null or "short note"
        }
      }
    ]

    \(sharedRules)
    """

    // MARK: - Parsing

    private func parse(_ text: String) throws -> VoiceTaskDraft {
        let jsonStr = ClaudeAPIClient.extractJSON(from: text)
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIClient.ClientError.parse(text)
        }
        return draft(from: json)
    }

    private func parseBatch(_ text: String, expected: Int) -> [VoiceTaskDraft] {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNL = s.firstIndex(of: "\n") { s = String(s[s.index(after: firstNL)...]) }
            if let fenceEnd = s.range(of: "```", options: .backwards) { s = String(s[..<fenceEnd.lowerBound]) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let first = s.firstIndex(of: "["), let last = s.lastIndex(of: "]"), first <= last {
            s = String(s[first...last])
        }

        guard let data = s.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.prefix(expected).map { draft(from: $0) }
    }

    private func draft(from json: [String: Any]) -> VoiceTaskDraft {
        let title = json["title"] as? String
        let notes = json["notes"] as? String

        let priority: TaskPriority?
        switch json["priority"] as? String {
        case "high":   priority = .high
        case "low":    priority = .low
        case "normal": priority = .normal
        default:       priority = nil
        }

        let category: TaskCategory?
        switch json["category"] as? String {
        case "health":   category = .health
        case "finance": category = .finance
        case "work":    category = .work
        case "home":    category = .home
        case "personal": category = .personal
        default:         category = .other
        }

        var dueDate: Date? = nil
        if let raw = json["dueDate"] as? String, !raw.isEmpty {
            dueDate = Self.parseDueDate(raw)
        }

        let advancedFields: [String: String] = Self.sanitizedAdvancedFields(
            json["advancedFields"],
            for: category
        )
        let financialDetails = Self.sanitizedFinancialDetails(json["financialDetails"])

        return VoiceTaskDraft(
            title: title,
            notes: notes,
            category: category,
            dueDate: dueDate,
            priority: priority,
            advancedFields: advancedFields,
            financialEnabled: financialDetails.enabled,
            financialType: financialDetails.type,
            plannedAmount: financialDetails.plannedAmount,
            actualAmount: financialDetails.actualAmount,
            currencyCode: financialDetails.currencyCode,
            budgetCategory: financialDetails.budgetCategory,
            paymentDate: financialDetails.paymentDate,
            linkedBudgetId: financialDetails.linkedBudgetId,
            linkedGoalId: financialDetails.linkedGoalId,
            includeInMonthlySpending: financialDetails.includeInMonthlySpending,
            markPlannedOnCreate: financialDetails.markPlannedOnCreate,
            financialNotes: financialDetails.notes
        )
    }

    private struct FinancialDetailsDraft {
        var enabled: Bool?
        var type: TaskFinancialType?
        var plannedAmount: Double?
        var actualAmount: Double?
        var currencyCode: String?
        var budgetCategory: String?
        var paymentDate: Date?
        var linkedBudgetId: UUID?
        var linkedGoalId: UUID?
        var includeInMonthlySpending: Bool?
        var markPlannedOnCreate: Bool?
        var notes: String?
    }

    private static func sanitizedFinancialDetails(_ raw: Any?) -> FinancialDetailsDraft {
        guard let dict = raw as? [String: Any], !dict.isEmpty else {
            return FinancialDetailsDraft()
        }

        let type = normalizedFinancialType(dict["type"])
        return FinancialDetailsDraft(
            enabled: boolValue(dict["enabled"]),
            type: type,
            plannedAmount: doubleValue(dict["plannedAmount"]),
            actualAmount: doubleValue(dict["actualAmount"]),
            currencyCode: normalizedCurrencyCode(dict["currencyCode"]),
            budgetCategory: stringValue(dict["budgetCategory"]),
            paymentDate: stringValue(dict["paymentDate"]).flatMap(parseDueDate),
            linkedBudgetId: stringValue(dict["linkedBudgetId"]).flatMap(UUID.init(uuidString:)),
            linkedGoalId: stringValue(dict["linkedGoalId"]).flatMap(UUID.init(uuidString:)),
            includeInMonthlySpending: boolValue(dict["includeInMonthlySpending"]),
            markPlannedOnCreate: boolValue(dict["markPlannedOnCreate"]),
            notes: stringValue(dict["financialNotes"])
        )
    }

    private static func normalizedFinancialType(_ raw: Any?) -> TaskFinancialType? {
        guard let value = stringValue(raw)?
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_") else {
            return nil
        }
        return TaskFinancialType(rawValue: value)
    }

    private static func normalizedCurrencyCode(_ raw: Any?) -> String? {
        guard let value = stringValue(raw)?.uppercased(),
              MoneyCurrency.supportedCodes.contains(value) else {
            return nil
        }
        return value
    }

    private static func stringValue(_ raw: Any?) -> String? {
        let value: String?
        switch raw {
        case let string as String:
            value = string
        case let number as NSNumber:
            value = number.stringValue
        default:
            value = nil
        }

        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func doubleValue(_ raw: Any?) -> Double? {
        switch raw {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            var cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned = cleaned.replacingOccurrences(of: #"[^0-9,.\-]"#, with: "", options: .regularExpression)
            if cleaned.filter({ $0 == "," }).count == 1, !cleaned.contains(".") {
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
            return Double(cleaned)
        default:
            return nil
        }
    }

    private static func boolValue(_ raw: Any?) -> Bool? {
        switch raw {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.intValue != 0
        case let string as String:
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1", "enabled", "on":
                return true
            case "false", "no", "0", "disabled", "off":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private static func sanitizedAdvancedFields(_ raw: Any?, for category: TaskCategory?) -> [String: String] {
        guard let dict = raw as? [String: Any], !dict.isEmpty else { return [:] }
        let allowedKeys = Set((category ?? .other).advancedFields.map(\.rawValue))
        guard !allowedKeys.isEmpty else { return [:] }

        var result: [String: String] = [:]
        for (key, value) in dict where allowedKeys.contains(key) {
            let stringValue: String
            switch value {
            case let s as String: stringValue = s
            case let n as NSNumber: stringValue = n.stringValue
            default: continue
            }
            let cleaned = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            result[key] = cleaned
        }
        return result
    }

    private static func parseDueDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFractional.date(from: s) { return d }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: s) { return d }

        // Fallback: date-only or loose format
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = .current
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            fallback.dateFormat = fmt
            if let d = fallback.date(from: s) { return d }
        }
        return nil
    }
}
