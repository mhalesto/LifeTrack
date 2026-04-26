//
//  InboxItem.swift
//  LifeTrack
//

import Foundation

enum InboxItemSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case typed
    case voice
    case shared

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typed: "Typed"
        case .voice: "Voice"
        case .shared: "Shared"
        }
    }

    var symbolName: String {
        switch self {
        case .typed: "square.and.pencil"
        case .voice: "mic.fill"
        case .shared: "square.and.arrow.down"
        }
    }
}

struct InboxItem: Identifiable, Codable, Equatable {
    var id: UUID
    var source: InboxItemSource
    var rawText: String
    var previewTitle: String
    var structuredDraft: VoiceTaskDraft
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var convertedAt: Date?

    init(
        id: UUID = UUID(),
        source: InboxItemSource,
        rawText: String,
        previewTitle: String,
        structuredDraft: VoiceTaskDraft,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        archivedAt: Date? = nil,
        convertedAt: Date? = nil
    ) {
        self.id = id
        self.source = source
        self.rawText = rawText
        self.previewTitle = previewTitle
        self.structuredDraft = structuredDraft
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.convertedAt = convertedAt
    }

    var isOpen: Bool {
        archivedAt == nil && convertedAt == nil
    }

    var captureDraft: CapturedTaskDraft {
        CapturedTaskDraft(
            source: source,
            rawText: rawText,
            structuredDraft: structuredDraft,
            createdAt: createdAt
        )
    }

    mutating func markArchived(at date: Date = Date()) {
        archivedAt = date
        updatedAt = date
    }

    mutating func markConverted(at date: Date = Date()) {
        convertedAt = date
        updatedAt = date
    }
}

enum InboxStore {
    private static let key = "LifeTrack.InboxStore.items.v1"

    static func loadItems() -> [InboxItem] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let items = try? JSONDecoder().decode([InboxItem].self, from: data)
        else {
            return []
        }

        return items.sorted { $0.createdAt > $1.createdAt }
    }

    static func loadOpenItems() -> [InboxItem] {
        loadItems().filter(\.isOpen)
    }

    static func add(_ item: InboxItem) {
        var items = loadItems()
        items.removeAll { $0.id == item.id }
        items.append(item)
        save(items)
    }

    static func update(_ item: InboxItem) {
        var items = loadItems()
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            items.append(item)
            save(items)
            return
        }
        items[index] = item
        save(items)
    }

    static func remove(id: UUID) {
        save(loadItems().filter { $0.id != id })
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func save(_ items: [InboxItem]) {
        guard let data = try? JSONEncoder().encode(items.sorted { $0.createdAt > $1.createdAt }) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
