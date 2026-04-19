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

}
