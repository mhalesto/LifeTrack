//
//  TaskTemplate.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation

struct TaskTemplate: Identifiable {
    let id: String
    let title: String
    let category: TaskCategory
    let dueDate: Date
    let notes: String
    let action: TaskTemplateAction

    var subtitle: String {
        switch id {
        case "email":
            "Creates a pre-filled follow-up email draft."
        case "budget":
            "Review balances, bills, and savings progress."
        case "checkup":
            "Plan a health appointment and attach records."
        default:
            "Start from a structured task."
        }
    }

    var symbolName: String {
        switch action {
        case .email:
            "envelope.badge"
        case .none:
            category.symbolName
        }
    }

    static var common: [TaskTemplate] {
        [
            TaskTemplate(
                id: "email",
                title: "Send follow-up email",
                category: .work,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                notes: "Subject: Follow up\n\nHi,\n\nI wanted to follow up on this task and confirm the next step.\n\nThanks,",
                action: .email
            ),
            TaskTemplate(
                id: "budget",
                title: "Review monthly budget",
                category: .finance,
                dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                notes: "Check account balances, upcoming bills, and savings progress.",
                action: .none
            ),
            TaskTemplate(
                id: "checkup",
                title: "Book health check",
                category: .health,
                dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                notes: "Confirm available dates and add appointment documents once booked.",
                action: .none
            )
        ]
    }
}
