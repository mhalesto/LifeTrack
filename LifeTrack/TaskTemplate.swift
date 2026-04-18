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
    let priority: TaskPriority
    let recurrence: TaskRecurrence
    let estimatedDurationMinutes: Int

    init(
        id: String,
        title: String,
        category: TaskCategory,
        dueDate: Date,
        notes: String,
        action: TaskTemplateAction,
        priority: TaskPriority = .normal,
        recurrence: TaskRecurrence = .none,
        estimatedDurationMinutes: Int = 30
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.dueDate = dueDate
        self.notes = notes
        self.action = action
        self.priority = priority
        self.recurrence = recurrence
        self.estimatedDurationMinutes = estimatedDurationMinutes
    }

    var subtitle: String {
        switch id {
        case "email":
            "Creates a pre-filled follow-up email draft."
        case "budget":
            "Review balances, bills, and savings progress."
        case "checkup":
            "Plan a health appointment and attach records."
        case "bill":
            "Track monthly payments before they become overdue."
        case "medication":
            "Set a recurring health reminder."
        case "cleaning":
            "Keep home routines visible and lightweight."
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
                action: .email,
                estimatedDurationMinutes: 30
            ),
            TaskTemplate(
                id: "budget",
                title: "Review monthly budget",
                category: .finance,
                dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                notes: "Check account balances, upcoming bills, and savings progress.",
                action: .none,
                recurrence: .monthly,
                estimatedDurationMinutes: 45
            ),
            TaskTemplate(
                id: "checkup",
                title: "Book health check",
                category: .health,
                dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                notes: "Confirm available dates and add appointment documents once booked.",
                action: .none,
                priority: .high,
                estimatedDurationMinutes: 30
            ),
            TaskTemplate(
                id: "bill",
                title: "Pay monthly bill",
                category: .finance,
                dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                notes: "Attach the invoice or statement and confirm payment once complete.",
                action: .none,
                priority: .high,
                recurrence: .monthly,
                estimatedDurationMinutes: 20
            ),
            TaskTemplate(
                id: "medication",
                title: "Take medication",
                category: .health,
                dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                notes: "Confirm dosage and any notes from the prescription.",
                action: .none,
                priority: .high,
                recurrence: .daily,
                estimatedDurationMinutes: 5
            ),
            TaskTemplate(
                id: "cleaning",
                title: "Weekly cleaning reset",
                category: .home,
                dueDate: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
                notes: "Tidy the main spaces, laundry, bins, and quick surface clean.",
                action: .none,
                recurrence: .weekly,
                estimatedDurationMinutes: 60
            )
        ]
    }
}
