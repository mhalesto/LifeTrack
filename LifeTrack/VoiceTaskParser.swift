//
//  VoiceTaskParser.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation

struct VoiceTaskDraft: Equatable {
    var title: String?
    var notes: String?
    var category: TaskCategory?
    var dueDate: Date?
    var priority: TaskPriority?
    var advancedFields: [String: String] = [:]
    var financialEnabled: Bool?
    var financialType: TaskFinancialType?
    var plannedAmount: Double?
    var actualAmount: Double?
    var currencyCode: String?
    var budgetCategory: String?
    var paymentDate: Date?
    var linkedBudgetId: UUID?
    var linkedGoalId: UUID?
    var includeInMonthlySpending: Bool?
    var markPlannedOnCreate: Bool?
    var financialNotes: String?
}

enum VoiceTaskParser {
    static func parse(_ transcript: String, referenceDate: Date = Date()) -> VoiceTaskDraft {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTranscript.isEmpty else {
            return VoiceTaskDraft()
        }

        var dueDate = detectedDueDate(in: cleanedTranscript, referenceDate: referenceDate)
        let explicitHour = detectedExplicitHour(in: cleanedTranscript)
        if let base = dueDate,
           let (hour, minute) = explicitHour,
           let overridden = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base) {
            dueDate = overridden
        }
        let residual = residualBody(from: cleanedTranscript)
        var (title, notes) = splitTitleAndNotes(residual)

        if let (hour, minute) = explicitHour {
            let bullet = "• " + formattedTimeBullet(hour: hour, minute: minute)
            if let existing = notes, !existing.isEmpty {
                notes = bullet + "\n" + existing
            } else {
                notes = bullet
            }
        }

        return VoiceTaskDraft(
            title: title,
            notes: notes,
            category: detectedCategory(in: cleanedTranscript),
            dueDate: dueDate
        )
    }

    private static func residualBody(from transcript: String) -> String {
        var body = stripCommandPrefix(transcript)
        body = stripTimeExpressions(body)
        body = collapseWhitespace(body)
        body = trimmedTrailingConnectors(body)
        body = body.trimmingCharacters(in: CharacterSet(charactersIn: ",.;: "))
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripCommandPrefix(_ text: String) -> String {
        let prefixes = [
            "please remind me to ",
            "remind me to ",
            "create a task to ",
            "create task to ",
            "add a task to ",
            "add task to ",
            "new task to ",
            "i need to ",
            "i have to ",
            "i want to ",
            "i should ",
            "make sure to ",
            "can you remind me to "
        ]

        var working = text
        var loweredCopy = working.lowercased()
        if let prefix = prefixes.first(where: { loweredCopy.hasPrefix($0) }) {
            working = String(working.dropFirst(prefix.count))
            loweredCopy = working.lowercased()
        }

        // Collapse filler "go to {verb}" / "go and {verb}" to just the verb.
        let fillerVerbs = ["see", "check", "get", "buy", "meet", "visit", "fetch", "collect", "find", "do", "make", "pick up"]
        for verb in fillerVerbs {
            let patterns = [
                "go to \(verb) ",
                "go and \(verb) "
            ]
            for p in patterns where loweredCopy.hasPrefix(p) {
                let dropCount = p.count - (verb.count + 1) // keep "{verb} "
                working = String(working.dropFirst(dropCount))
                return working
            }
        }

        return working
    }

    private static func splitTitleAndNotes(_ text: String) -> (title: String?, notes: String?) {
        guard !text.isEmpty else { return (nil, nil) }

        if let (head, tail) = splitOnFirstMatch(in: text, pattern: #"(?i)\s+(?:because|so that|so we can|so I can|since)\s+"#) {
            return (capitalized(head), capitalized(tail))
        }

        if let (head, tail) = splitOnSentenceBoundary(text) {
            return (capitalized(head), capitalized(tail))
        }

        if text.count > 90, let (head, tail) = splitOnFirstMatch(in: text, pattern: #"\s*[;—–]\s+|\s*,\s+"#) {
            if head.count >= 12 && !tail.isEmpty {
                return (capitalized(head), capitalized(tail))
            }
        }

        return (capitalized(text), nil)
    }

    private static func splitOnSentenceBoundary(_ text: String) -> (String, String)? {
        guard let range = text.range(of: #"(?<=[.!?])\s+"#, options: .regularExpression) else {
            return nil
        }

        let head = String(text[..<range.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: " .!?,;"))
        let tail = String(text[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !head.isEmpty, !tail.isEmpty else { return nil }
        return (head, tail)
    }

    private static func splitOnFirstMatch(in text: String, pattern: String) -> (String, String)? {
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let head = String(text[..<range.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,;:"))
        let tail = String(text[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !head.isEmpty, !tail.isEmpty else { return nil }
        return (head, tail)
    }

    private static func capitalized(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    }

    private static func trimmedTrailingConnectors(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let connectors = ["and", "but", "then", "also", "so", "because", "in"]
        var changed = true
        while changed {
            changed = false
            for word in connectors {
                let pattern = "(?i)\\s+\(word)$"
                if let range = result.range(of: pattern, options: .regularExpression) {
                    result = String(result[..<range.lowerBound])
                        .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:"))
                    changed = true
                }
            }
        }
        return result
    }

    // MARK: - Time expression stripping

    private static func stripTimeExpressions(_ text: String) -> String {
        var working = text
        for pattern in timeExpressionPatterns {
            working = working.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return working
    }

    private static let timeExpressionPatterns: [String] = [
        // "in the next hour/minute" (no count word)
        #"\bin\s+the\s+next\s+(?:hour|minute)\b"#,
        // "in an hour", "in 2 hours", "in about an hour", "in roughly 45 minutes"
        #"\bin\s+(?:the\s+next\s+|about\s+|around\s+|roughly\s+|approximately\s+)?(?:\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty|thirty|forty|forty[-\s]five|fifty|sixty|ninety|half\s+an)\s+(?:hours?|hrs?|minutes?|mins?)\b"#,
        // "2 hours from now", "an hour from now", "30 minutes from now"
        #"\b(?:\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty|thirty|forty|forty[-\s]five|fifty|sixty|ninety|half\s+an)\s+(?:hours?|hrs?|minutes?|mins?)\s+from\s+now\b"#,
        // "about an hour", "around 2 hours", "about 30 minutes"
        #"\b(?:about|around|roughly|approximately)\s+(?:\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty|thirty|forty|forty[-\s]five|fifty|sixty|ninety|half\s+an)\s+(?:hours?|hrs?|minutes?|mins?)\b"#,
        // Day-level phrases we already understand
        #"\bthe\s+day\s+after\s+tomorrow\b"#,
        #"\bday\s+after\s+tomorrow\b"#,
        #"\btomorrow\b"#,
        #"\btoday\b"#,
        #"\btonight\b"#,
        #"\bthis\s+(?:morning|afternoon|evening|weekend)\b"#,
        #"\bnext\s+week\b"#,
        #"\b(?:this|next|on)\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#,
        #"\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#,
        #"\bin\s+(?:\d+|one|two|three|four|five|six|seven)\s+days?\b"#,
        // Absolute times often paired: "at 3pm", "at 15:00", "at 6 o'clock"
        #"\bat\s+\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?\s*(?:o['’]?clock)?\b"#,
        // Bare "6 o'clock", "10 o'clock"
        #"\b\d{1,2}\s*o['’]?clock\b"#,
        // Bare trailing "o'clock"
        #"\bo['’]?clock\b"#
    ]

    // MARK: - Category detection

    private static func detectedCategory(in transcript: String) -> TaskCategory? {
        let text = transcript.lowercased()
        let keywordGroups: [(TaskCategory, [String])] = [
            (.health, ["appointment", "doctor", "dentist", "clinic", "medicine", "medication", "workout", "exercise", "health", "checkup", "therapy"]),
            (.finance, ["budget", "bill", "invoice", "payment", "bank", "tax", "insurance", "loan", "credit", "finance", "receipt"]),
            (.work, ["email", "meeting", "client", "report", "presentation", "project", "deadline", "follow up", "call", "work", "power cable", "power cables", "server", "deploy"]),
            (.home, ["home", "house", "repair", "clean", "laundry", "grocery", "groceries", "rent", "maintenance"]),
            (.personal, ["family", "birthday", "friend", "personal", "travel", "passport", "license"])
        ]

        return keywordGroups.first { _, keywords in
            keywords.contains { text.localizedCaseInsensitiveContains($0) }
        }?.0
    }

    // MARK: - Due date detection

    private static func detectedDueDate(in transcript: String, referenceDate: Date) -> Date? {
        if let relative = detectedRelativeTime(in: transcript, referenceDate: referenceDate) {
            return relative
        }

        if let detectorDate = detectedDateUsingDataDetector(in: transcript, referenceDate: referenceDate) {
            return detectorDate
        }

        let text = transcript.lowercased()
        let calendar = Calendar.current

        if text.contains("day after tomorrow") {
            return calendar.defaultTaskTime(byAdding: .day, value: 2, to: referenceDate)
        }

        if text.contains("tomorrow") {
            return calendar.defaultTaskTime(byAdding: .day, value: 1, to: referenceDate)
        }

        if text.contains("tonight") {
            return calendar.eveningTime(on: referenceDate)
        }

        if text.contains("today") {
            return calendar.defaultTaskTime(on: referenceDate)
        }

        if text.contains("next week") {
            return calendar.defaultTaskTime(byAdding: .day, value: 7, to: referenceDate)
        }

        if let weekdayDate = detectedWeekdayDate(in: text, referenceDate: referenceDate) {
            return weekdayDate
        }

        if let relativeDate = detectedRelativeDayCount(in: text, referenceDate: referenceDate) {
            return relativeDate
        }

        return nil
    }

    private static func formattedTimeBullet(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let cal = Calendar.current
        if let date = cal.date(from: components) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.timeStyle = .short
            return "At " + formatter.string(from: date)
        }
        return String(format: "At %02d:%02d", hour, minute)
    }

    /// Finds an explicit clock time in the transcript ("at 10", "10 o'clock",
    /// "10:30 am", "at 10:30"). Returns (hour, minute) in 24-hour form, or nil.
    /// Picks the LATEST occurring time so self-corrections ("at 12 no no not 12
    /// it's 10") yield the corrected value.
    /// "in the morning" biases 10 o'clock to 10:00; "in the evening/night" biases to 22:00.
    private static func detectedExplicitHour(in transcript: String) -> (hour: Int, minute: Int)? {
        let text = transcript.lowercased()

        let patterns = [
            #"(?:at\s+)?(\d{1,2}):(\d{2})\s*(am|pm|a\.m\.|p\.m\.)?"#,
            #"(?:at\s+)(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)"#,
            #"(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)"#,
            #"(?:at\s+)?(\d{1,2})\s*o['’]?clock"#,
            #"(?:at\s+)(\d{1,2})(?!\d)"#
        ]

        let preferEvening = text.contains("evening") || text.contains("tonight") || text.contains("night") || text.contains("pm")
        let preferMorning = text.contains("morning") || text.contains("am")
        let preferAfternoon = text.contains("afternoon")

        var latest: (offset: Int, hour: Int, minute: Int)?

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let hourRange = Range(match.range(at: 1), in: text),
                      let hour = Int(text[hourRange]), hour >= 0, hour <= 23 else {
                    continue
                }

                var minute = 0
                if match.numberOfRanges >= 3,
                   let r = Range(match.range(at: 2), in: text) {
                    let piece = String(text[r]).lowercased()
                    if let m = Int(piece) { minute = m }
                }

                var suffix = ""
                if match.numberOfRanges >= 4, let r = Range(match.range(at: 3), in: text) {
                    suffix = String(text[r]).lowercased()
                } else if match.numberOfRanges >= 3, let r = Range(match.range(at: 2), in: text) {
                    let piece = String(text[r]).lowercased()
                    if piece.contains("p") || piece.contains("a") { suffix = piece }
                }

                var resolvedHour = hour
                if suffix.contains("p") {
                    if resolvedHour < 12 { resolvedHour += 12 }
                } else if suffix.contains("a") {
                    if resolvedHour == 12 { resolvedHour = 0 }
                } else {
                    if preferEvening && resolvedHour >= 1 && resolvedHour <= 11 {
                        resolvedHour += 12
                    } else if preferAfternoon && resolvedHour >= 1 && resolvedHour <= 7 {
                        resolvedHour += 12
                    } else if preferMorning && resolvedHour == 12 {
                        resolvedHour = 0
                    }
                }

                if resolvedHour < 0 || resolvedHour > 23 { continue }
                if minute < 0 || minute > 59 { continue }

                let offset = match.range.location
                if latest == nil || offset > latest!.offset {
                    latest = (offset, resolvedHour, minute)
                }
            }
        }

        return latest.map { ($0.hour, $0.minute) }
    }

    private static func detectedRelativeTime(in transcript: String, referenceDate: Date) -> Date? {
        let text = transcript.lowercased()
        let calendar = Calendar.current

        let halfHourPattern = #"\b(?:in\s+(?:about\s+|around\s+|roughly\s+)?half\s+an\s+hour|half\s+an\s+hour\s+from\s+now|(?:about|around)\s+half\s+an\s+hour)\b"#
        if text.range(of: halfHourPattern, options: .regularExpression) != nil {
            return calendar.date(byAdding: .minute, value: 30, to: referenceDate)
        }

        if text.range(of: #"\bin\s+the\s+next\s+hour\b"#, options: .regularExpression) != nil {
            return calendar.date(byAdding: .minute, value: 60, to: referenceDate)
        }

        if text.range(of: #"\bin\s+the\s+next\s+minute\b"#, options: .regularExpression) != nil {
            return calendar.date(byAdding: .minute, value: 1, to: referenceDate)
        }

        let hourPatterns = [
            #"\bin\s+(?:the\s+next\s+|about\s+|around\s+|roughly\s+|approximately\s+)?(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|twelve|twenty[-\s]?four)\s+(?:hours?|hrs?)\b"#,
            #"\b(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|twelve)\s+(?:hours?|hrs?)\s+from\s+now\b"#,
            #"\b(?:about|around|roughly|approximately)\s+(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|twelve)\s+(?:hours?|hrs?)\b"#
        ]

        for pattern in hourPatterns {
            if let count = firstCapturedCount(in: text, pattern: pattern) {
                return calendar.date(byAdding: .minute, value: count * 60, to: referenceDate)
            }
        }

        let minutePatterns = [
            #"\bin\s+(?:the\s+next\s+|about\s+|around\s+|roughly\s+|approximately\s+)?(\d+|one|two|three|four|five|six|seven|eight|nine|ten|fifteen|twenty|thirty|forty[-\s]?five|forty|fifty|sixty|ninety)\s+(?:minutes?|mins?)\b"#,
            #"\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|fifteen|twenty|thirty|forty[-\s]?five|forty|fifty|sixty|ninety)\s+(?:minutes?|mins?)\s+from\s+now\b"#,
            #"\b(?:about|around|roughly|approximately)\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten|fifteen|twenty|thirty|forty[-\s]?five|forty|fifty|sixty|ninety)\s+(?:minutes?|mins?)\b"#
        ]

        for pattern in minutePatterns {
            if let count = firstCapturedCount(in: text, pattern: pattern) {
                return calendar.date(byAdding: .minute, value: count, to: referenceDate)
            }
        }

        return nil
    }

    private static func firstCapturedCount(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let captured = String(text[captureRange])
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let value = Int(captured) {
            return value
        }

        let words: [String: Int] = [
            "a": 1, "an": 1,
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "twelve": 12, "fifteen": 15, "twenty": 20, "twenty four": 24, "twentyfour": 24,
            "thirty": 30, "forty": 40, "forty five": 45, "fortyfive": 45, "fifty": 50,
            "sixty": 60, "ninety": 90
        ]

        return words[captured]
    }

    private static func detectedDateUsingDataDetector(in transcript: String, referenceDate: Date) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        let range = NSRange(transcript.startIndex..<transcript.endIndex, in: transcript)
        let matches = detector.matches(in: transcript, options: [], range: range)

        return matches
            .compactMap(\.date)
            .map { date in
                if Calendar.current.dateComponents([.hour, .minute], from: date).hour == 0 {
                    return Calendar.current.defaultTaskTime(on: date)
                }
                return date
            }
            .first { $0 >= Calendar.current.startOfDay(for: referenceDate) }
    }

    private static func detectedWeekdayDate(in text: String, referenceDate: Date) -> Date? {
        let weekdayMap = [
            "sunday": 1,
            "monday": 2,
            "tuesday": 3,
            "wednesday": 4,
            "thursday": 5,
            "friday": 6,
            "saturday": 7
        ]

        guard let weekday = weekdayMap.first(where: { text.contains($0.key) })?.value else {
            return nil
        }

        var components = DateComponents()
        components.weekday = weekday
        let matchingPolicy: Calendar.MatchingPolicy = text.contains("next") ? .nextTime : .nextTimePreservingSmallerComponents

        guard let date = Calendar.current.nextDate(
            after: referenceDate,
            matching: components,
            matchingPolicy: matchingPolicy,
            direction: .forward
        ) else {
            return nil
        }

        return Calendar.current.defaultTaskTime(on: date)
    }

    private static func detectedRelativeDayCount(in text: String, referenceDate: Date) -> Date? {
        let wordsToNumbers = [
            "one": 1,
            "two": 2,
            "three": 3,
            "four": 4,
            "five": 5,
            "six": 6,
            "seven": 7
        ]

        for (word, value) in wordsToNumbers where text.contains("in \(word) days") || text.contains("in \(word) day") {
            return Calendar.current.defaultTaskTime(byAdding: .day, value: value, to: referenceDate)
        }

        guard let range = text.range(of: #"in\s+(\d+)\s+days?"#, options: .regularExpression) else {
            return nil
        }

        let matchedText = String(text[range])
        let numberText = matchedText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let days = Int(numberText), days > 0 else {
            return nil
        }

        return Calendar.current.defaultTaskTime(byAdding: .day, value: days, to: referenceDate)
    }
}

private extension Calendar {
    func defaultTaskTime(byAdding component: Component, value: Int, to date: Date) -> Date? {
        guard let targetDate = self.date(byAdding: component, value: value, to: date) else {
            return nil
        }

        return defaultTaskTime(on: targetDate)
    }

    func defaultTaskTime(on date: Date) -> Date {
        let startOfTargetDay = startOfDay(for: date)
        let now = Date()
        let morningTime = self.date(bySettingHour: 9, minute: 0, second: 0, of: startOfTargetDay) ?? startOfTargetDay

        var components = dateComponents([.year, .month, .day], from: startOfTargetDay)
        components.hour = isDateInToday(date) && now > morningTime ? 18 : 9
        components.minute = 0

        return self.date(from: components) ?? date
    }

    func eveningTime(on date: Date) -> Date {
        self.date(bySettingHour: 19, minute: 0, second: 0, of: date) ?? date
    }
}
