//
//  SmartSchedulingAdvisor.swift
//  LifeTrack
//

import Combine
import Foundation

// MARK: - Model

struct ScheduledBlock: Identifiable {
    let id = UUID()
    let start: String
    let end: String
    let taskID: UUID
    let taskTitle: String
    let reasoning: String
    let energyTag: String
}

// MARK: - Advisor

@MainActor
final class SmartSchedulingAdvisor: ObservableObject {
    static let shared = SmartSchedulingAdvisor()

    @Published var scheduledBlocks: [ScheduledBlock] = []
    @Published var unscheduledTitles: [String] = []
    @Published var dayStrategy: String = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastRefreshed: Date?

    var isConfigured: Bool { ClaudeAPIClient.shared.isConfigured }

    private init() {}

    func optimize(tasks: [LifeTask], energyLevel: EnergyLevel) async {
        guard isConfigured else {
            error = ClaudeAPIClient.ClientError.missingAPIKey.localizedDescription
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let active = tasks.filter { !$0.isCompleted && !$0.isDeleted }
        guard !active.isEmpty else {
            dayStrategy = "No active tasks — you're free today!"
            scheduledBlocks = []
            unscheduledTitles = []
            return
        }

        do {
            let text = try await ClaudeAPIClient.shared.send(
                system: Self.systemPrompt,
                userContent: buildUserContent(for: active, energy: energyLevel),
                maxTokens: 700,
                cacheTTL: 15 * 60
            )
            let parsed = try parse(text, tasks: active)
            scheduledBlocks = parsed.blocks
            unscheduledTitles = parsed.unscheduled
            dayStrategy = parsed.strategy
            lastRefreshed = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Prompt

    private static let systemPrompt = """
    You are LifeTrack's smart scheduling assistant. Given a list of active tasks and the user's \
    current energy level you slot 3–6 of them into a focused work day between 09:00 and 18:00.

    Reply ONLY with this JSON (no markdown, no extra text):
    {
      "schedule": [
        {"start": "09:00", "end": "10:30", "task_index": 1, "reasoning": "max 12 words why now", "energy_tag": "Deep focus|Quick win|Low effort|Admin"}
      ],
      "unscheduled": [3, 5],
      "day_strategy": "One sharp sentence about today's approach"
    }

    Rules:
    - Schedule 3–6 tasks max. Leave gaps between blocks (15 min).
    - High-energy tasks (deep work, high priority) in morning if energy is high/moderate; afternoon if low.
    - "energy_tag" must be one of: Deep focus, Quick win, Low effort, Admin.
    - List task_index values that don't fit in "unscheduled".
    - Times in HH:MM 24h format. No overlapping blocks.
    """

    private func buildUserContent(for tasks: [LifeTask], energy: EnergyLevel) -> String {
        let today = Date()
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateStyle = .short

        let list = tasks.prefix(20).enumerated().map { i, t in
            var parts = ["\(i+1). \"\(t.title)\""]
            parts.append("cat:\(t.category.rawValue)")
            let days = cal.dateComponents([.day], from: today, to: t.dueDate).day ?? 0
            let dueLabel = days < 0 ? "\(abs(days))d overdue" : days == 0 ? "today" : "in \(days)d"
            parts.append("due:\(dueLabel)")
            parts.append("pri:\(t.priorityRawValue)")
            if let mins = t.estimatedDurationMinutes { parts.append("\(mins)min") } else { parts.append("30min") }
            return parts.joined(separator: " ")
        }.joined(separator: "\n")

        return """
        Today is \(fmt.string(from: today)). Day: \(cal.weekdaySymbols[cal.component(.weekday, from: today) - 1]).
        User energy level: \(energy.label).

        Active tasks:
        \(list)
        """
    }

    // MARK: - Parse

    private func parse(_ text: String, tasks: [LifeTask]) throws -> (blocks: [ScheduledBlock], unscheduled: [String], strategy: String) {
        let jsonStr = ClaudeAPIClient.extractJSON(from: text)
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIClient.ClientError.parse(text)
        }

        var blocks: [ScheduledBlock] = []
        if let items = json["schedule"] as? [[String: Any]] {
            for item in items {
                guard let idx = item["task_index"] as? Int, idx >= 1, idx <= tasks.count else { continue }
                let task = tasks[idx - 1]
                blocks.append(ScheduledBlock(
                    start: item["start"] as? String ?? "09:00",
                    end: item["end"] as? String ?? "10:00",
                    taskID: task.id,
                    taskTitle: task.title,
                    reasoning: item["reasoning"] as? String ?? "",
                    energyTag: item["energy_tag"] as? String ?? "Focus"
                ))
            }
        }

        var unscheduled: [String] = []
        if let indices = json["unscheduled"] as? [Int] {
            for idx in indices where idx >= 1 && idx <= tasks.count {
                unscheduled.append(tasks[idx - 1].title)
            }
        }

        let strategy = json["day_strategy"] as? String ?? ""
        return (blocks, unscheduled, strategy)
    }
}
