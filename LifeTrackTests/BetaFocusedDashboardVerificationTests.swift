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
}
