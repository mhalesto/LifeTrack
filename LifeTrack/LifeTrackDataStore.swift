//
//  LifeTrackDataStore.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import SwiftData

@MainActor
enum LifeTrackDataStore {
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LifeTask.self,
            CustomTaskCategory.self,
            MoneyEntry.self,
        ])
        ensureDefaultStoreDirectoryExists()
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private static func ensureDefaultStoreDirectoryExists() {
        let fileManager = FileManager.default
        let groupIdentifier = "group.com.currenttech.LifeTrack"
        let candidates = [
            fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
                .appendingPathComponent("Library/Application Support", isDirectory: true),
            try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        ]

        for url in candidates.compactMap({ $0 }) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
