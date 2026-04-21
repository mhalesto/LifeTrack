//
//  AIVoiceTaskEnhancer.swift
//  LifeTrack
//

import Combine
import Foundation

@MainActor
final class AIVoiceTaskEnhancer: ObservableObject {
    @Published var isEnhancing = false
    @Published var error: String?

    var isConfigured: Bool { ClaudeAPIClient.shared.isConfigured }

    // MARK: - Single enhance

    func enhance(transcript: String) async -> VoiceTaskDraft? {
        guard isConfigured, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        isEnhancing = true
        error = nil
        defer { isEnhancing = false }

        do {
            let text = try await ClaudeAPIClient.shared.send(
                system: Self.singleSystemPrompt,
                userContent: "Transcript: \"\(transcript)\"",
                maxTokens: 300,
                cacheTTL: 60 * 60
            )
            return try parse(text)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    // MARK: - Batch enhance (one API call for N transcripts)

    /// Enhance several transcripts in a single API call. Returns drafts in the same order as input,
    /// with nil for any entry that couldn't be parsed.
    func enhance(transcripts: [String]) async -> [VoiceTaskDraft?] {
        let cleaned = transcripts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let filledIndexes = cleaned.enumerated().compactMap { $1.isEmpty ? nil : $0 }

        guard isConfigured, !filledIndexes.isEmpty else {
            return Array(repeating: nil, count: transcripts.count)
        }

        if filledIndexes.count == 1, let only = filledIndexes.first {
            let single = await enhance(transcript: cleaned[only])
            var result: [VoiceTaskDraft?] = Array(repeating: nil, count: transcripts.count)
            result[only] = single
            return result
        }

        isEnhancing = true
        error = nil
        defer { isEnhancing = false }

        let numbered = filledIndexes.enumerated().map { i, idx in
            "\(i + 1). \"\(cleaned[idx])\""
        }.joined(separator: "\n")

        let userContent = """
        Enhance each transcript below. Return one JSON object per line, in order, matching the numbered input.

        Transcripts:
        \(numbered)
        """

        do {
            let text = try await ClaudeAPIClient.shared.send(
                system: Self.batchSystemPrompt,
                userContent: userContent,
                maxTokens: 300 * filledIndexes.count,
                cacheTTL: 60 * 60
            )
            let drafts = parseBatch(text, expected: filledIndexes.count)
            var result: [VoiceTaskDraft?] = Array(repeating: nil, count: transcripts.count)
            for (offset, idx) in filledIndexes.enumerated() where offset < drafts.count {
                result[idx] = drafts[offset]
            }
            return result
        } catch {
            self.error = error.localizedDescription
            return Array(repeating: nil, count: transcripts.count)
        }
    }

    // MARK: - Prompts

    private static let sharedRules = """
    Priority rules:
    - high: urgent, asap, critical, must, important, deadline, overdue
    - low: sometime, maybe, eventually, when possible, no rush
    - normal: everything else

    Notes rules:
    - Use • as the bullet prefix
    - Add notes if ANY of these apply:
      1. The transcript has context, reasons, or sub-steps beyond the action itself
      2. The task has implicit unknowns the user will need at execution time (e.g. "pick up documents" → where? which ones?)
      3. The transcript contains a qualifier or condition (e.g. "during the day", "if possible", "after 2pm")
    - Keep each bullet concise (under 12 words)
    - Phrase implicit-unknown bullets as reminders, e.g. "• Note which documents and where to collect"
    - null only if the transcript is completely unambiguous and self-contained
    """

    private static let singleSystemPrompt = """
    You structure a spoken task transcript into clean fields.

    Reply ONLY with this JSON (no markdown, no extra text):
    {
      "title": "Concise imperative task title, max 8 words, start with a verb",
      "notes": null or "Bullet-pointed notes using • prefix for each point.",
      "priority": "low|normal|high",
      "category": "health|finance|work|home|personal|other"
    }

    \(sharedRules)
    """

    private static let batchSystemPrompt = """
    You structure multiple spoken task transcripts into clean fields in one response.

    Reply ONLY with a JSON array (no markdown, no extra text). Each element mirrors the single-task schema and \
    appears in the same order as the numbered input transcripts:
    [
      {
        "title": "Concise imperative task title, max 8 words, start with a verb",
        "notes": null or "Bullet-pointed notes using • prefix for each point.",
        "priority": "low|normal|high",
        "category": "health|finance|work|home|personal|other"
      }
    ]

    \(sharedRules)
    """

    // MARK: - Parsing

    private func parse(_ text: String) throws -> VoiceTaskDraft {
        let jsonStr = ClaudeAPIClient.extractJSON(from: text)
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIClient.ClientError.parse(text)
        }
        return draft(from: json)
    }

    private func parseBatch(_ text: String, expected: Int) -> [VoiceTaskDraft] {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNL = s.firstIndex(of: "\n") { s = String(s[s.index(after: firstNL)...]) }
            if let fenceEnd = s.range(of: "```", options: .backwards) { s = String(s[..<fenceEnd.lowerBound]) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let first = s.firstIndex(of: "["), let last = s.lastIndex(of: "]"), first <= last {
            s = String(s[first...last])
        }

        guard let data = s.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.prefix(expected).map { draft(from: $0) }
    }

    private func draft(from json: [String: Any]) -> VoiceTaskDraft {
        let title = json["title"] as? String
        let notes = json["notes"] as? String

        let priority: TaskPriority?
        switch json["priority"] as? String {
        case "high":   priority = .high
        case "low":    priority = .low
        case "normal": priority = .normal
        default:       priority = nil
        }

        let category: TaskCategory?
        switch json["category"] as? String {
        case "health":   category = .health
        case "finance": category = .finance
        case "work":    category = .work
        case "home":    category = .home
        case "personal": category = .personal
        default:         category = .other
        }

        return VoiceTaskDraft(
            title: title,
            notes: notes,
            category: category,
            dueDate: nil,
            priority: priority
        )
    }
}
