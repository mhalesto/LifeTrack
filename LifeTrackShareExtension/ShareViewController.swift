//
//  ShareViewController.swift
//  LifeTrackShareExtension
//

import Social
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    private struct PendingAttachment {
        let originalURL: URL?
        let suggestedDisplayName: String?
        let extractedText: String?
    }

    private var pendingAttachments: [PendingAttachment] = []
    private var didLoadAttachments = false

    override func presentationAnimationDidFinish() {
        super.presentationAnimationDidFinish()

        guard !didLoadAttachments else { return }
        didLoadAttachments = true
        placeholder = "Add a note (optional)"
        title = "Send to LifeTrack"

        loadAttachments()
    }

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        let note = (contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = SharedInboxPayload(
            createdAt: Date(),
            note: note.isEmpty ? nil : note,
            attachments: pendingAttachments.map {
                SharedInboxAttachment(
                    originalFileName: $0.originalURL?.lastPathComponent,
                    storedRelativePath: $0.originalURL.flatMap { storedPath(for: $0) },
                    suggestedDisplayName: $0.suggestedDisplayName,
                    extractedText: $0.extractedText
                )
            }
        )

        SharedInboxWriter.write(payload: payload)

        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    private func loadAttachments() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }

        guard !providers.isEmpty else {
            pendingAttachments = []
            return
        }

        let group = DispatchGroup()
        var collected: [PendingAttachment] = []
        let queue = DispatchQueue(label: "LifeTrackShareExtension.collect")

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let url = (item as? URL) ?? (item as? NSURL) as URL?
                    guard let url else { return }
                    queue.sync {
                        collected.append(PendingAttachment(originalURL: url, suggestedDisplayName: url.lastPathComponent, extractedText: nil))
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        queue.sync {
                            collected.append(PendingAttachment(originalURL: url, suggestedDisplayName: url.lastPathComponent, extractedText: nil))
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        queue.sync {
                            collected.append(PendingAttachment(originalURL: url, suggestedDisplayName: url.lastPathComponent, extractedText: nil))
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    let url = (item as? URL) ?? (item as? NSURL) as URL?
                    if let url {
                        queue.sync {
                            collected.append(PendingAttachment(originalURL: nil, suggestedDisplayName: url.host ?? url.lastPathComponent, extractedText: url.absoluteString))
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let text = item as? String {
                        queue.sync {
                            collected.append(PendingAttachment(originalURL: nil, suggestedDisplayName: nil, extractedText: text))
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.pendingAttachments = collected
        }
    }

    private func storedPath(for sourceURL: URL) -> String? {
        return SharedInboxWriter.copyIntoInbox(sourceURL)
    }
}
