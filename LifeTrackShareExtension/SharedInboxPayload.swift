//
//  SharedInboxPayload.swift
//  LifeTrackShareExtension
//

import Foundation

struct SharedInboxAttachment: Codable, Equatable {
    var originalFileName: String?
    var storedRelativePath: String?
    var suggestedDisplayName: String?
    var extractedText: String?
}

struct SharedInboxPayload: Codable, Equatable {
    var createdAt: Date
    var note: String?
    var attachments: [SharedInboxAttachment]
}

enum SharedInboxLocations {
    static let appGroupIdentifier = "group.com.currenttech.LifeTrack"
    static let inboxDirectoryName = "SharedInbox"
    static let filesDirectoryName = "SharedInboxFiles"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static var inboxDirectory: URL? {
        containerURL?.appendingPathComponent(inboxDirectoryName, isDirectory: true)
    }

    static var filesDirectory: URL? {
        containerURL?.appendingPathComponent(filesDirectoryName, isDirectory: true)
    }
}

enum SharedInboxWriter {
    static func write(payload: SharedInboxPayload) {
        guard let directory = SharedInboxLocations.inboxDirectory else { return }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            let fileName = "\(UUID().uuidString).json"
            let destination = directory.appendingPathComponent(fileName)
            try data.write(to: destination, options: [.atomic])
        } catch {
            // Extensions have no UI to surface this; silently drop.
        }
    }

    /// Copies a shared file into the App Group's files directory and returns the
    /// file name (relative path) the main app can re-hydrate.
    @discardableResult
    static func copyIntoInbox(_ sourceURL: URL) -> String? {
        guard let directory = SharedInboxLocations.filesDirectory else { return nil }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let displayName = sourceURL.lastPathComponent
            let storageName = "\(UUID().uuidString)-\(displayName)"
            let destination = directory.appendingPathComponent(storageName)

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
            }

            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return storageName
        } catch {
            return nil
        }
    }
}
