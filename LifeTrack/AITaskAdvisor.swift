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

    var isConfigured: Bool { ClaudeAPIClient.shared.isConfigured }

    func analyze(tasks: [LifeTask]) async {
        guard isConfigured else {
            error = ClaudeAPIClient.ClientError.missingAPIKey.localizedDescription
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
            let responseText = try await ClaudeAPIClient.shared.send(
                system: Self.systemPrompt,
                userContent: buildUserContent(for: active),
                maxTokens: 512,
                cacheTTL: 10 * 60
            )
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

    private static let systemPrompt = """
    You are LifeTrack's task-focus advisor. Given an active task list you pick 2–3 tasks the user \
    should focus on today and 0–2 tasks to reschedule. You write one short insight about their workload.

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

    Rules: focus = 2-3 tasks, reschedule = 0-2 tasks. Only suggest reschedule when clearly beneficial. \
    Indexes must refer to the numbered active tasks in the user message. `badge` must be one of the \
    listed options. `days_from_now` must be a positive integer.
    """

    private func buildUserContent(for tasks: [LifeTask]) -> String {
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
        """
    }

    // MARK: - Parse

    private func parse(_ text: String, tasks: [LifeTask]) throws -> (focus: [AITaskSuggestion], reschedule: [AITaskSuggestion], insight: String) {
        let jsonString = ClaudeAPIClient.extractJSON(from: text)
        NSLog("[AITaskAdvisor] parse raw=%@ extracted=%@", text.prefix(400).description, jsonString.prefix(400).description)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIClient.ClientError.parse(text)
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
}
