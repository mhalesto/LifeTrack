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
