//
//  LifeTrackApp.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct LifeTrackApp: App {
    private let sharedModelContainer: ModelContainer
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        sharedModelContainer = LifeTrackDataStore.sharedModelContainer
        ReminderScheduler.configureNotificationCategories()
        UNUserNotificationCenter.current().delegate = LifeTrackNotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
