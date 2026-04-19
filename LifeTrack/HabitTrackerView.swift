//
//  HabitTrackerView.swift
//  LifeTrack
//

import SwiftUI

struct HabitTrackerView: View {
    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
    let onToggleCompletion: (LifeTask) -> Void

    @State private var summaries: [HabitSummary] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge, pinnedViews: []) {
                        header.padding(.top, LifeTrackTheme.Spacing.large)

                        if isLoading {
                            loadingState
                        } else if summaries.isEmpty {
                            emptyState
                        } else {
                            ForEach(summaries, id: \.task.id) { summary in
                                HabitCard(
                                    summary: summary,
                                    onToggle: { onToggleCompletion(summary.task) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await recomputeSummaries()
        }
        .onChange(of: tasks) { _, newTasks in
            Task { await recomputeSummaries() }
        }
    }

    @MainActor
    private func recomputeSummaries() async {
        // Yield so the spinner renders before synchronous computation runs
        await Task.yield()
        summaries = HabitEngine.summaries(from: tasks)
        isLoading = false
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Habits")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            Text("Recurring tasks promoted to streaks.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading habits…")
                .font(.caption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyState: some View {
        SectionCardView {
            VStack(spacing: 10) {
                Image(systemName: "flame")
                    .font(.system(size: 32))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                Text("No habits yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text("Set any task to repeat daily, weekly, or monthly — it becomes a habit with streak tracking.")
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, LifeTrackTheme.Spacing.medium)
        }
    }
}

// MARK: - Habit Card

private struct HabitCard: View {
    let summary: HabitSummary
    let onToggle: () -> Void

    @State private var isToggling = false

    private var streakColor: Color {
        switch summary.currentStreak {
        case 0: return LifeTrackTheme.ColorPalette.secondaryText
        case 1...3: return Color(red: 0.9, green: 0.55, blue: 0.1)
        case 4...9: return Color(red: 0.95, green: 0.3, blue: 0.15)
        default: return Color(red: 0.85, green: 0.15, blue: 0.5)
        }
    }

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                // Title + streak badge
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(summary.task.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .lineLimit(1)
                        Text(summary.recurrence.title)
                            .font(.caption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }

                    Spacer()

                    VStack(spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(streakColor)
                            Text("\(summary.currentStreak)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(streakColor)
                        }
                        Text("streak")
                            .font(.caption2)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                }

                // Heatmap
                HabitHeatmap(
                    filledDateStrings: summary.filledDateStrings,
                    cellCount: summary.cellCount
                )

                // Stats + action
                HStack(spacing: LifeTrackTheme.Spacing.large) {
                    HabitStat(label: "Best", value: "\(summary.longestStreak)")
                    HabitStat(label: "Total", value: "\(summary.completionDates.count)")
                    Spacer()

                    if !summary.task.isCompleted {
                        Button {
                            guard !isToggling else { return }
                            isToggling = true
                            Task { @MainActor in
                                // Yield so the spinner renders before work starts
                                await Task.yield()
                                onToggle()
                            }
                        } label: {
                            Group {
                                if isToggling {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                        .frame(width: 80, height: 20)
                                } else {
                                    Label("Done Today", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(LifeTrackTheme.ColorPalette.accentGradient, in: Capsule())
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96))
                        .disabled(isToggling)
                    } else {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                    }
                }
            }
        }
    }
}

private struct HabitStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
    }
}

// MARK: - Heatmap (pre-computed, no Calendar work at render time)

private struct HabitHeatmap: View {
    let filledDateStrings: Set<String>
    let cellCount: Int

    private let columns = 13
    private var rows: Int { (cellCount + columns - 1) / columns }

    var body: some View {
        // Fixed grid — no LazyVGrid to avoid layout measurement overhead
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < cellCount {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(filledDateStrings.contains(cellKey(index))
                                      ? LifeTrackTheme.ColorPalette.accent.opacity(0.85)
                                      : LifeTrackTheme.ColorPalette.accent.opacity(0.1))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    private func cellKey(_ index: Int) -> String {
        // index 0 = today, index n = n periods ago — key matches HabitSummary.filledDateStrings
        "\(index)"
    }
}
