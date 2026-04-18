//
//  VoiceTaskParser.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation

struct VoiceTaskDraft: Equatable {
    var title: String?
    var category: TaskCategory?
    var dueDate: Date?
}

enum VoiceTaskParser {
    static func parse(_ transcript: String, referenceDate: Date = Date()) -> VoiceTaskDraft {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTranscript.isEmpty else {
            return VoiceTaskDraft()
        }

        return VoiceTaskDraft(
            title: normalizedTitle(from: cleanedTranscript),
            category: detectedCategory(in: cleanedTranscript),
            dueDate: detectedDueDate(in: cleanedTranscript, referenceDate: referenceDate)
        )
    }

    private static func normalizedTitle(from transcript: String) -> String {
        var title = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        let loweredTitle = title.lowercased()
        let prefixes = [
            "create a task to ",
            "create task to ",
            "add a task to ",
            "add task to ",
            "new task to ",
            "remind me to ",
            "i need to ",
            "i have to ",
            "please remind me to "
        ]

        if let prefix = prefixes.first(where: { loweredTitle.hasPrefix($0) }) {
            title.removeFirst(prefix.count)
        }

        return title.prefix(1).uppercased() + title.dropFirst()
    }

    private static func detectedCategory(in transcript: String) -> TaskCategory? {
        let text = transcript.lowercased()
        let keywordGroups: [(TaskCategory, [String])] = [
            (.health, ["appointment", "doctor", "dentist", "clinic", "medicine", "medication", "workout", "exercise", "health", "checkup", "therapy"]),
            (.finance, ["budget", "bill", "invoice", "payment", "bank", "tax", "insurance", "loan", "credit", "finance", "receipt"]),
            (.work, ["email", "meeting", "client", "report", "presentation", "project", "deadline", "follow up", "call", "work"]),
            (.home, ["home", "house", "repair", "clean", "laundry", "grocery", "groceries", "rent", "maintenance"]),
            (.personal, ["family", "birthday", "friend", "personal", "travel", "passport", "license"])
        ]

        return keywordGroups.first { _, keywords in
            keywords.contains { text.localizedCaseInsensitiveContains($0) }
        }?.0
    }

    private static func detectedDueDate(in transcript: String, referenceDate: Date) -> Date? {
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
}
