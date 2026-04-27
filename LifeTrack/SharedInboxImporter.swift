//
//  SharedInboxImporter.swift
//  LifeTrack
//

import Foundation
import SwiftData

@MainActor
enum SharedInboxImporter {
    static func drain(context: ModelContext) async {
        guard
            let inboxDirectory = SharedInboxLocations.inboxDirectory,
            FileManager.default.fileExists(atPath: inboxDirectory.path)
        else {
            return
        }

        let payloadURLs: [URL]
        do {
            payloadURLs = try FileManager.default
                .contentsOfDirectory(at: inboxDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            return
        }

        guard !payloadURLs.isEmpty else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for payloadURL in payloadURLs {
            guard
                let data = try? Data(contentsOf: payloadURL),
                let payload = try? decoder.decode(SharedInboxPayload.self, from: data)
            else {
                try? FileManager.default.removeItem(at: payloadURL)
                continue
            }

            await importPayload(payload, context: context)
            try? FileManager.default.removeItem(at: payloadURL)
        }
    }

    private static func importPayload(_ payload: SharedInboxPayload, context: ModelContext) async {
        let note = payload.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = payload.attachments

        if attachments.isEmpty {
            guard let note, !note.isEmpty else { return }
            InboxStore.add(
                CapturedTaskDraft(source: .shared, rawText: note, createdAt: Date())
                    .makeInboxItem()
            )
            return
        }

        for attachment in attachments {
            await importAttachment(attachment, note: note, context: context)
        }
    }

    private static func importAttachment(
        _ attachment: SharedInboxAttachment,
        note: String?,
        context: ModelContext
    ) async {
        var storedDocument: StoredDocument?

        if let relativePath = attachment.storedRelativePath,
           let filesDirectory = SharedInboxLocations.filesDirectory {
            let sharedURL = filesDirectory.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: sharedURL.path) {
                storedDocument = try? DocumentStore.adoptFromAppGroup(
                    sourceURL: sharedURL,
                    preferredDisplayName: attachment.suggestedDisplayName ?? attachment.originalFileName
                )
                try? FileManager.default.removeItem(at: sharedURL)
            }
        }

        let displayName = storedDocument?.displayName
            ?? attachment.suggestedDisplayName
            ?? attachment.originalFileName
            ?? "Shared item"

        var combinedNotes = ""
        if let note, !note.isEmpty {
            combinedNotes = note
        }
        if let text = attachment.extractedText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            if !combinedNotes.isEmpty {
                combinedNotes += "\n\n"
            }
            combinedNotes += text
        }

        let task = LifeTask(
            title: "Review \(displayName)",
            category: .personal,
            dueDate: CapturedTaskDraft.defaultDueDate(),
            notes: combinedNotes,
            documentStorageName: storedDocument?.storageName,
            documentDisplayName: storedDocument?.displayName
        )
        context.insert(task)
        try? context.save()

        guard let storedDocument else { return }

        if let url = DocumentStore.url(for: storedDocument.storageName) {
            let analysis = await DocumentAnalysisManager.analyze(
                url: url,
                displayName: storedDocument.displayName
            )
            task.documentExtractedText = analysis.extractedText
            task.documentAnalysisSummary = analysis.summary
            task.documentSuggestedTitle = analysis.suggestedTitle
            task.documentSuggestedDueDate = analysis.suggestedDueDate
            task.documentKeywords = analysis.keywords
            task.updatedAt = Date()
            try? context.save()
        }
    }
}
