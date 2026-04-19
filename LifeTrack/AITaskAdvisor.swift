//
//  AITaskAdvisor.swift
//  LifeTrack
//

import Combine
import Foundation

// MARK: - Model

struct AITaskSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let taskID: UUID
    let taskTitle: String
    let reasoning: String
    let badge: String
    let suggestedDate: Date?

    enum SuggestionType {
        case focus
        case reschedule
    }
}

// MARK: - Advisor

@MainActor
final class AITaskAdvisor: ObservableObject {
    static let shared = AITaskAdvisor()

    @Published var focusSuggestions: [AITaskSuggestion] = []
    @Published var rescheduleSuggestions: [AITaskSuggestion] = []
    @Published var overallInsight: String = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastRefreshed: Date?

    var apiKey: String {
        UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.claudeAPIKey) ?? ""
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    func analyze(tasks: [LifeTask]) async {
        guard isConfigured else {
            error = "Add your Claude API key in Settings to use AI suggestions."
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let active = tasks.filter { !$0.isCompleted && !$0.isDeleted }
        guard !active.isEmpty else {
            overallInsight = "No active tasks to analyse — you're all clear!"
            focusSuggestions = []
            rescheduleSuggestions = []
            return
        }

        do {
            let responseText = try await callClaude(prompt: buildPrompt(for: active))
            let parsed = try parse(responseText, tasks: active)
            focusSuggestions = parsed.focus
            rescheduleSuggestions = parsed.reschedule
            overallInsight = parsed.insight
            lastRefreshed = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Prompt

    private func buildPrompt(for tasks: [LifeTask]) -> String {
        let today = Date()
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateStyle = .short

        let list = tasks.prefix(25).enumerated().map { i, t in
            var parts = ["\(i+1). \"\(t.title)\""]
            parts.append("cat:\(t.category.rawValue)")
            let days = cal.dateComponents([.day], from: today, to: t.dueDate).day ?? 0
            let dueLabel = days < 0 ? "\(abs(days))d overdue" : days == 0 ? "today" : "in \(days)d"
            parts.append("due:\(fmt.string(from: t.dueDate))(\(dueLabel))")
            parts.append("pri:\(t.priority.rawValue)")
            if let mins = t.estimatedDurationMinutes { parts.append("\(mins)min") }
            return parts.joined(separator: " ")
        }.joined(separator: "\n")

        return """
        Today is \(fmt.string(from: today)). Day of week: \(cal.weekdaySymbols[cal.component(.weekday, from: today) - 1]).

        Active tasks:
        \(list)

        Reply ONLY with this JSON (no markdown, no extra text):
        {
          "focus": [
            {"index": 1, "reasoning": "max 12 words why", "badge": "This morning|After lunch|This evening"}
          ],
          "reschedule": [
            {"index": 2, "reasoning": "max 12 words why", "days_from_now": 1}
          ],
          "insight": "One sharp observation about workload or patterns, max 20 words"
        }

        Rules: focus = 2-3 tasks, reschedule = 0-2 tasks. Only suggest reschedule when clearly beneficial.
        """
    }

    // MARK: - API Call

    private func callClaude(prompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 60

        let bodyObj: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 512,
            "messages": [["role": "user", "content": prompt]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: bodyObj)

        let (data, response) = try await URLSession.shared.data(for: req)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let rawBody = String(data: data, encoding: .utf8) ?? "empty"

        guard statusCode == 200 else {
            throw NSError(domain: "Anthropic", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode): \(rawBody.prefix(300))"])
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = (json?["content"] as? [[String: Any]])?.first?["text"] as? String else {
            throw NSError(domain: "Anthropic", code: -1, userInfo: [NSLocalizedDescriptionKey: "Parse failed. Response: \(rawBody.prefix(300))"])
        }
        return text
    }

    // MARK: - Parse

    private func parse(_ text: String, tasks: [LifeTask]) throws -> (focus: [AITaskSuggestion], reschedule: [AITaskSuggestion], insight: String) {
        let jsonString = Self.extractJSON(from: text)
        NSLog("[AITaskAdvisor] parse raw=%@ extracted=%@", text.prefix(400).description, jsonString.prefix(400).description)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Anthropic", code: -2, userInfo: [NSLocalizedDescriptionKey: "Couldn't read Claude's reply as JSON. First 200 chars: \(text.prefix(200))"])
        }

        let cal = Calendar.current
        var focus: [AITaskSuggestion] = []
        var reschedule: [AITaskSuggestion] = []

        if let items = json["focus"] as? [[String: Any]] {
            for item in items {
                guard let idx = item["index"] as? Int, idx >= 1, idx <= tasks.count else { continue }
                let task = tasks[idx - 1]
                focus.append(AITaskSuggestion(
                    type: .focus,
                    taskID: task.id,
                    taskTitle: task.title,
                    reasoning: item["reasoning"] as? String ?? "",
                    badge: item["badge"] as? String ?? "Today",
                    suggestedDate: nil
                ))
            }
        }

        if let items = json["reschedule"] as? [[String: Any]] {
            for item in items {
                guard let idx = item["index"] as? Int, idx >= 1, idx <= tasks.count else { continue }
                let task = tasks[idx - 1]
                let days = item["days_from_now"] as? Int ?? 1
                let date = cal.date(byAdding: .day, value: days, to: Date())
                reschedule.append(AITaskSuggestion(
                    type: .reschedule,
                    taskID: task.id,
                    taskTitle: task.title,
                    reasoning: item["reasoning"] as? String ?? "",
                    badge: days == 1 ? "Tomorrow" : "In \(days) days",
                    suggestedDate: date
                ))
            }
        }

        let insight = json["insight"] as? String ?? ""
        return (focus, reschedule, insight)
    }

    private static func extractJSON(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNL = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNL)...])
            }
            if let fenceEnd = s.range(of: "```", options: .backwards) {
                s = String(s[..<fenceEnd.lowerBound])
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}"), first <= last {
            s = String(s[first...last])
        }
        return s
    }
}
