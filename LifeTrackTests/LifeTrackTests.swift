//
//  LifeTrackTests.swift
//  LifeTrackTests
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import Testing
@testable import LifeTrack

struct LifeTrackTests {

    @Test func emailTemplateCreatesEmailActionTaskDefaults() {
        let template = TaskTemplate.common.first { $0.id == "email" }

        #expect(template?.title == "Send follow-up email")
        #expect(template?.category == .work)
        #expect(template?.action == .email)
        #expect(template?.notes.contains("Subject: Follow up") == true)
    }

    @Test func completedTaskIsNeverOverdue() {
        let task = LifeTask(
            title: "Past task",
            category: .finance,
            dueDate: Date(timeIntervalSinceNow: -3600),
            isCompleted: true
        )

        #expect(task.isOverdue == false)
    }

    @Test func voiceParserDetectsAppointmentTomorrow() {
        let referenceDate = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to book a dentist appointment tomorrow",
            referenceDate: referenceDate
        )

        #expect(draft.title == "Book a dentist appointment")
        #expect(draft.notes == nil)
        #expect(draft.category == .health)
        #expect(draft.dueDate != nil)
    }

    @Test func voiceParserDetectsFinanceCategory() {
        let draft = VoiceTaskParser.parse("Review insurance payment in two days")

        #expect(draft.category == .finance)
        #expect(draft.title == "Review insurance payment")
    }

    @Test func voiceParserHandlesHourOffsetInTheNextHour() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to check power cables in the next hour",
            referenceDate: reference
        )

        #expect(draft.title == "Check power cables")
        let due = try #require(draft.dueDate)
        let delta = due.timeIntervalSince(reference)
        #expect(abs(delta - 3600) < 2)
    }

    @Test func voiceParserHandlesAnHourFromNow() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Check power cables an hour from now",
            referenceDate: reference
        )

        #expect(draft.title == "Check power cables")
        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 3600) < 2)
    }

    @Test func voiceParserHandlesAboutAnHour() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Check the power cables about an hour",
            referenceDate: reference
        )

        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 3600) < 2)
        #expect(draft.title == "Check the power cables")
    }

    @Test func voiceParserHandlesSpecificMinuteOffset() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to start the oven in 30 minutes",
            referenceDate: reference
        )

        #expect(draft.title == "Start the oven")
        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 1800) < 2)
    }

    @Test func voiceParserHandlesHalfAnHour() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to check the oven in half an hour",
            referenceDate: reference
        )

        #expect(draft.title == "Check the oven")
        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 1800) < 2)
    }

    @Test func voiceParserHandlesTwoHours() throws {
        let reference = Date(timeIntervalSince1970: 1_766_016_000)
        let draft = VoiceTaskParser.parse(
            "Remind me to call the client in 2 hours",
            referenceDate: reference
        )

        #expect(draft.title == "Call the client")
        let due = try #require(draft.dueDate)
        #expect(abs(due.timeIntervalSince(reference) - 7200) < 2)
    }

    @Test func voiceParserSplitsNotesOnBecauseClause() {
        let draft = VoiceTaskParser.parse(
            "Remind me to check the power cables in an hour because they've been overheating"
        )

        #expect(draft.title == "Check the power cables")
        #expect(draft.notes == "They've been overheating")
    }

    @Test func voiceParserSplitsNotesOnSentenceBoundary() {
        let draft = VoiceTaskParser.parse(
            "Send the quarterly insurance update tomorrow. Include the Q2 numbers and last year's spreadsheet."
        )

        #expect(draft.title == "Send the quarterly insurance update")
        #expect(draft.notes == "Include the Q2 numbers and last year's spreadsheet.")
        #expect(draft.category == .finance)
    }

    @Test func voiceParserKeepsTitleWhenNoAdditionalContext() {
        let draft = VoiceTaskParser.parse("Buy groceries")

        #expect(draft.title == "Buy groceries")
        #expect(draft.notes == nil)
    }

    // MARK: - CompletedArchivePeriod

    @Test func archivePeriodOffNeverArchives() {
        let deepPast = Date(timeIntervalSinceNow: -365 * 24 * 60 * 60 * 10)
        #expect(CompletedArchivePeriod.off.shouldArchive(completedAt: deepPast) == false)
    }

    @Test func archivePeriodArchivesWhenOlderThanLimit() {
        let reference = Date()
        let olderThanNinetyDays = reference.addingTimeInterval(-91 * 24 * 60 * 60)
        #expect(CompletedArchivePeriod.ninetyDays.shouldArchive(
            completedAt: olderThanNinetyDays,
            referenceDate: reference
        ) == true)
    }

    @Test func archivePeriodDoesNotArchiveRecentlyCompleted() {
        let reference = Date()
        let twoDaysAgo = reference.addingTimeInterval(-2 * 24 * 60 * 60)
        #expect(CompletedArchivePeriod.thirtyDays.shouldArchive(
            completedAt: twoDaysAgo,
            referenceDate: reference
        ) == false)
    }

    // MARK: - TaskBinRetentionPeriod

    @Test func binRetentionExpiresAfterDuration() {
        let reference = Date()
        let deletedEightDaysAgo = reference.addingTimeInterval(-8 * 24 * 60 * 60)
        #expect(TaskBinRetentionPeriod.sevenDays.isExpired(
            deletedAt: deletedEightDaysAgo,
            referenceDate: reference
        ) == true)
    }

    @Test func binRetentionImmediateIsAlwaysExpired() {
        let now = Date()
        #expect(TaskBinRetentionPeriod.immediately.isExpired(
            deletedAt: now,
            referenceDate: now
        ) == true)
    }

    // MARK: - DailyFocusPlanner

    @MainActor
    @Test func focusPlannerPrioritizesOverdueOverUpcoming() {
        let now = Date()
        let overdue = LifeTask(
            title: "Overdue",
            category: .work,
            dueDate: now.addingTimeInterval(-86_400)
        )
        let upcoming = LifeTask(
            title: "Upcoming",
            category: .work,
            dueDate: now.addingTimeInterval(86_400 * 5)
        )

        let recs = DailyFocusPlanner.recommendations(from: [upcoming, overdue])
        #expect(recs.first?.task.title == "Overdue")
        #expect(recs.first?.reason == .overdue)
    }

    @MainActor
    @Test func focusPlannerReturnsAtLeastThreeWhenAvailable() {
        let now = Date()
        let tasks = (0..<6).map { index in
            LifeTask(
                title: "Task \(index)",
                category: .work,
                dueDate: now.addingTimeInterval(TimeInterval(index * 3600))
            )
        }

        let recs = DailyFocusPlanner.recommendations(from: tasks)
        #expect(recs.count >= 3 && recs.count <= 5)
    }

    @MainActor
    @Test func focusPlannerShouldOfferResetWhenManyOverdue() {
        let now = Date()
        let overdueTasks = (0..<4).map { index in
            LifeTask(
                title: "Overdue \(index)",
                category: .work,
                dueDate: now.addingTimeInterval(-TimeInterval((index + 1) * 3600))
            )
        }
        #expect(DailyFocusPlanner.shouldOfferReset(for: overdueTasks) == true)
    }

    @MainActor
    @Test func focusPlannerDoesNotOfferResetForLightLoad() {
        let now = Date()
        let light = [
            LifeTask(title: "One", category: .work, dueDate: now.addingTimeInterval(3600)),
            LifeTask(title: "Two", category: .work, dueDate: now.addingTimeInterval(7200))
        ]
        #expect(DailyFocusPlanner.shouldOfferReset(for: light) == false)
    }

    @MainActor
    @Test func focusPlannerResetScheduleAssignsSlotsToFocusTasks() {
        let now = Date(timeIntervalSince1970: 1_766_016_000)
        let a = LifeTask(title: "A", category: .work, dueDate: now.addingTimeInterval(-3600))
        let b = LifeTask(title: "B", category: .work, dueDate: now.addingTimeInterval(-1800))
        let c = LifeTask(title: "C", category: .work, dueDate: now.addingTimeInterval(3600))

        let plan = DailyFocusPlanner.resetSchedule(
            for: [a, b, c],
            focusIDs: [a.id, b.id],
            referenceDate: now
        )

        let focusTitles = plan.compactMap { ($0.0.id == a.id || $0.0.id == b.id) ? $0.0.title : nil }
        #expect(focusTitles.contains("A"))
        #expect(focusTitles.contains("B"))
    }

}
