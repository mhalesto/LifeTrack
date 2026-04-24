//
//  CalendarAwareScheduleEngine.swift
//  LifeTrack
//

import Foundation

struct CalendarAwareScheduleDraft {
    let taskID: UUID
    let taskTitle: String
    let preferredStartDate: Date?
    let durationMinutes: Int
    let reasoning: String
    let energyTag: String
}

struct CalendarAwareSchedulePlan {
    let blocks: [ScheduledBlock]
    let unscheduledTitles: [String]
}

@MainActor
enum CalendarAwareScheduleEngine {
    private static let workdayStartHour = 8
    private static let workdayEndHour = 20
    private static let taskGapMinutes = 15
    private static let roundingMinutes = 5

    static func dayLoadInterval(for referenceDate: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    static func sequentialPlan(
        for tasks: [LifeTask],
        taskDurations: [UUID: Int] = [:],
        busyBlocks: [CalendarBusyBlock],
        referenceDate: Date = Date(),
        energyLevel: EnergyLevel = .unknown,
        calendar: Calendar = .current
    ) -> CalendarAwareSchedulePlan {
        let drafts = tasks.map { task in
            let duration = max(5, taskDurations[task.id] ?? task.scheduledDurationMinutes)
            return CalendarAwareScheduleDraft(
                taskID: task.id,
                taskTitle: task.title,
                preferredStartDate: nil,
                durationMinutes: duration,
                reasoning: localReasoning(for: task, durationMinutes: duration, energyLevel: energyLevel, calendar: calendar),
                energyTag: localEnergyTag(for: task, durationMinutes: duration, energyLevel: energyLevel)
            )
        }

        let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        return normalizedPlan(
            for: drafts,
            tasksByID: tasksByID,
            busyBlocks: busyBlocks,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func normalizedPlan(
        for drafts: [CalendarAwareScheduleDraft],
        tasksByID: [UUID: LifeTask],
        busyBlocks: [CalendarBusyBlock],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> CalendarAwareSchedulePlan {
        guard !drafts.isEmpty else {
            return CalendarAwareSchedulePlan(blocks: [], unscheduledTitles: [])
        }

        let workday = workdayInterval(for: referenceDate, calendar: calendar)
        let busyIntervals = busyBlocks
            .map { DateInterval(start: max($0.startDate, workday.start), end: min($0.endDate, workday.end)) }
            .filter { $0.end > $0.start }
        let orderedDrafts = drafts.enumerated().sorted { lhs, rhs in
            let leftDate = lhs.element.preferredStartDate ?? .distantFuture
            let rightDate = rhs.element.preferredStartDate ?? .distantFuture
            if leftDate != rightDate {
                return leftDate < rightDate
            }

            return lhs.offset < rhs.offset
        }

        var blocks: [ScheduledBlock] = []
        var reservedTaskIntervals: [DateInterval] = []
        var unscheduledTitles: [String] = []
        var cursor = roundedUpDate(max(referenceDate, workday.start), calendar: calendar)

        for draft in orderedDrafts.map(\.element) {
            guard tasksByID[draft.taskID] != nil else {
                unscheduledTitles.append(draft.taskTitle)
                continue
            }

            let preferredStart = max(draft.preferredStartDate ?? cursor, cursor)
            guard let slot = nextAvailableSlot(
                startingAt: preferredStart,
                durationMinutes: max(5, draft.durationMinutes),
                workday: workday,
                busyIntervals: busyIntervals,
                reservedTaskIntervals: reservedTaskIntervals,
                calendar: calendar
            ) else {
                unscheduledTitles.append(draft.taskTitle)
                continue
            }

            blocks.append(
                ScheduledBlock(
                    taskID: draft.taskID,
                    taskTitle: draft.taskTitle,
                    startDate: slot.start,
                    endDate: slot.end,
                    reasoning: draft.reasoning.isEmpty ? "Scheduled in your next open window." : draft.reasoning,
                    energyTag: draft.energyTag.isEmpty ? "Focus" : draft.energyTag
                )
            )

            let reservedEnd = slot.end.addingTimeInterval(TimeInterval(taskGapMinutes * 60))
            reservedTaskIntervals.append(DateInterval(start: slot.start, end: min(reservedEnd, workday.end)))
            cursor = roundedUpDate(reservedEnd, calendar: calendar)
        }

        return CalendarAwareSchedulePlan(
            blocks: blocks.sorted { $0.startDate < $1.startDate },
            unscheduledTitles: orderedUnique(unscheduledTitles)
        )
    }

    static func workdayInterval(for referenceDate: Date, calendar: Calendar = .current) -> DateInterval {
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(bySettingHour: workdayStartHour, minute: 0, second: 0, of: startOfDay) ?? startOfDay
        let end = calendar.date(bySettingHour: workdayEndHour, minute: 0, second: 0, of: startOfDay) ?? start.addingTimeInterval(12 * 60 * 60)
        return DateInterval(start: start, end: max(end, start.addingTimeInterval(60 * 60)))
    }

    private static func nextAvailableSlot(
        startingAt preferredStart: Date,
        durationMinutes: Int,
        workday: DateInterval,
        busyIntervals: [DateInterval],
        reservedTaskIntervals: [DateInterval],
        calendar: Calendar
    ) -> DateInterval? {
        let duration = TimeInterval(max(5, durationMinutes) * 60)
        var candidateStart = roundedUpDate(max(preferredStart, workday.start), calendar: calendar)

        while candidateStart.addingTimeInterval(duration) <= workday.end {
            let candidateEnd = candidateStart.addingTimeInterval(duration)
            let blockers = (busyIntervals + reservedTaskIntervals).sorted { $0.start < $1.start }

            if let conflict = blockers.first(where: { $0.end > candidateStart && $0.start < candidateEnd }) {
                candidateStart = roundedUpDate(conflict.end, calendar: calendar)
                continue
            }

            return DateInterval(start: candidateStart, end: candidateEnd)
        }

        return nil
    }

    private static func roundedUpDate(_ date: Date, calendar: Calendar) -> Date {
        let minute = calendar.component(.minute, from: date)
        let remainder = minute % roundingMinutes
        let roundedMinute = remainder == 0 ? minute : minute + (roundingMinutes - remainder)
        let base = calendar.date(bySettingHour: calendar.component(.hour, from: date), minute: 0, second: 0, of: date) ?? date
        let withMinutes = calendar.date(byAdding: .minute, value: roundedMinute, to: base) ?? date
        if withMinutes < date {
            return calendar.date(byAdding: .minute, value: roundingMinutes, to: withMinutes) ?? date
        }
        return withMinutes
    }

    private static func localReasoning(
        for task: LifeTask,
        durationMinutes: Int,
        energyLevel: EnergyLevel,
        calendar: Calendar
    ) -> String {
        if task.isOverdue {
            return "Overdue and worth clearing early."
        }

        if calendar.isDateInToday(task.dueDate) {
            return "Due today and worth protecting time for."
        }

        if energyLevel == .low && durationMinutes <= 30 {
            return "Short enough to fit a lower-energy window."
        }

        if task.priority == .high && durationMinutes >= 45 {
            return "High-priority work placed in a longer focus block."
        }

        if durationMinutes <= 30 {
            return "Quick win between your calendar commitments."
        }

        return "Placed in your next clear calendar window."
    }

    private static func localEnergyTag(
        for task: LifeTask,
        durationMinutes: Int,
        energyLevel: EnergyLevel
    ) -> String {
        if energyLevel == .low && durationMinutes <= 30 {
            return "Low effort"
        }

        if task.priority == .high && durationMinutes >= 45 {
            return "Deep focus"
        }

        if durationMinutes <= 30 {
            return "Quick win"
        }

        return task.category == .work ? "Admin" : "Deep focus"
    }

    private static func orderedUnique(_ titles: [String]) -> [String] {
        var seen: Set<String> = []
        return titles.filter { seen.insert($0).inserted }
    }
}
