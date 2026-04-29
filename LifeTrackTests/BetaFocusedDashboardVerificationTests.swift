//
//  BetaFocusedDashboardVerificationTests.swift
//  LifeTrackTests
//

import Foundation
import Testing
@testable import LifeTrack

struct BetaFocusedDashboardVerificationTests {

    @Test func focusSessionRestoresElapsedRunningTime() throws {
        let defaults = try Self.makeDefaults()
        let startedAt = Date(timeIntervalSince1970: 2_000)

        FocusSessionStore.start(
            timeRemaining: FocusSessionStore.focusDuration,
            isBreak: false,
            taskID: UUID(),
            taskTitle: "Update side hustle income",
            now: startedAt,
            defaults: defaults
        )

        let restored = FocusSessionStore.snapshot(
            now: startedAt.addingTimeInterval(75),
            defaults: defaults
        )

        #expect(restored.isRunning)
        #expect(restored.isBreak == false)
        #expect(restored.timeRemaining == FocusSessionStore.focusDuration - 75)
        #expect(restored.taskTitle == "Update side hustle income")
    }

    @Test func focusSessionRollsIntoBreakAfterRelaunch() throws {
        let defaults = try Self.makeDefaults()
        let startedAt = Date(timeIntervalSince1970: 3_000)

        FocusSessionStore.start(
            timeRemaining: 10,
            isBreak: false,
            taskID: nil,
            taskTitle: nil,
            now: startedAt,
            defaults: defaults
        )

        let restored = FocusSessionStore.snapshot(
            now: startedAt.addingTimeInterval(12),
            defaults: defaults
        )

        #expect(restored.isRunning)
        #expect(restored.isBreak)
        #expect(restored.timeRemaining == FocusSessionStore.breakDuration - 2)
        #expect(restored.completedFocusBlocks.count == 1)
        #expect(restored.completedFocusBlocks.first?.durationSeconds == 10)
    }

    @Test func focusSessionReportsMultipleCompletedBlocksAcrossRelaunch() throws {
        let defaults = try Self.makeDefaults()
        let startedAt = Date(timeIntervalSince1970: 4_000)
        let elapsed = FocusSessionStore.focusDuration +
            FocusSessionStore.breakDuration +
            FocusSessionStore.focusDuration +
            12

        FocusSessionStore.start(
            timeRemaining: FocusSessionStore.focusDuration,
            isBreak: false,
            taskID: nil,
            taskTitle: nil,
            now: startedAt,
            defaults: defaults
        )

        let restored = FocusSessionStore.snapshot(
            now: startedAt.addingTimeInterval(TimeInterval(elapsed)),
            defaults: defaults
        )

        #expect(restored.isBreak)
        #expect(restored.completedFocusBlocks.count == 2)
        #expect(restored.completedFocusBlocks.map(\.durationSeconds) == [
            FocusSessionStore.focusDuration,
            FocusSessionStore.focusDuration
        ])
    }

    @Test func focusSessionRecordRoundsDurationToMinutes() {
        let record = FocusSessionRecord(
            taskID: nil,
            taskTitle: "Focus",
            categoryRawValue: TaskCategory.work.rawValue,
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 61),
            durationSeconds: 61,
            completedBlock: false
        )

        #expect(record.durationMinutes == 2)
        #expect(record.category == .work)
    }

    @Test func focusSessionSummaryCalculatesTodayWeekAndStreak() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = Self.makeDate(year: 2026, month: 4, day: 30, hour: 12, calendar: calendar)
        let today = Self.makeDate(year: 2026, month: 4, day: 30, hour: 10, calendar: calendar)
        let yesterday = Self.makeDate(year: 2026, month: 4, day: 29, hour: 15, calendar: calendar)
        let lastWeek = Self.makeDate(year: 2026, month: 4, day: 20, hour: 15, calendar: calendar)

        let summary = FocusSessionSummary(
            records: [
                Self.makeFocusRecord(endedAt: today, durationSeconds: 25 * 60, completedBlock: true),
                Self.makeFocusRecord(endedAt: yesterday, durationSeconds: 13 * 60, completedBlock: false),
                Self.makeFocusRecord(endedAt: lastWeek, durationSeconds: 8 * 60, completedBlock: true)
            ],
            referenceDate: reference,
            calendar: calendar
        )

        #expect(summary.todayMinutes == 25)
        #expect(summary.weekMinutes == 38)
        #expect(summary.todayCompletedBlocks == 1)
        #expect(summary.totalCompletedBlocks == 2)
        #expect(summary.activeDayStreak == 2)
    }

    @Test func focusDailyGoalFormatsProgressAndCompletion() {
        let summary = FocusSessionSummary(
            records: [
                Self.makeFocusRecord(
                    endedAt: Date(),
                    durationSeconds: 25 * 60,
                    completedBlock: true
                )
            ]
        )
        let goal = FocusDailyGoal(minuteTarget: 30, blockTarget: 2)

        #expect(goal.homeLine(for: summary) == "25m focused today • 1 block")
        #expect(goal.compactProgressLine(for: summary) == "25m/30m • 1/2 blocks")
        #expect(goal.goalMetLine(for: summary) == "5m to minute goal")
        #expect(goal.goalMet(for: summary) == false)
    }

    @Test func focusDailyGoalDetectsCompletedGoal() {
        let summary = FocusSessionSummary(
            records: [
                Self.makeFocusRecord(
                    endedAt: Date(),
                    durationSeconds: 15 * 60,
                    completedBlock: true
                ),
                Self.makeFocusRecord(
                    endedAt: Date(),
                    durationSeconds: 15 * 60,
                    completedBlock: true
                )
            ]
        )
        let goal = FocusDailyGoal(minuteTarget: 30, blockTarget: 2)

        #expect(goal.goalMet(for: summary))
        #expect(goal.goalMetLine(for: summary) == "Goal met")
    }

    @Test func focusSessionPauseSurvivesLeavingScreen() throws {
        let defaults = try Self.makeDefaults()
        let taskID = UUID()

        FocusSessionStore.pause(
            timeRemaining: 480,
            isBreak: false,
            taskID: taskID,
            taskTitle: "Prepare demo build",
            defaults: defaults
        )

        let restored = FocusSessionStore.snapshot(
            now: Date(timeIntervalSince1970: 10_000),
            defaults: defaults
        )

        #expect(restored.isRunning == false)
        #expect(restored.timeRemaining == 480)
        #expect(restored.taskID == taskID)
        #expect(restored.taskTitle == "Prepare demo build")
    }

    @Test func dashboardCountGuardrailsCapHugeNumbers() {
        #expect(BetaFocusedDashboardFormat.count(0) == "0")
        #expect(BetaFocusedDashboardFormat.count(999) == "999")
        #expect(BetaFocusedDashboardFormat.count(1_000) == "999+")
        #expect(BetaFocusedDashboardFormat.count(14, limit: 9) == "9+")
    }

    @Test func focusHealthDetectsBlockedTasks() {
        let task = LifeTask(
            title: "Call insurer",
            category: .finance,
            dueDate: Date(timeIntervalSince1970: 2_000),
            notes: "Blocked waiting on policy number"
        )

        #expect(task.betaFocusedHealthState(referenceDate: Date(timeIntervalSince1970: 2_000)) == .blocked)
    }

    @Test func focusHealthDetectsStaleTasks() {
        let reference = Date(timeIntervalSince1970: 2_000_000)
        let oldDate = reference.addingTimeInterval(-20 * 24 * 60 * 60)
        let task = LifeTask(
            title: "Review old task",
            category: .work,
            dueDate: oldDate,
            updatedAt: oldDate
        )

        #expect(task.betaFocusedHealthState(referenceDate: reference) == .stale)
    }

    @Test func focusHealthDetectsRecurringMissedBeforeStale() {
        let reference = Date(timeIntervalSince1970: 2_000_000)
        let task = LifeTask(
            title: "Weekly review",
            category: .personal,
            dueDate: reference.addingTimeInterval(-2 * 24 * 60 * 60),
            recurrence: .weekly
        )

        #expect(task.betaFocusedHealthState(referenceDate: reference) == .recurringMissed)
    }

    @Test func focusHealthDetectsNeedsDateDefaults() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let created = calendar.date(from: DateComponents(year: 2026, month: 4, day: 29, hour: 12))!
        let due = calendar.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 9))!
        let task = LifeTask(
            title: "Untimed capture",
            category: .other,
            dueDate: due,
            priority: .normal,
            recurrence: .none,
            createdAt: created,
            updatedAt: created
        )

        #expect(task.betaFocusedHealthState(referenceDate: created, calendar: calendar) == .needsDate)
    }

    private static func makeDefaults() throws -> UserDefaults {
        let suiteName = "LifeTrackTests.focus.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private static func makeFocusRecord(
        endedAt: Date,
        durationSeconds: Int,
        completedBlock: Bool
    ) -> FocusSessionRecord {
        FocusSessionRecord(
            taskID: nil,
            taskTitle: "Focus",
            categoryRawValue: TaskCategory.work.rawValue,
            startedAt: endedAt.addingTimeInterval(-TimeInterval(durationSeconds)),
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            completedBlock: completedBlock
        )
    }
}
