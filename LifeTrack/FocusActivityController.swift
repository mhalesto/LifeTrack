//
//  FocusActivityController.swift
//  LifeTrack
//
//  Wraps ActivityKit so a single LifeTask can be pinned to the lock
//  screen / Dynamic Island as a Live Activity until completion.
//

import ActivityKit
import Foundation
import SwiftUI

@MainActor
final class FocusActivityController {
    static let shared = FocusActivityController()

    private var current: Activity<LifeTrackControlWidgetAttributes>?
    private var currentTaskID: UUID?

    private init() {
        adoptExistingActivityIfAny()
    }

    var pinnedTaskID: UUID? { currentTaskID }

    func isPinned(_ task: LifeTask) -> Bool {
        currentTaskID == task.id
    }

    func toggle(for task: LifeTask, customCategories: [CustomTaskCategory]) {
        if isPinned(task) {
            stop()
        } else {
            start(for: task, customCategories: customCategories)
        }
    }

    func start(for task: LifeTask, customCategories: [CustomTaskCategory]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let existing = current {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
            current = nil
            currentTaskID = nil
        }

        let option = task.categoryOption(customCategories: customCategories)
        let attributes = LifeTrackControlWidgetAttributes(
            taskID: task.id.uuidString,
            title: task.title,
            categoryTitle: option.title,
            categorySymbol: option.symbolName,
            accentColorHex: hex(for: option.tint)
        )
        let state = makeState(for: task)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: task.dueDate.addingTimeInterval(60 * 60 * 12)),
                pushType: nil
            )
            current = activity
            currentTaskID = task.id
        } catch {
            current = nil
            currentTaskID = nil
        }
    }

    func update(for task: LifeTask) {
        guard let activity = current, currentTaskID == task.id else { return }

        if task.isCompleted || task.deletedAt != nil {
            stop(matching: task.id)
            return
        }

        let state = makeState(for: task)
        Task {
            await activity.update(ActivityContent(state: state, staleDate: task.dueDate.addingTimeInterval(60 * 60 * 12)))
        }
    }

    func stop() {
        guard let activity = current else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        current = nil
        currentTaskID = nil
    }

    func stop(matching taskID: UUID) {
        guard currentTaskID == taskID else { return }
        stop()
    }

    private func makeState(for task: LifeTask) -> LifeTrackControlWidgetAttributes.ContentState {
        let trimmedNote = task.notes
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = trimmedNote.isEmpty ? nil : String(trimmedNote.prefix(140))
        return .init(
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            isOverdue: !task.isCompleted && task.dueDate < Date(),
            noteSummary: summary
        )
    }

    private func adoptExistingActivityIfAny() {
        guard let existing = Activity<LifeTrackControlWidgetAttributes>.activities.first else { return }
        current = existing
        currentTaskID = UUID(uuidString: existing.attributes.taskID)
    }

    private func hex(for color: Color) -> UInt {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return 0x4F8CFF
        }
        let ri = UInt(max(0, min(255, Int(r * 255))))
        let gi = UInt(max(0, min(255, Int(g * 255))))
        let bi = UInt(max(0, min(255, Int(b * 255))))
        return (ri << 16) | (gi << 8) | bi
        #else
        return 0x4F8CFF
        #endif
    }
}
