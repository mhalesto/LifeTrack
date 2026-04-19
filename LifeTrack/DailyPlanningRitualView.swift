//
//  DailyPlanningRitualView.swift
//  LifeTrack
//

import SwiftUI
import SwiftData

// MARK: - Main View

struct DailyPlanningRitualView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
    let onToggleCompletion: (LifeTask) -> Void
    let onReschedule: (LifeTask, Date) -> Void

    @State private var step: RitualStep = .yesterdayReview
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var taskDurations: [UUID: Int] = [:]
    @State private var stepTransitionForward = true

    private var yesterdayTasks: [LifeTask] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return tasks.filter {
            !$0.isCompleted && !$0.isDeleted &&
            Calendar.current.isDate($0.dueDate, inSameDayAs: yesterday)
        }
    }

    private var todayCandidates: [DailyFocusRecommendation] {
        DailyFocusPlanner.recommendations(from: tasks)
    }

    private var selectedTasks: [LifeTask] {
        todayCandidates
            .map(\.task)
            .filter { selectedTaskIDs.contains($0.id) }
    }

    private var totalCommittedMinutes: Int {
        selectedTasks.reduce(0) { $0 + (taskDurations[$1.id] ?? $1.scheduledDurationMinutes) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    progressBar
                    stepContent
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: stepTransitionForward ? .trailing : .leading).combined(with: .opacity),
                                removal: .move(edge: stepTransitionForward ? .leading : .trailing).combined(with: .opacity)
                            )
                        )
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
            if yesterdayTasks.isEmpty && step == .yesterdayReview {
                advanceStep()
            }
            for rec in todayCandidates.prefix(3) {
                selectedTaskIDs.insert(rec.task.id)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(RitualStep.allCases) { s in
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

    // MARK: - Step Routing

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .yesterdayReview:
            YesterdayReviewStep(
                tasks: yesterdayTasks,
                customCategories: customCategories,
                onComplete: onToggleCompletion,
                onMoveToToday: { moveToToday($0) },
                onContinue: advanceStep
            )
        case .pickFocus:
            PickFocusStep(
                candidates: todayCandidates,
                customCategories: customCategories,
                selectedIDs: $selectedTaskIDs,
                onContinue: advanceStep
            )
        case .timeBox:
            TimeBoxStep(
                selectedTasks: selectedTasks,
                taskDurations: $taskDurations,
                totalMinutes: totalCommittedMinutes,
                onContinue: advanceStep
            )
        case .launchDay:
            LaunchDayStep(
                selectedTasks: selectedTasks,
                taskDurations: taskDurations,
                totalMinutes: totalCommittedMinutes,
                onStart: commitAndDismiss
            )
        }
    }

    // MARK: - Actions

    private func advanceStep() {
        guard let next = RitualStep(rawValue: step.rawValue + 1) else { return }
        stepTransitionForward = true
        withAnimation(.snappy(duration: 0.38)) { step = next }
    }

    private func moveToToday(_ task: LifeTask) {
        task.dueDate = Calendar.current.startOfDay(for: Date()).addingTimeInterval(23 * 3600)
        task.updatedAt = Date()
        try? modelContext.save()
    }

    private func commitAndDismiss() {
        for task in selectedTasks {
            let duration = taskDurations[task.id] ?? task.scheduledDurationMinutes
            if task.estimatedDurationMinutes != duration {
                task.estimatedDurationMinutes = duration
                task.updatedAt = Date()
            }
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Step Enum

enum RitualStep: Int, CaseIterable, Identifiable {
    case yesterdayReview = 0
    case pickFocus       = 1
    case timeBox         = 2
    case launchDay       = 3

    var id: Int { rawValue }
}

// MARK: - Step 1: Yesterday Review

private struct YesterdayReviewStep: View {
    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
    let onComplete: (LifeTask) -> Void
    let onMoveToToday: (LifeTask) -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                icon: "moon.stars.fill",
                iconColor: Color(red: 0.45, green: 0.35, blue: 0.95),
                title: "Clear the Decks",
                subtitle: tasks.isEmpty
                    ? "Clean slate — nothing left over from yesterday."
                    : "\(tasks.count) task\(tasks.count == 1 ? "" : "s") carried over from yesterday."
            )

            if tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                        Text("Yesterday was a great day!")
                            .font(.headline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: LifeTrackTheme.Spacing.small) {
                        ForEach(tasks) { task in
                            YesterdayTaskRow(
                                task: task,
                                customCategories: customCategories,
                                onComplete: { onComplete(task) },
                                onMoveToToday: { onMoveToToday(task) }
                            )
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                }
            }

            Spacer(minLength: 0)
            continueButton(title: "Continue", action: onContinue)
        }
    }
}

private struct YesterdayTaskRow: View {
    let task: LifeTask
    let customCategories: [CustomTaskCategory]
    let onComplete: () -> Void
    let onMoveToToday: () -> Void

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Button(action: onComplete) {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(LifeTrackTheme.ColorPalette.success.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onMoveToToday) {
                        Label("Move to Today", systemImage: "arrow.right.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(LifeTrackTheme.ColorPalette.accent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Step 2: Pick Focus

private struct PickFocusStep: View {
    let candidates: [DailyFocusRecommendation]
    let customCategories: [CustomTaskCategory]
    @Binding var selectedIDs: Set<UUID>
    let onContinue: () -> Void

    private var selectedCount: Int { selectedIDs.count }
    private var canContinue: Bool { selectedCount >= 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                icon: "scope",
                iconColor: LifeTrackTheme.ColorPalette.accent,
                title: "What Matters Most?",
                subtitle: "Pick 1–5 tasks to commit to today. \(selectedCount > 0 ? "\(selectedCount) selected." : "")"
            )

            ScrollView {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(candidates) { rec in
                        FocusCandidateRow(
                            recommendation: rec,
                            customCategories: customCategories,
                            isSelected: selectedIDs.contains(rec.task.id),
                            onToggle: {
                                if selectedIDs.contains(rec.task.id) {
                                    selectedIDs.remove(rec.task.id)
                                } else if selectedIDs.count < 5 {
                                    selectedIDs.insert(rec.task.id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.large)
            }

            continueButton(
                title: canContinue ? "Time-Box My Picks (\(selectedCount))" : "Select at least 1 task",
                action: onContinue,
                disabled: !canContinue
            )
        }
    }
}

private struct FocusCandidateRow: View {
    let recommendation: DailyFocusRecommendation
    let customCategories: [CustomTaskCategory]
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.accent.opacity(0.1))
                        .frame(width: 28, height: 28)
                    Image(systemName: isSelected ? "checkmark" : "circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isSelected ? .white : LifeTrackTheme.ColorPalette.accent)
                }
                .animation(.snappy(duration: 0.2), value: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    Text(recommendation.task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(1)
                    Text(recommendation.reason.title)
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer()
            }
            .padding(LifeTrackTheme.Spacing.medium)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected
                          ? LifeTrackTheme.ColorPalette.accent.opacity(0.08)
                          : LifeTrackTheme.ColorPalette.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected
                                    ? LifeTrackTheme.ColorPalette.accent.opacity(0.35)
                                    : Color.clear, lineWidth: 1.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

// MARK: - Step 3: Time-Box

private struct TimeBoxStep: View {
    let selectedTasks: [LifeTask]
    @Binding var taskDurations: [UUID: Int]
    let totalMinutes: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                icon: "timer",
                iconColor: Color(red: 0.9, green: 0.55, blue: 0.1),
                title: "Time-Box Your Day",
                subtitle: "How long will each take? Total: \(formattedDuration(totalMinutes))"
            )

            ScrollView {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(selectedTasks) { task in
                        TimeBoxRow(
                            task: task,
                            selectedMinutes: Binding(
                                get: { taskDurations[task.id] ?? task.scheduledDurationMinutes },
                                set: { taskDurations[task.id] = $0 }
                            )
                        )
                    }
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.large)
            }

            continueButton(title: "Lock In My Plan", action: onContinue)
        }
    }
}

private struct TimeBoxRow: View {
    let task: LifeTask
    @Binding var selectedMinutes: Int

    private let options = [15, 30, 45, 60, 90, 120]

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options, id: \.self) { minutes in
                            Button {
                                selectedMinutes = minutes
                            } label: {
                                Text(formattedDuration(minutes))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selectedMinutes == minutes
                                                     ? .white
                                                     : LifeTrackTheme.ColorPalette.secondaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(selectedMinutes == minutes
                                                       ? LifeTrackTheme.ColorPalette.accent
                                                       : LifeTrackTheme.ColorPalette.accent.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            .animation(.snappy(duration: 0.18), value: selectedMinutes)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step 4: Launch Day

private struct LaunchDayStep: View {
    let selectedTasks: [LifeTask]
    let taskDurations: [UUID: Int]
    let totalMinutes: Int
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                icon: "sunrise.fill",
                iconColor: Color(red: 0.95, green: 0.65, blue: 0.1),
                title: "You're Set!",
                subtitle: "Your plan for today — \(formattedDuration(totalMinutes)) committed."
            )

            ScrollView {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(Array(selectedTasks.enumerated()), id: \.element.id) { index, task in
                        let duration = taskDurations[task.id] ?? task.scheduledDurationMinutes
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LifeTrackTheme.ColorPalette.accent.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Text("\(index + 1)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                    .lineLimit(1)
                                Text(formattedDuration(duration))
                                    .font(.caption)
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            }

                            Spacer()
                        }
                        .padding(LifeTrackTheme.Spacing.medium)
                        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.large)
            }

            VStack(spacing: LifeTrackTheme.Spacing.medium) {
                Text("Focus beats perfection. Even one task done is a win.")
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)

                continueButton(
                    title: "Start My Day",
                    action: onStart,
                    icon: "sunrise.fill"
                )
            }
        }
    }
}

// MARK: - Shared Helpers

private func stepHeader(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
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

private func continueButton(title: String, action: @escaping () -> Void, icon: String? = nil, disabled: Bool = false) -> some View {
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
        .background(disabled
                    ? AnyShapeStyle(LifeTrackTheme.ColorPalette.accent.opacity(0.3))
                    : AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
        .padding(.top, LifeTrackTheme.Spacing.medium)
    }
    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97))
    .disabled(disabled)
}

private func formattedDuration(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes)m" }
    let h = minutes / 60
    let m = minutes % 60
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}
