//
//  LifeTask.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import SwiftData

enum TaskCategory: String, CaseIterable, Identifiable {
    case health
    case finance
    case work
    case home
    case personal
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .health: "Health"
        case .finance: "Finance"
        case .work: "Work"
        case .home: "Home"
        case .personal: "Personal"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .health: "heart.text.square"
        case .finance: "creditcard"
        case .work: "briefcase"
        case .home: "house"
        case .personal: "person.crop.circle"
        case .other: "tag"
        }
    }
}

enum TaskTemplateAction: String {
    case none
    case email
}

@Model
final class LifeTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var categoryRawValue: String
    var dueDate: Date
    var isCompleted: Bool
    var notes: String
    var templateActionRawValue: String
    var documentStorageName: String?
    var documentDisplayName: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        category: TaskCategory,
        categoryRawValue: String? = nil,
        dueDate: Date,
        isCompleted: Bool = false,
        notes: String = "",
        templateAction: TaskTemplateAction = .none,
        documentStorageName: String? = nil,
        documentDisplayName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.categoryRawValue = categoryRawValue ?? category.rawValue
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.notes = notes
        self.templateActionRawValue = templateAction.rawValue
        self.documentStorageName = documentStorageName
        self.documentDisplayName = documentDisplayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var templateAction: TaskTemplateAction {
        get { TaskTemplateAction(rawValue: templateActionRawValue) ?? .none }
        set { templateActionRawValue = newValue.rawValue }
    }

    var isOverdue: Bool {
        !isCompleted && dueDate < Date()
    }

    var hasDocument: Bool {
        documentStorageName != nil && documentDisplayName != nil
    }
}
