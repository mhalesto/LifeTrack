//
//  StartVoiceTaskIntent.swift
//  LifeTrack
//

import AppIntents
import Foundation

struct StartVoiceTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "New Voice Task"
    static var description = IntentDescription("Open LifeTrack and start voice recording to create a new task")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.currenttech.LifeTrack")?
            .set(true, forKey: "pendingVoiceTaskLaunch")
        return .result()
    }
}

struct NewBlankTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "New Task"
    static var description = IntentDescription("Open LifeTrack and create a new task")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.currenttech.LifeTrack")?
            .set(true, forKey: "pendingBlankTaskLaunch")
        return .result()
    }
}

struct TodaysFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Focus"
    static var description = IntentDescription("Open LifeTrack to your daily focus tasks")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.currenttech.LifeTrack")?
            .set(true, forKey: "pendingFocusLaunch")
        return .result()
    }
}

struct QuickCompleteIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Next Task"
    static var description = IntentDescription("Mark your top priority task as done in LifeTrack")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.currenttech.LifeTrack")?
            .set(true, forKey: "pendingQuickComplete")
        return .result()
    }
}
