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

        #expect(draft.title == "Book a dentist appointment tomorrow")
        #expect(draft.category == .health)
        #expect(draft.dueDate != nil)
    }

    @Test func voiceParserDetectsFinanceCategory() {
        let draft = VoiceTaskParser.parse("Review insurance payment in two days")

        #expect(draft.category == .finance)
        #expect(draft.title == "Review insurance payment in two days")
    }

}
