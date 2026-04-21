//
//  TaskEmojiService.swift
//  LifeTrack
//
//  Maps a task title to a single emoji via Claude Haiku.
//  Results are cached permanently in UserDefaults keyed on title hash.
//

import Combine
import CryptoKit
import Foundation

@MainActor
final class TaskEmojiService: ObservableObject {
    static let shared = TaskEmojiService()

    private let defaults = UserDefaults.standard
    private let storeKey = "LifeTrack.ai.emojiCache"

    private var cache: [String: String]

    private init() {
        self.cache = (UserDefaults.standard.dictionary(forKey: "LifeTrack.ai.emojiCache") as? [String: String]) ?? [:]
    }

    /// Returns a cached emoji for the given title if one was previously computed.
    func cachedEmoji(for title: String) -> String? {
        cache[Self.key(for: title)]
    }

    /// Fetch an emoji for the given title. Cached forever on first success.
    /// Fails silently (returns nil) if the API is not configured or errors.
    @discardableResult
    func emoji(for title: String) async -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let key = Self.key(for: trimmed)
        if let hit = cache[key] { return hit }
        guard ClaudeAPIClient.shared.isConfigured else { return nil }

        do {
            let text = try await ClaudeAPIClient.shared.send(
                system: Self.systemPrompt,
                userContent: "Task title: \"\(trimmed)\"",
                maxTokens: 10,
                cacheTTL: .infinity
            )
            let emoji = Self.extractFirstEmoji(from: text)
            guard !emoji.isEmpty else { return nil }
            cache[key] = emoji
            defaults.set(cache, forKey: storeKey)
            return emoji
        } catch {
            return nil
        }
    }

    // MARK: - Prompt

    private static let systemPrompt = """
    You pick the single best emoji that represents a short task title.
    Reply with ONLY the emoji character — no words, no punctuation, no quotes, no explanation.
    """

    // MARK: - Helpers

    private static func key(for title: String) -> String {
        let normalized = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func extractFirstEmoji(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for char in trimmed {
            if char.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) {
                return String(char)
            }
        }
        // Fallback: first non-whitespace character, still lets us render something.
        return trimmed.first.map(String.init) ?? ""
    }
}
