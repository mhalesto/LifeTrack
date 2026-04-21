//
//  WeeklyDigestService.swift
//  LifeTrack
//
//  Generates a short AI narrative about the user's week using Claude Haiku.
//  One call per ISO week — result is persisted in UserDefaults and reused.
//

import Combine
import Foundation

@MainActor
final class WeeklyDigestService: ObservableObject {
    static let shared = WeeklyDigestService()

    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let storeKey = "LifeTrack.ai.weeklyDigestCache"
    private let defaults = UserDefaults.standard

    /// Returns a cached narrative for the given week key if one exists.
    func cachedNarrative(forWeekKey key: String) -> String? {
        cache()[key]
    }

    /// Fetch the narrative for the week containing `weekEnd`. Cached per ISO week.
    func narrative(
        weekStart: Date,
        weekEnd: Date,
        completed: Int,
        rescheduled: Int,
        newIdeas: Int,
        nextWeekCount: Int,
        topCategoryName: String?,
        longestStreak: Int
    ) async -> String? {
        let key = Self.isoWeekKey(for: weekEnd)
        if let hit = cache()[key] { return hit }
        guard ClaudeAPIClient.shared.isConfigured else { return nil }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let range = "\(fmt.string(from: weekStart))–\(fmt.string(from: weekEnd))"

        let user = """
        Week: \(range)
        Completed: \(completed)
        Rescheduled: \(rescheduled)
        New ideas captured: \(newIdeas)
        Next-week tasks: \(nextWeekCount)
        Top category: \(topCategoryName ?? "—")
        Longest habit streak: \(longestStreak)
        """

        do {
            let text = try await ClaudeAPIClient.shared.send(
                system: Self.systemPrompt,
                userContent: user,
                maxTokens: 180,
                cacheTTL: .infinity
            )
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }
            persist(key: key, narrative: cleaned)
            return cleaned
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Prompt

    private static let systemPrompt = """
    You write a brief, warm weekly recap for a productivity app user based on their numbers.
    Keep it to 2–3 sentences. Lead with what went well, call out one clear pattern or momentum \
    signal, and end with a one-line nudge for next week. No emojis, no headings, no lists, no markdown. \
    Do not repeat the raw numbers back verbatim — interpret them.
    """

    // MARK: - Persistence

    private func cache() -> [String: String] {
        (defaults.dictionary(forKey: storeKey) as? [String: String]) ?? [:]
    }

    private func persist(key: String, narrative: String) {
        var current = cache()
        current[key] = narrative
        // Keep only the last 12 weeks to stay tiny.
        if current.count > 12 {
            let keep = current.sorted(by: { $0.key > $1.key }).prefix(12)
            current = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        defaults.set(current, forKey: storeKey)
    }

    private static func isoWeekKey(for date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = comps.yearForWeekOfYear ?? 0
        let week = comps.weekOfYear ?? 0
        return String(format: "%04d-W%02d", year, week)
    }
}
