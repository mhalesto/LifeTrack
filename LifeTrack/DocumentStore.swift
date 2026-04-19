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
    private static let shareFolderName = "LifeTrackSharedDocuments"

    static func adoptFromAppGroup(sourceURL: URL, preferredDisplayName: String?) throws -> StoredDocument {
        let directory = try documentsDirectory()
        let rawDisplayName = preferredDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = sourceURL.lastPathComponent
        let displayName = (rawDisplayName?.isEmpty == false ? rawDisplayName! : fallbackName)
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

    static func shareableURL(for storageName: String, displayName: String?) -> URL? {
        guard
            let sourceURL = url(for: storageName),
            let directory = try? shareDirectory()
        else {
            return nil
        }

        let fileName = sanitizedShareFileName(
            displayName: displayName,
            sourceURL: sourceURL,
            storageName: storageName
        )
        let destinationURL = directory.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            return nil
        }
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

    private static func shareDirectory() throws -> URL {
        let baseURL = FileManager.default.temporaryDirectory
        let directory = baseURL.appendingPathComponent(shareFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func sanitizedShareFileName(displayName: String?, sourceURL: URL, storageName: String) -> String {
        let storedDisplayName: String
        if storageName.count > 37,
           storageName[storageName.index(storageName.startIndex, offsetBy: 36)] == "-" {
            let displayNameStart = storageName.index(storageName.startIndex, offsetBy: 37)
            storedDisplayName = String(storageName[displayNameStart...])
        } else {
            storedDisplayName = storageName
        }
        let fallbackName = storedDisplayName.isEmpty ? sourceURL.lastPathComponent : storedDisplayName
        let fallbackExtension = sourceURL.pathExtension
        let preferredName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawName = preferredName?.isEmpty == false ? preferredName ?? fallbackName : fallbackName
        let sanitized = rawName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitized.isEmpty else {
            return fallbackExtension.isEmpty ? "LifeTrack Document" : "LifeTrack Document.\(fallbackExtension)"
        }

        let currentExtension = URL(fileURLWithPath: sanitized).pathExtension
        if currentExtension.isEmpty && !fallbackExtension.isEmpty {
            return "\(sanitized).\(fallbackExtension)"
        }

        return sanitized
    }
}
