//
//  FocusSessionRecord.swift
//  LifeTrack
//

import Foundation
import SwiftData

@Model
final class FocusSessionRecord {
    @Attribute(.unique) var id: UUID
    var taskID: UUID?
    var taskTitle: String
    var categoryRawValue: String
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var completedBlock: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        taskID: UUID?,
        taskTitle: String,
        categoryRawValue: String,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        completedBlock: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.categoryRawValue = categoryRawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, durationSeconds)
        self.completedBlock = completedBlock
        self.createdAt = createdAt
    }

    var durationMinutes: Int {
        guard durationSeconds > 0 else { return 0 }
        return max(1, Int(ceil(Double(durationSeconds) / 60.0)))
    }

    var category: TaskCategory {
        TaskCategory(rawValue: categoryRawValue) ?? .other
    }
}
