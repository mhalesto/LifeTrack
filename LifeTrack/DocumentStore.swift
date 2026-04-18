//
//  DocumentStore.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation

struct StoredDocument: Equatable {
    let storageName: String
    let displayName: String
}

enum DocumentStore {
    private static let folderName = "TaskDocuments"

    static func saveSecurityScopedFile(from sourceURL: URL) throws -> StoredDocument {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let directory = try documentsDirectory()
        let displayName = sourceURL.lastPathComponent
        let storageName = "\(UUID().uuidString)-\(displayName)"
        let destinationURL = directory.appendingPathComponent(storageName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: destinationURL.path
        )

        return StoredDocument(storageName: storageName, displayName: displayName)
    }

    static func url(for storageName: String) -> URL? {
        guard let directory = try? documentsDirectory() else {
            return nil
        }

        let url = directory.appendingPathComponent(storageName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func delete(storageName: String?) {
        guard
            let storageName,
            let url = url(for: storageName)
        else {
            return
        }

        try? FileManager.default.removeItem(at: url)
    }

    private static func documentsDirectory() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
