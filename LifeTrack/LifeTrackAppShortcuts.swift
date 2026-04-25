//
//  LifeTrackAppShortcuts.swift
//  LifeTrack
//
//  Registers Siri phrases and shortcut tiles for LifeTrack's App Intents.
//

import AppIntents

struct LifeTrackAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Add a task to \(.applicationName)",
                "New task in \(.applicationName)",
                "Remind me in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: GetTodaysTasksIntent(),
            phrases: [
                "What's on my plate in \(.applicationName)",
                "Today's tasks in \(.applicationName)",
                "What do I need to do in \(.applicationName)"
            ],
            shortTitle: "Today's Tasks",
            systemImageName: "list.bullet.clipboard"
        )

        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Mark a task done in \(.applicationName)",
                "Complete task in \(.applicationName)"
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle.fill"
        )

        AppShortcut(
            intent: StartVoiceTaskIntent(),
            phrases: [
                "Capture a task with \(.applicationName)",
                "Start voice task in \(.applicationName)"
            ],
            shortTitle: "Voice Task",
            systemImageName: "mic.fill"
        )

        AppShortcut(
            intent: TodaysFocusIntent(),
            phrases: [
                "Show my focus in \(.applicationName)",
                "Open today's focus in \(.applicationName)"
            ],
            shortTitle: "Today's Focus",
            systemImageName: "sparkles"
        )

        AppShortcut(
            intent: LogMoneyEntryIntent(),
            phrases: [
                "Log money in \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Add an expense to \(.applicationName)"
            ],
            shortTitle: "Log Money",
            systemImageName: "creditcard.fill"
        )

        AppShortcut(
            intent: SpentTodayIntent(),
            phrases: [
                "How much have I spent today in \(.applicationName)",
                "What did I spend today in \(.applicationName)"
            ],
            shortTitle: "Spent Today",
            systemImageName: "dollarsign.circle"
        )

        AppShortcut(
            intent: SpentThisMonthIntent(),
            phrases: [
                "How much have I spent this month in \(.applicationName)",
                "Monthly spending in \(.applicationName)"
            ],
            shortTitle: "Spent This Month",
            systemImageName: "calendar.badge.clock"
        )
    }
}
