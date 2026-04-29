//
//  FocusSessionSummary.swift
//  LifeTrack
//

import Foundation

struct FocusSessionSummary {
    let records: [FocusSessionRecord]
    let referenceDate: Date
    let calendar: Calendar

    init(
        records: [FocusSessionRecord],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.records = records
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    var todayRecords: [FocusSessionRecord] {
        records.filter { calendar.isDate($0.endedAt, inSameDayAs: referenceDate) }
    }

    var weekRecords: [FocusSessionRecord] {
        records.filter { calendar.isDate($0.endedAt, equalTo: referenceDate, toGranularity: .weekOfYear) }
    }

    var todayMinutes: Int {
        minutes(in: todayRecords)
    }

    var weekMinutes: Int {
        minutes(in: weekRecords)
    }

    var todayCompletedBlocks: Int {
        todayRecords.filter(\.completedBlock).count
    }

    var totalCompletedBlocks: Int {
        records.filter(\.completedBlock).count
    }

    var activeDayStreak: Int {
        let activeDays = Set(records.map { calendar.startOfDay(for: $0.endedAt) })
        guard !activeDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: referenceDate)

        while activeDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    var latestRecord: FocusSessionRecord? {
        records.max { $0.endedAt < $1.endedAt }
    }

    func minutes(in records: [FocusSessionRecord]) -> Int {
        records.reduce(0) { $0 + $1.durationMinutes }
    }
}

struct FocusDailyGoal {
    static let defaultMinuteTarget = 30
    static let defaultBlockTarget = 2

    let minuteTarget: Int
    let blockTarget: Int

    init(minuteTarget: Int, blockTarget: Int) {
        self.minuteTarget = max(0, minuteTarget)
        self.blockTarget = max(0, blockTarget)
    }

    var hasMinuteGoal: Bool {
        minuteTarget > 0
    }

    var hasBlockGoal: Bool {
        blockTarget > 0
    }

    var isEnabled: Bool {
        hasMinuteGoal || hasBlockGoal
    }

    func minuteProgress(for summary: FocusSessionSummary) -> Double {
        guard hasMinuteGoal else { return 0 }
        return min(max(Double(summary.todayMinutes) / Double(minuteTarget), 0), 1)
    }

    func blockProgress(for summary: FocusSessionSummary) -> Double {
        guard hasBlockGoal else { return 0 }
        return min(max(Double(summary.todayCompletedBlocks) / Double(blockTarget), 0), 1)
    }

    func homeLine(for summary: FocusSessionSummary) -> String {
        "\(summary.todayMinutes)m focused today • \(blockCountLabel(summary.todayCompletedBlocks))"
    }

    func compactProgressLine(for summary: FocusSessionSummary) -> String {
        let minuteText = hasMinuteGoal
            ? "\(minuteLabel(summary.todayMinutes))/\(minuteLabel(minuteTarget))"
            : "\(minuteLabel(summary.todayMinutes)) today"
        let blockText = hasBlockGoal
            ? "\(summary.todayCompletedBlocks)/\(blockTarget) blocks"
            : blockCountLabel(summary.todayCompletedBlocks)

        return "\(minuteText) • \(blockText)"
    }

    func goalMetLine(for summary: FocusSessionSummary) -> String {
        if goalMet(for: summary) {
            return "Goal met"
        }

        if hasMinuteGoal, summary.todayMinutes < minuteTarget {
            let remaining = max(minuteTarget - summary.todayMinutes, 0)
            return "\(remaining)m to minute goal"
        }

        if hasBlockGoal, summary.todayCompletedBlocks < blockTarget {
            let remaining = max(blockTarget - summary.todayCompletedBlocks, 0)
            return "\(remaining) block\(remaining == 1 ? "" : "s") to goal"
        }

        return "Keep going"
    }

    func goalMet(for summary: FocusSessionSummary) -> Bool {
        let minuteMet = !hasMinuteGoal || summary.todayMinutes >= minuteTarget
        let blockMet = !hasBlockGoal || summary.todayCompletedBlocks >= blockTarget
        return isEnabled && minuteMet && blockMet
    }

    private func minuteLabel(_ minutes: Int) -> String {
        minutes > 999 ? "999+ min" : "\(minutes)m"
    }

    private func blockCountLabel(_ count: Int) -> String {
        "\(count) block\(count == 1 ? "" : "s")"
    }
}
