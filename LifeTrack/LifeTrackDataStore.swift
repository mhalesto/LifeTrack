//
//  LifeTrackDataStore.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData

@MainActor
enum LifeTrackDataStore {
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LifeTask.self,
            CustomTaskCategory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
