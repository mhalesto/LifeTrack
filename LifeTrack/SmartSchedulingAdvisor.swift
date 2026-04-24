//
//  SmartSchedulingAdvisor.swift
//  LifeTrack
//

import Combine
import Foundation

// MARK: - Model

struct ScheduledBlock: Identifiable {
    let id = UUID()
    let taskID: UUID
    let taskTitle: String
    let startDate: Date
    let endDate: Date
    let reasoning: String
    let energyTag: String

    var start: String { startDate.timeString }
    var end: String { endDate.timeString }
    var durationMinutes: Int {
        max(5, Int(endDate.timeIntervalSince(startDate) / 60))
    }
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
    @Published var scheduleSourceLabel: String = ""

    var isConfigured: Bool { ClaudeAPIClient.shared.isConfigured }

    private init() {}

    func optimize(
        tasks: [LifeTask],
        energyLevel: EnergyLevel,
        busyBlocks: [CalendarBusyBlock] = [],
        referenceDate: Date = Date()
    ) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let active = tasks.filter { !$0.isCompleted && !$0.isDeleted }
        guard !active.isEmpty else {
            dayStrategy = "No active tasks — you're free today!"
            scheduledBlocks = []
            unscheduledTitles = []
            scheduleSourceLabel = ""
            return
        }

        guard isConfigured else {
            applyLocalFallback(tasks: active, energyLevel: energyLevel, busyBlocks: busyBlocks, referenceDate: referenceDate)
            return
        }

        do {
            let text = try await ClaudeAPIClient.shared.send(
                system: Self.systemPrompt,
                userContent: buildUserContent(
                    for: active,
                    energy: energyLevel,
                    busyBlocks: busyBlocks,
                    referenceDate: referenceDate
                ),
                maxTokens: 700,
                cacheTTL: 15 * 60
            )
            let parsed = try parse(text, tasks: active, referenceDate: referenceDate)
            let tasksByID = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
            let normalized = CalendarAwareScheduleEngine.normalizedPlan(
                for: parsed.drafts,
                tasksByID: tasksByID,
                busyBlocks: busyBlocks,
                referenceDate: referenceDate
            )
            scheduledBlocks = normalized.blocks
            unscheduledTitles = orderedUnique(parsed.unscheduledTitles + normalized.unscheduledTitles)
            dayStrategy = parsed.strategy
            scheduleSourceLabel = busyBlocks.isEmpty ? "AI schedule" : "AI + Apple Calendar"
            lastRefreshed = Date()
        } catch {
            applyLocalFallback(tasks: active, energyLevel: energyLevel, busyBlocks: busyBlocks, referenceDate: referenceDate)
        }
    }

    // MARK: - Prompt

    private static let systemPrompt = """
    You are LifeTrack's smart scheduling assistant. Given a list of active tasks and the user's \
    current energy level you slot 3–6 of them into a focused work day between 08:00 and 20:00.

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
    - Never overlap with the busy windows listed in the prompt.
    - High-energy tasks (deep work, high priority) in morning if energy is high/moderate; afternoon if low.
    - "energy_tag" must be one of: Deep focus, Quick win, Low effort, Admin.
    - List task_index values that don't fit in "unscheduled".
    - Times in HH:MM 24h format. No overlapping blocks.
    """

    private struct ParsedSchedule {
        let drafts: [CalendarAwareScheduleDraft]
        let unscheduledTitles: [String]
        let strategy: String
    }

    private func buildUserContent(
        for tasks: [LifeTask],
        energy: EnergyLevel,
        busyBlocks: [CalendarBusyBlock],
        referenceDate: Date
    ) -> String {
        let today = referenceDate
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
        let busySummary: String
        if busyBlocks.isEmpty {
            busySummary = "None"
        } else {
            busySummary = busyBlocks
                .prefix(12)
                .map { "- \($0.startDate.timeString)-\($0.endDate.timeString) busy" }
                .joined(separator: "\n")
        }

        return """
        Today is \(fmt.string(from: today)). Day: \(cal.weekdaySymbols[cal.component(.weekday, from: today) - 1]).
        User energy level: \(energy.label).

        Apple Calendar busy windows (titles hidden for privacy):
        \(busySummary)

        Active tasks:
        \(list)
        """
    }

    // MARK: - Parse

    private func parse(_ text: String, tasks: [LifeTask], referenceDate: Date) throws -> ParsedSchedule {
        let jsonStr = ClaudeAPIClient.extractJSON(from: text)
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIClient.ClientError.parse(text)
        }

        var drafts: [CalendarAwareScheduleDraft] = []
        if let items = json["schedule"] as? [[String: Any]] {
            for item in items {
                guard let idx = item["task_index"] as? Int, idx >= 1, idx <= tasks.count else { continue }
                let task = tasks[idx - 1]
                let startText = item["start"] as? String
                let endText = item["end"] as? String
                let startDate = date(from: startText, on: referenceDate)
                let endDate = date(from: endText, on: referenceDate)
                let durationMinutes: Int
                if let startDate, let endDate, endDate > startDate {
                    durationMinutes = max(5, Int(endDate.timeIntervalSince(startDate) / 60))
                } else {
                    durationMinutes = task.scheduledDurationMinutes
                }

                drafts.append(
                    CalendarAwareScheduleDraft(
                        taskID: task.id,
                        taskTitle: task.title,
                        preferredStartDate: startDate,
                        durationMinutes: durationMinutes,
                        reasoning: item["reasoning"] as? String ?? "",
                        energyTag: item["energy_tag"] as? String ?? "Focus"
                    )
                )
            }
        }

        var unscheduledTitles: [String] = []
        if let indices = json["unscheduled"] as? [Int] {
            for idx in indices where idx >= 1 && idx <= tasks.count {
                unscheduledTitles.append(tasks[idx - 1].title)
            }
        }

        let strategy = (json["day_strategy"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ParsedSchedule(
            drafts: drafts,
            unscheduledTitles: orderedUnique(unscheduledTitles),
            strategy: strategy.isEmpty ? "Focus blocks arranged around your calendar." : strategy
        )
    }

    private func applyLocalFallback(
        tasks: [LifeTask],
        energyLevel: EnergyLevel,
        busyBlocks: [CalendarBusyBlock],
        referenceDate: Date
    ) {
        let focusTasks = DailyFocusPlanner.recommendations(from: tasks, energyLevel: energyLevel)
            .map(\.task)
        let plan = CalendarAwareScheduleEngine.sequentialPlan(
            for: Array(focusTasks.prefix(6)),
            busyBlocks: busyBlocks,
            referenceDate: referenceDate,
            energyLevel: energyLevel
        )
        let scheduledIDs = Set(plan.blocks.map(\.taskID))
        let remainingTitles = tasks
            .filter { !scheduledIDs.contains($0.id) }
            .map(\.title)

        scheduledBlocks = plan.blocks
        unscheduledTitles = orderedUnique(remainingTitles + plan.unscheduledTitles)
        dayStrategy = localStrategy(for: energyLevel, busyBlockCount: busyBlocks.count)
        scheduleSourceLabel = busyBlocks.isEmpty ? "Local schedule" : "Local + Apple Calendar"
        error = nil
        lastRefreshed = Date()
    }

    private func localStrategy(for energyLevel: EnergyLevel, busyBlockCount: Int) -> String {
        if busyBlockCount > 0 {
            return "Calendar-aware focus blocks leave room around \(busyBlockCount) busy \(busyBlockCount == 1 ? "event" : "events")."
        }

        switch energyLevel {
        case .high:
            return "Use your strongest hours first, then taper into lighter work."
        case .moderate:
            return "Mix one deeper block with a few clean quick wins."
        case .low:
            return "Keep momentum with shorter tasks and protected recovery gaps."
        case .unknown:
            return "Focus blocks were arranged from your due dates, priorities, and durations."
        }
    }

    private func date(from clockTime: String?, on referenceDate: Date) -> Date? {
        guard let clockTime else {
            return nil
        }

        let parts = clockTime.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Calendar.current.startOfDay(for: referenceDate)
        )
    }

    private func orderedUnique(_ titles: [String]) -> [String] {
        var seen: Set<String> = []
        return titles.filter { seen.insert($0).inserted }
    }
}
