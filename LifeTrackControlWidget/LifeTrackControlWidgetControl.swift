//
//  LifeTrackControlWidgetControl.swift
//  LifeTrackControlWidget
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Intents

struct StartVoiceTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "New Voice Task"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.currenttech.LifeTrack")?
            .set(true, forKey: "pendingVoiceTaskLaunch")
        return .result()
    }
}

struct NewBlankTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "New Task"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.currenttech.LifeTrack")?
            .set(true, forKey: "pendingBlankTaskLaunch")
        return .result()
    }
}

struct TodaysFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Focus"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.currenttech.LifeTrack")?
            .set(true, forKey: "pendingFocusLaunch")
        return .result()
    }
}

struct QuickCompleteIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Next Task"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.currenttech.LifeTrack")?
            .set(true, forKey: "pendingQuickComplete")
        return .result()
    }
}

// MARK: - Controls

struct LifeTrackControlWidgetControl: ControlWidget {
    static let kind: String = "com.currenttech.LifeTrack.VoiceTaskControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { _ in
            ControlWidgetButton(action: StartVoiceTaskIntent()) {
                Label("Voice Task", systemImage: "waveform")
            }
            .tint(Color(red: 0.35, green: 0.55, blue: 1.0))
        }
        .displayName("New Voice Task")
        .description("Start voice recording to create a task in LifeTrack")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { false }
    }
}

struct NewBlankTaskControl: ControlWidget {
    static let kind: String = "com.currenttech.LifeTrack.NewBlankTaskControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { _ in
            ControlWidgetButton(action: NewBlankTaskIntent()) {
                Label("New Task", systemImage: "plus.circle")
            }
            .tint(Color(red: 0.35, green: 0.55, blue: 1.0))
        }
        .displayName("New Task")
        .description("Open LifeTrack and create a new task")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { false }
    }
}

struct TodaysFocusControl: ControlWidget {
    static let kind: String = "com.currenttech.LifeTrack.TodaysFocusControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { _ in
            ControlWidgetButton(action: TodaysFocusIntent()) {
                Label("Today's Focus", systemImage: "scope")
            }
            .tint(Color(red: 0.35, green: 0.55, blue: 1.0))
        }
        .displayName("Today's Focus")
        .description("Open LifeTrack to your daily focus tasks")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { false }
    }
}

struct QuickCompleteControl: ControlWidget {
    static let kind: String = "com.currenttech.LifeTrack.QuickCompleteControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { _ in
            ControlWidgetButton(action: QuickCompleteIntent()) {
                Label("Complete Next", systemImage: "checkmark.circle")
            }
            .tint(Color(red: 0.25, green: 0.75, blue: 0.45))
        }
        .displayName("Complete Next Task")
        .description("Mark your top priority task as done")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { false }
    }
}
