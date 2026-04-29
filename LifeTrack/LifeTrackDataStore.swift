//
//  LifeTrackDataStore.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import OSLog
import SwiftData

@MainActor
enum LifeTrackDataStore {
    private static let logger = Logger(subsystem: "com.currenttech.LifeTrack", category: "DataStore")

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LifeTask.self,
            CustomTaskCategory.self,
            MoneyEntry.self,
            RecurringMoneyTransaction.self,
            FocusSessionRecord.self,
        ])
        ensureDefaultStoreDirectoryExists()
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            logger.error("Persistent ModelContainer failed to load: \(error.localizedDescription, privacy: .public)")
            // Try renaming the corrupted store aside so the next launch can
            // build a fresh one without losing the user's old data.
            archiveStoreIfPresent()

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                logger.error("Recreating ModelContainer after archive failed: \(error.localizedDescription, privacy: .public)")
                // Last-resort: in-memory container so the app at least
                // launches. The user can navigate, see the schema, and
                // reinstall or restore from backup without a force-quit loop.
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [memoryConfig])
                } catch {
                    fatalError("ModelContainer could not be created even in-memory: \(error)")
                }
            }
        }
    }()

    private static func ensureDefaultStoreDirectoryExists() {
        let fileManager = FileManager.default
        for url in storeDirectoryCandidates() {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Renames the on-disk `default.store` (and its sidecar files) so a fresh
    /// container can be created on the next attempt. The old data is preserved
    /// under a timestamped name rather than deleted - the user can recover it
    /// from the device file system if they need to.
    private static func archiveStoreIfPresent() {
        let fileManager = FileManager.default
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        for directory in storeDirectoryCandidates() {
            guard let entries = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
                continue
            }
            for entry in entries where entry.lastPathComponent.hasPrefix("default.store") {
                let archived = directory.appendingPathComponent("corrupted-\(timestamp)-\(entry.lastPathComponent)")
                try? fileManager.moveItem(at: entry, to: archived)
                logger.notice("Archived corrupted store: \(entry.lastPathComponent, privacy: .public) -> \(archived.lastPathComponent, privacy: .public)")
            }
        }
    }

    private static func storeDirectoryCandidates() -> [URL] {
        let fileManager = FileManager.default
        let groupIdentifier = "group.com.currenttech.LifeTrack"
        return [
            fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
                .appendingPathComponent("Library/Application Support", isDirectory: true),
            try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        ].compactMap { $0 }
    }
}
