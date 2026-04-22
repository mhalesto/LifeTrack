//
//  NewTaskDraftStore.swift
//  LifeTrack
//
//  Caches an in-progress new-task form so an accidental dismissal
//  doesn't lose the user's input. On reopening the create flow,
//  NewTaskView asks the user whether to resume or discard.
//

import Foundation

struct NewTaskDraft: Codable, Equatable {
    var title: String
    var notes: String
    var categoryRawValue: String
    var dueDate: Date
    var priorityRawValue: String
    var recurrenceRawValue: String
    var templateActionRawValue: String
    var durationMinutes: Int
    var voiceTranscript: String
    var locationName: String?
    var locationLatitude: Double?
    var locationLongitude: Double?
    var locationRadius: Double?
    var locationOnArrival: Bool?
    var advancedFields: [String: String] = [:]
    var savedAt: Date
}

enum NewTaskDraftStore {
    private static let key = "NewTaskDraftStore.draft.v1"
    private static let maxAge: TimeInterval = 60 * 60 * 24 * 7 // 7 days

    static func save(_ draft: NewTaskDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> NewTaskDraft? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let draft = try? JSONDecoder().decode(NewTaskDraft.self, from: data) else {
            return nil
        }
        if Date().timeIntervalSince(draft.savedAt) > maxAge {
            clear()
            return nil
        }
        return draft
    }

    static func hasDraft() -> Bool {
        load() != nil
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
