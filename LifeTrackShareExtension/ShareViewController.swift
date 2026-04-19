//
//  ShareViewController.swift
//  LifeTrackShareExtension
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private struct PendingAttachment {
        let originalURL: URL?
        let suggestedDisplayName: String?
        let extractedText: String?
        let symbolName: String
        let typeDetail: String
    }

    private let model = ShareSheetModel()
    private var pendingAttachments: [PendingAttachment] = []
    private var hostingController: UIHostingController<ShareSheetView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let content = ShareSheetView(
            model: model,
            onCancel: { [weak self] in self?.cancel() },
            onPost: { [weak self] in self?.post() }
        )
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host

        loadAttachments()
    }

    private func cancel() {
        let error = NSError(
            domain: "com.currenttech.LifeTrack.ShareExtension",
            code: NSUserCancelledError,
            userInfo: nil
        )
        extensionContext?.cancelRequest(withError: error)
    }

    private func post() {
        guard !model.isPosting else { return }
        model.isPosting = true

        let trimmedNote = model.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = pendingAttachments

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let stored: [SharedInboxAttachment] = attachments.map { attachment in
                SharedInboxAttachment(
                    originalFileName: attachment.originalURL?.lastPathComponent,
                    storedRelativePath: attachment.originalURL.flatMap { SharedInboxWriter.copyIntoInbox($0) },
                    suggestedDisplayName: attachment.suggestedDisplayName,
                    extractedText: attachment.extractedText
                )
            }

            let payload = SharedInboxPayload(
                createdAt: Date(),
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                attachments: stored
            )

            SharedInboxWriter.write(payload: payload)

            DispatchQueue.main.async {
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }

    private func loadAttachments() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            model.isLoading = false
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty else {
            model.isLoading = false
            return
        }

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.currenttech.LifeTrack.ShareExtension.collect")
        var collected: [PendingAttachment] = []

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    guard let url = item as? URL else { return }
                    let attachment = PendingAttachment(
                        originalURL: url,
                        suggestedDisplayName: url.lastPathComponent,
                        extractedText: nil,
                        symbolName: "doc.text.fill",
                        typeDetail: "PDF document"
                    )
                    queue.sync { collected.append(attachment) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let url = (item as? URL) ?? (item as? NSURL) as URL?
                    guard let url else { return }
                    let meta = ShareViewController.fileMetadata(for: url)
                    let attachment = PendingAttachment(
                        originalURL: url,
                        suggestedDisplayName: url.lastPathComponent,
                        extractedText: nil,
                        symbolName: meta.symbol,
                        typeDetail: meta.detail
                    )
                    queue.sync { collected.append(attachment) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    guard let url = item as? URL else { return }
                    let attachment = PendingAttachment(
                        originalURL: url,
                        suggestedDisplayName: url.lastPathComponent,
                        extractedText: nil,
                        symbolName: "photo.fill",
                        typeDetail: "Image"
                    )
                    queue.sync { collected.append(attachment) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let url = (item as? URL) ?? (item as? NSURL) as URL?
                    guard let url else { return }
                    let attachment = PendingAttachment(
                        originalURL: nil,
                        suggestedDisplayName: url.host ?? url.lastPathComponent,
                        extractedText: url.absoluteString,
                        symbolName: "link",
                        typeDetail: url.host ?? "Link"
                    )
                    queue.sync { collected.append(attachment) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    guard let text = item as? String else { return }
                    let attachment = PendingAttachment(
                        originalURL: nil,
                        suggestedDisplayName: nil,
                        extractedText: text,
                        symbolName: "text.alignleft",
                        typeDetail: "Plain text"
                    )
                    queue.sync { collected.append(attachment) }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.pendingAttachments = collected
            self.model.previews = collected.map { attachment in
                SharedAttachmentPreview(
                    id: UUID(),
                    symbolName: attachment.symbolName,
                    displayName: attachment.suggestedDisplayName
                        ?? attachment.originalURL?.lastPathComponent
                        ?? "Shared item",
                    typeDetail: attachment.typeDetail
                )
            }
            self.model.isLoading = false
        }
    }

    private static func fileMetadata(for url: URL) -> (symbol: String, detail: String) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return ("doc.text.fill", "PDF document")
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "webp":
            return ("photo.fill", "Image")
        case "mp4", "mov", "m4v":
            return ("video.fill", "Video")
        case "mp3", "wav", "m4a", "aac":
            return ("waveform", "Audio")
        case "doc", "docx":
            return ("doc.fill", "Word document")
        case "xls", "xlsx", "csv":
            return ("tablecells.fill", "Spreadsheet")
        case "ppt", "pptx", "key":
            return ("rectangle.on.rectangle", "Presentation")
        case "zip", "rar", "7z":
            return ("shippingbox.fill", "Archive")
        case "txt", "md", "rtf":
            return ("doc.text", "Text file")
        default:
            return ("doc.fill", ext.isEmpty ? "File" : "\(ext.uppercased()) file")
        }
    }
}
