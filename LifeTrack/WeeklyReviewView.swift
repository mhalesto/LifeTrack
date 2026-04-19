//
//  WeeklyReviewView.swift
//  LifeTrack
//

import SwiftData
import SwiftUI

// MARK: - Step Enum

enum WeeklyReviewStep: Int, CaseIterable, Identifiable {
    case wins       = 0
    case reschedule = 1
    case mindSweep  = 2
    case nextWeek   = 3
    case summary    = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .wins:       "Wins"
        case .reschedule: "Clear"
        case .mindSweep:  "Capture"
        case .nextWeek:   "Preview"
        case .summary:    "Done"
        }
    }
}

// MARK: - Summary Data

struct WeeklyReviewSummary {
    let weekStart: Date
    let weekEnd: Date
    let completedCount: Int
    let rescheduledCount: Int
    let newIdeasCount: Int
    let nextWeekCount: Int
    let topCategoryName: String?
    let longestStreakThisWeek: Int
}

// MARK: - Main View

struct WeeklyReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]

    @State private var step: WeeklyReviewStep = .wins
    @State private var stepForward = true
    @State private var reschedulePlans: [UUID: Date] = [:]
    @State private var skippedIDs: Set<UUID> = []
    @State private var mindSweepTitles: [String] = [""]
    @State private var renderedCard: UIImage?

    // MARK: Computed task lists

    private var cal: Calendar { .current }

    private var weekCutoff: Date {
        cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date())) ?? Date()
    }

    private var completedThisWeek: [LifeTask] {
        tasks.filter {
            !$0.isDeleted && $0.isCompleted &&
            ($0.completedAt ?? $0.updatedAt) >= weekCutoff
        }.sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    private var overdueUnfinished: [LifeTask] {
        tasks.filter { !$0.isDeleted && !$0.isCompleted && $0.isOverdue }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var nextWeekTasks: [LifeTask] {
        let now = Date()
        guard let end = cal.date(byAdding: .day, value: 8, to: now) else { return [] }
        return tasks.filter {
            !$0.isDeleted && !$0.isCompleted && $0.dueDate >= now && $0.dueDate <= end
        }.sorted { $0.dueDate < $1.dueDate }
    }

    private var topCategoryName: String? {
        let counts = completedThisWeek
            .map { $0.categoryOption(customCategories: customCategories).title }
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private var longestStreakThisWeek: Int {
        let habits = tasks.filter { $0.isHabit && !$0.isDeleted }
        guard !habits.isEmpty else { return 0 }
        let summaries = HabitEngine.summaries(from: habits)
        return summaries.map(\.currentStreak).max() ?? 0
    }

    private func makeSummary() -> WeeklyReviewSummary {
        let ideas = mindSweepTitles.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return WeeklyReviewSummary(
            weekStart: weekCutoff,
            weekEnd: Date(),
            completedCount: completedThisWeek.count,
            rescheduledCount: reschedulePlans.count,
            newIdeasCount: ideas.count,
            nextWeekCount: nextWeekTasks.count,
            topCategoryName: topCategoryName,
            longestStreakThisWeek: longestStreakThisWeek
        )
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    progressBar

                    Group {
                        switch step {
                        case .wins:
                            WinsStep(
                                completedTasks: completedThisWeek,
                                customCategories: customCategories,
                                onContinue: advance
                            )
                        case .reschedule:
                            RescheduleStep(
                                overdueTasks: overdueUnfinished,
                                reschedulePlans: $reschedulePlans,
                                skippedIDs: $skippedIDs,
                                onContinue: advance
                            )
                        case .mindSweep:
                            MindSweepStep(
                                titles: $mindSweepTitles,
                                onContinue: advance
                            )
                        case .nextWeek:
                            NextWeekStep(
                                tasks: nextWeekTasks,
                                customCategories: customCategories,
                                onContinue: { advance(); renderCard() }
                            )
                        case .summary:
                            SummaryStep(
                                summary: makeSummary(),
                                renderedCard: renderedCard,
                                onFinish: commitAndDismiss
                            )
                        }
                    }
                    .animation(.snappy(duration: 0.38), value: step)
                    .transition(.asymmetric(
                        insertion: .move(edge: stepForward ? .trailing : .leading).combined(with: .opacity),
                        removal:   .move(edge: stepForward ? .leading  : .trailing).combined(with: .opacity)
                    ))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
        }
        .onAppear {
            if overdueUnfinished.isEmpty && step == .wins {
                // pre-skip reschedule step silently if nothing to do
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(WeeklyReviewStep.allCases) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue
                          ? LifeTrackTheme.ColorPalette.accent
                          : LifeTrackTheme.ColorPalette.accent.opacity(0.18))
                    .frame(height: 4)
                    .animation(.snappy(duration: 0.35), value: step)
            }
        }
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .padding(.top, LifeTrackTheme.Spacing.medium)
        .padding(.bottom, LifeTrackTheme.Spacing.large)
    }

    // MARK: - Actions

    private func advance() {
        guard let next = WeeklyReviewStep(rawValue: step.rawValue + 1) else { return }
        stepForward = true
        withAnimation(.snappy(duration: 0.38)) { step = next }
    }

    @MainActor
    private func renderCard() {
        let summary = makeSummary()
        let cardView = WeeklySummaryCardView(summary: summary)
            .frame(width: 360, height: 500)
            .background(LifeTrackTheme.appBackground)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        renderedCard = renderer.uiImage
    }

    private func commitAndDismiss() {
        let now = Date()

        // Apply reschedule plans
        for task in overdueUnfinished {
            if let newDate = reschedulePlans[task.id] {
                task.dueDate = newDate
                task.updatedAt = now
            }
        }

        // Insert mind sweep tasks
        let newTitles = mindSweepTitles.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for title in newTitles {
            let task = LifeTask(title: title)
            task.dueDate = cal.date(byAdding: .day, value: 7, to: now) ?? now
            modelContext.insert(task)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Step 1: Wins This Week

private struct WinsStep: View {
    let completedTasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            weeklyStepHeader(
                icon: "trophy.fill",
                iconColor: Color(red: 0.95, green: 0.72, blue: 0.1),
                title: "This Week's Wins",
                subtitle: completedTasks.isEmpty
                    ? "Nothing completed yet — the week isn't over!"
                    : "\(completedTasks.count) task\(completedTasks.count == 1 ? "" : "s") crushed this week. 🎉"
            )

            if completedTasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        Text("Keep going — every task counts.")
                            .font(.subheadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: LifeTrackTheme.Spacing.small) {
                        ForEach(completedTasks.prefix(30)) { task in
                            WinRow(task: task, customCategories: customCategories)
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                }
            }

            weeklyActionButton(title: "Next: Clear the Backlog", action: onContinue)
        }
    }
}

private struct WinRow: View {
    let task: LifeTask
    let customCategories: [CustomTaskCategory]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                Text(task.categoryOption(customCategories: customCategories).title)
                    .font(.caption2)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Spacer()

            if let date = task.completedAt {
                Text(date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
        }
        .padding(LifeTrackTheme.Spacing.medium)
        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Step 2: Reschedule Unfinished

private struct RescheduleStep: View {
    let overdueTasks: [LifeTask]
    @Binding var reschedulePlans: [UUID: Date]
    @Binding var skippedIDs: Set<UUID>
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            weeklyStepHeader(
                icon: "arrow.clockwise.circle.fill",
                iconColor: Color(red: 0.45, green: 0.35, blue: 0.95),
                title: "Clear the Backlog",
                subtitle: overdueTasks.isEmpty
                    ? "No overdue tasks — you're on top of it!"
                    : "\(overdueTasks.count) overdue. Reschedule or skip each one."
            )

            if overdueTasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                        Text("Inbox zero on overdue tasks!")
                            .font(.subheadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: LifeTrackTheme.Spacing.small) {
                        ForEach(overdueTasks) { task in
                            RescheduleRow(
                                task: task,
                                chosenDate: Binding(
                                    get: { reschedulePlans[task.id] },
                                    set: { reschedulePlans[task.id] = $0 }
                                ),
                                isSkipped: skippedIDs.contains(task.id),
                                onSkip: {
                                    skippedIDs.insert(task.id)
                                    reschedulePlans.removeValue(forKey: task.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                }
            }

            weeklyActionButton(title: "Next: Mind Sweep", action: onContinue)
        }
    }
}

private struct RescheduleRow: View {
    let task: LifeTask
    @Binding var chosenDate: Date?
    let isSkipped: Bool
    let onSkip: () -> Void

    private var cal: Calendar { .current }
    private var today: Date { cal.startOfDay(for: Date()) }

    private var options: [(label: String, date: Date)] {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let weekend  = nextWeekend()
        let nextWeek = cal.date(byAdding: .day, value: 7, to: today)!
        return [
            ("Today",      today.addingTimeInterval(23 * 3600)),
            ("Tomorrow",   tomorrow.addingTimeInterval(9 * 3600)),
            ("Weekend",    weekend.addingTimeInterval(10 * 3600)),
            ("Next week",  nextWeek.addingTimeInterval(9 * 3600))
        ]
    }

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSkipped
                            ? LifeTrackTheme.ColorPalette.secondaryText
                            : LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)
                        .strikethrough(isSkipped)

                    Spacer()

                    if isSkipped {
                        Text("Skipped")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                }

                if !isSkipped {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(options, id: \.label) { option in
                                let selected = chosenDate.map { cal.isDate($0, inSameDayAs: option.date) } ?? false
                                Button {
                                    chosenDate = option.date
                                } label: {
                                    Text(option.label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(selected ? .white : LifeTrackTheme.ColorPalette.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(selected
                                                ? LifeTrackTheme.ColorPalette.accent
                                                : LifeTrackTheme.ColorPalette.accent.opacity(0.1))
                                        )
                                }
                                .buttonStyle(.plain)
                                .animation(.snappy(duration: 0.18), value: selected)
                            }

                            Button(action: onSkip) {
                                Text("Skip")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(LifeTrackTheme.ColorPalette.secondaryText.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func nextWeekend() -> Date {
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekday = 7 // Saturday
        return cal.date(from: comps) ?? cal.date(byAdding: .day, value: 6, to: today)!
    }
}

// MARK: - Step 3: Mind Sweep

private struct MindSweepStep: View {
    @Binding var titles: [String]
    let onContinue: () -> Void

    @FocusState private var focusedIndex: Int?

    private var validCount: Int {
        titles.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            weeklyStepHeader(
                icon: "brain.head.profile",
                iconColor: Color(red: 0.35, green: 0.6, blue: 0.95),
                title: "Mind Sweep",
                subtitle: "Dump everything on your mind. No judgement — capture it all."
            )

            ScrollView {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(titles.indices, id: \.self) { i in
                        HStack(spacing: 10) {
                            Image(systemName: "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent.opacity(0.5))

                            TextField("New task or idea…", text: $titles[i])
                                .font(.subheadline)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                .focused($focusedIndex, equals: i)
                                .submitLabel(i == titles.count - 1 ? .done : .next)
                                .onSubmit {
                                    if i == titles.count - 1 {
                                        if !titles[i].trimmingCharacters(in: .whitespaces).isEmpty {
                                            titles.append("")
                                            focusedIndex = titles.count - 1
                                        }
                                    } else {
                                        focusedIndex = i + 1
                                    }
                                }
                        }
                        .padding(LifeTrackTheme.Spacing.medium)
                        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        titles.append("")
                        focusedIndex = titles.count - 1
                    } label: {
                        Label("Add another", systemImage: "plus.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.medium)
            }

            weeklyActionButton(
                title: validCount > 0 ? "Captured \(validCount) idea\(validCount == 1 ? "" : "s") — Preview Next Week" : "Skip to Next Week Preview",
                action: onContinue
            )
        }
    }
}

// MARK: - Step 4: Next Week Preview

private struct NextWeekStep: View {
    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            weeklyStepHeader(
                icon: "calendar.badge.plus",
                iconColor: Color(red: 0.2, green: 0.7, blue: 0.5),
                title: "Next Week",
                subtitle: tasks.isEmpty
                    ? "Nothing scheduled yet — add tasks after this review."
                    : "\(tasks.count) task\(tasks.count == 1 ? "" : "s") lined up. You're ready."
            )

            ScrollView {
                LazyVStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(tasks) { task in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                    .lineLimit(1)
                                Text(task.dueDate, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            }

                            Spacer()

                            Text(task.categoryOption(customCategories: customCategories).title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(LifeTrackTheme.ColorPalette.accent.opacity(0.1), in: Capsule())
                        }
                        .padding(LifeTrackTheme.Spacing.medium)
                        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.medium)
            }

            weeklyActionButton(title: "See My Summary →", action: onContinue)
        }
    }
}

// MARK: - Step 5: Summary

private struct SummaryStep: View {
    let summary: WeeklyReviewSummary
    let renderedCard: UIImage?
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            weeklyStepHeader(
                icon: "party.popper.fill",
                iconColor: Color(red: 0.95, green: 0.35, blue: 0.65),
                title: "Review Complete!",
                subtitle: "Here's your week at a glance."
            )

            ScrollView {
                VStack(spacing: LifeTrackTheme.Spacing.large) {
                    WeeklySummaryCardView(summary: summary)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)

                    if let image = renderedCard {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("My Week in Review", image: Image(uiImage: image))
                        ) {
                            Label("Share Summary Card", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(LifeTrackTheme.ColorPalette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    }
                }
                .padding(.top, LifeTrackTheme.Spacing.medium)
                .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
            }

            weeklyActionButton(title: "Start the Week!", icon: "sunrise.fill", action: onFinish)
        }
    }
}

// MARK: - Summary Card View (also used for ImageRenderer)

struct WeeklySummaryCardView: View {
    let summary: WeeklyReviewSummary

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.08, blue: 0.28),
                    Color(red: 0.06, green: 0.05, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("WEEKLY REVIEW")
                        .font(.caption2.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(weekRangeString)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 28)

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    summaryStatBox(
                        value: "\(summary.completedCount)",
                        label: "Completed",
                        icon: "checkmark.circle.fill",
                        color: Color(red: 0.18, green: 0.82, blue: 0.48)
                    )
                    summaryStatBox(
                        value: "\(summary.longestStreakThisWeek)",
                        label: "Best Streak",
                        icon: "flame.fill",
                        color: Color(red: 0.95, green: 0.45, blue: 0.15)
                    )
                    summaryStatBox(
                        value: "\(summary.rescheduledCount)",
                        label: "Rescheduled",
                        icon: "arrow.clockwise",
                        color: Color(red: 0.55, green: 0.45, blue: 0.95)
                    )
                    summaryStatBox(
                        value: "\(summary.nextWeekCount)",
                        label: "Next Week",
                        icon: "calendar.badge.plus",
                        color: Color(red: 0.2, green: 0.72, blue: 0.82)
                    )
                }
                .padding(.bottom, 20)

                if summary.newIdeasCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(Color(red: 0.45, green: 0.72, blue: 0.95))
                        Text("\(summary.newIdeasCount) new idea\(summary.newIdeasCount == 1 ? "" : "s") captured")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.bottom, 8)
                }

                if let category = summary.topCategoryName {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.1))
                        Text("Top category: \(category)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.bottom, 8)
                }

                Spacer()

                // Footer
                HStack {
                    Image(systemName: "l.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                    Text("LifeTrack")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text(Date(), format: .dateTime.year())
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4/5, contentMode: .fit)
    }

    private var weekRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: summary.weekStart)
        let end = formatter.string(from: summary.weekEnd)
        return "\(start) – \(end)"
    }

    private func summaryStatBox(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Shared Helpers

private func weeklyStepHeader(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
        }
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
    .padding(.bottom, LifeTrackTheme.Spacing.small)
}

private func weeklyActionButton(title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
            }
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
        .padding(.top, LifeTrackTheme.Spacing.medium)
    }
    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97))
}
