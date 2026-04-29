//
//  FocusSessionStore.swift
//  LifeTrack
//

import Foundation

struct FocusSessionSnapshot {
    let timeRemaining: Int
    let isRunning: Bool
    let isBreak: Bool
    let taskID: UUID?
    let taskTitle: String?
}

enum FocusSessionStore {
    static let focusDuration = 25 * 60
    static let breakDuration = 5 * 60

    private enum Keys {
        static let timeRemaining = "LifeTrack.focusSession.timeRemaining"
        static let isRunning = "LifeTrack.focusSession.isRunning"
        static let isBreak = "LifeTrack.focusSession.isBreak"
        static let phaseStartedAt = "LifeTrack.focusSession.phaseStartedAt"
        static let taskID = "LifeTrack.focusSession.taskID"
        static let taskTitle = "LifeTrack.focusSession.taskTitle"
    }

    static func snapshot(now: Date = Date(), defaults: UserDefaults = .standard) -> FocusSessionSnapshot {
        let storedRemaining = defaults.object(forKey: Keys.timeRemaining) as? Int ?? focusDuration
        let storedIsRunning = defaults.bool(forKey: Keys.isRunning)
        var resolvedIsBreak = defaults.bool(forKey: Keys.isBreak)
        var resolvedRemaining = max(1, storedRemaining)

        if storedIsRunning {
            let startedAt = defaults.double(forKey: Keys.phaseStartedAt)
            if startedAt > 0 {
                let elapsed = max(0, Int(now.timeIntervalSince(Date(timeIntervalSince1970: startedAt))))
                resolvedRemaining -= elapsed

                while resolvedRemaining <= 0 {
                    let overflow = abs(resolvedRemaining)
                    resolvedIsBreak.toggle()
                    let nextDuration = resolvedIsBreak ? breakDuration : focusDuration
                    resolvedRemaining = nextDuration - overflow
                }
            }
        }

        let taskID = defaults.string(forKey: Keys.taskID).flatMap(UUID.init(uuidString:))
        let taskTitle = defaults.string(forKey: Keys.taskTitle)

        return FocusSessionSnapshot(
            timeRemaining: min(max(resolvedRemaining, 1), resolvedIsBreak ? breakDuration : focusDuration),
            isRunning: storedIsRunning,
            isBreak: resolvedIsBreak,
            taskID: taskID,
            taskTitle: taskTitle
        )
    }

    static func start(
        timeRemaining: Int,
        isBreak: Bool,
        taskID: UUID?,
        taskTitle: String?,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) {
        defaults.set(max(1, timeRemaining), forKey: Keys.timeRemaining)
        defaults.set(true, forKey: Keys.isRunning)
        defaults.set(isBreak, forKey: Keys.isBreak)
        defaults.set(now.timeIntervalSince1970, forKey: Keys.phaseStartedAt)
        persistTask(taskID: taskID, taskTitle: taskTitle, defaults: defaults)
    }

    static func pause(
        timeRemaining: Int,
        isBreak: Bool,
        taskID: UUID?,
        taskTitle: String?,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(max(1, timeRemaining), forKey: Keys.timeRemaining)
        defaults.set(false, forKey: Keys.isRunning)
        defaults.set(isBreak, forKey: Keys.isBreak)
        defaults.removeObject(forKey: Keys.phaseStartedAt)
        persistTask(taskID: taskID, taskTitle: taskTitle, defaults: defaults)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.set(focusDuration, forKey: Keys.timeRemaining)
        defaults.set(false, forKey: Keys.isRunning)
        defaults.set(false, forKey: Keys.isBreak)
        defaults.removeObject(forKey: Keys.phaseStartedAt)
    }

    static func clearTask(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Keys.taskID)
        defaults.removeObject(forKey: Keys.taskTitle)
    }

    private static func persistTask(taskID: UUID?, taskTitle: String?, defaults: UserDefaults) {
        if let taskID {
            defaults.set(taskID.uuidString, forKey: Keys.taskID)
        } else {
            defaults.removeObject(forKey: Keys.taskID)
        }

        if let taskTitle, !taskTitle.isEmpty {
            defaults.set(taskTitle, forKey: Keys.taskTitle)
        } else {
            defaults.removeObject(forKey: Keys.taskTitle)
        }
    }
}
