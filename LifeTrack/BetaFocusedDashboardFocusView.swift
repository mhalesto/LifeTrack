//
//  BetaFocusedDashboardFocusView.swift
//  LifeTrack
//

import SwiftUI

struct BetaFocusedDashboardFocusView: View {
    @Environment(\.dismiss) private var dismiss

    let recommendations: [DailyFocusRecommendation]
    let scheduledBlock: ScheduledBlock?
    let focusProgressLabel: String
    let focusProgress: Double
    let dueTodayCount: Int
    let busyBlockCount: Int
    let customCategories: [CustomTaskCategory]
    let onOpenTask: (LifeTask) -> Void
    let onToggleCompletion: (LifeTask) -> Void
    let onOpenPlanMyDay: () -> Void
    let onOpenOverdueRescue: () -> Void

    @State private var timeRemaining = 25 * 60
    @State private var isTimerRunning = false
    @State private var isBreak = false
    @State private var timerTask: Task<Void, Never>?

    private let focusDuration = 25 * 60
    private let breakDuration = 5 * 60

    private var startRecommendation: DailyFocusRecommendation? {
        recommendations.first
    }

    private var queueRecommendations: [DailyFocusRecommendation] {
        Array(recommendations.dropFirst().prefix(4))
    }

    private var healthItems: [BetaFocusedDashboardFocusHealthItem] {
        var seen = Set<UUID>()
        return recommendations.compactMap { recommendation in
            let task = recommendation.task
            guard seen.insert(task.id).inserted,
                  let state = task.betaFocusedHealthState()
            else { return nil }

            return BetaFocusedDashboardFocusHealthItem(task: task, state: state)
        }
    }

    var body: some View {
        ZStack {
            BetaFocusedDashboardBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    progressCard
                    startHereCard
                    timerCard
                    queueCard
                    healthCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 92)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onDisappear {
            pauseTimer()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BetaFocusedDashboardPalette.statsPillText)
                    .frame(width: 34, height: 34)
                    .background(BetaFocusedDashboardPalette.statsPillBackground, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text("Focus")
                    .font(BetaFocusedDashboardTypography.greeting)
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                Text("Start with the next best action")
                    .font(BetaFocusedDashboardTypography.date)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var progressCard: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today")
                        .font(BetaFocusedDashboardTypography.section)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                    Spacer(minLength: 0)

                    Text(focusProgressLabel)
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(BetaFocusedDashboardPalette.border.opacity(0.56))

                        Capsule()
                            .fill(BetaFocusedDashboardPalette.progressTint)
                            .frame(width: proxy.size.width * CGFloat(focusProgress))
                    }
                }
                .frame(height: 5)

                HStack(spacing: 8) {
                    BetaFocusedDashboardFocusMetric(
                        value: recommendations.count,
                        title: "Queue",
                        systemImage: "list.bullet",
                        tint: BetaFocusedDashboardPalette.completedTint
                    )

                    BetaFocusedDashboardFocusMetric(
                        value: dueTodayCount,
                        title: "Due Today",
                        systemImage: "calendar",
                        tint: BetaFocusedDashboardPalette.dueTodayTint
                    )

                    BetaFocusedDashboardFocusMetric(
                        value: busyBlockCount,
                        title: "Busy",
                        systemImage: "calendar.badge.clock",
                        tint: BetaFocusedDashboardPalette.importExportTint
                    )
                }
            }
        }
    }

    private var startHereCard: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            if let recommendation = startRecommendation {
                let task = recommendation.task
                let category = task.categoryOption(customCategories: customCategories)
                let visuals = categoryVisuals(for: category)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Start here", systemImage: "sparkles")
                            .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                            .foregroundStyle(BetaFocusedDashboardPalette.heroAccent)

                        Spacer(minLength: 0)

                        Text(scheduleHint(for: recommendation))
                            .font(BetaFocusedDashboardTypography.bodySmall.weight(.medium))
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                            .lineLimit(1)
                    }

                    Button {
                        onOpenTask(task)
                    } label: {
                        HStack(spacing: 11) {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(visuals.background)
                                .frame(width: 46, height: 46)
                                .overlay {
                                    Image(systemName: category.symbolName)
                                        .font(.system(size: 19, weight: .medium))
                                        .foregroundStyle(visuals.tint)
                                }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(task.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                HStack(spacing: 6) {
                                    BetaFocusedDashboardCategoryChip(
                                        title: recommendation.reason.title,
                                        tint: BetaFocusedDashboardPalette.heroAccent,
                                        background: BetaFocusedDashboardPalette.dangerBackground
                                    )

                                    BetaFocusedDashboardCategoryChip(
                                        title: category.title,
                                        tint: visuals.tint,
                                        background: visuals.background
                                    )

                                    if let state = task.betaFocusedHealthState() {
                                        BetaFocusedDashboardHealthChip(state: state)
                                    }
                                }
                            }

                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        BetaFocusedDashboardActionChip(
                            title: "Start Focus",
                            systemImage: "play.fill",
                            tint: BetaFocusedDashboardPalette.completedTint
                        ) {
                            FocusActivityController.shared.start(for: task, customCategories: customCategories)
                        }

                        BetaFocusedDashboardActionChip(
                            title: "Done",
                            systemImage: "checkmark",
                            tint: BetaFocusedDashboardPalette.completedTint,
                            isCompact: true
                        ) {
                            onToggleCompletion(task)
                        }
                    }
                }
            } else {
                emptyFocusState
            }
        }
    }

    private var emptyFocusState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No focus queue")
                .font(BetaFocusedDashboardTypography.section)
                .foregroundStyle(BetaFocusedDashboardPalette.headerText)

            Text("Plan your day to choose the tasks that deserve attention first.")
                .font(BetaFocusedDashboardTypography.body)
                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)

            BetaFocusedDashboardActionChip(
                title: "Plan My Day",
                systemImage: "wand.and.stars",
                tint: BetaFocusedDashboardPalette.heroAccent,
                action: onOpenPlanMyDay
            )
        }
    }

    private var timerCard: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Session")
                        .font(BetaFocusedDashboardTypography.section)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                    Spacer(minLength: 0)

                    Text(isBreak ? "Break" : "Focus block")
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                        .foregroundStyle(isBreak ? BetaFocusedDashboardPalette.completedTint : BetaFocusedDashboardPalette.heroAccent)
                }

                HStack(alignment: .center, spacing: 14) {
                    Text(timerLabel)
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                        .monospacedDigit()

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        focusCircleButton(systemImage: "arrow.counterclockwise") {
                            resetTimer()
                        }

                        focusCircleButton(systemImage: isTimerRunning ? "pause.fill" : "play.fill", isPrimary: true) {
                            isTimerRunning ? pauseTimer() : startTimer()
                        }

                        focusCircleButton(systemImage: "forward.end.fill") {
                            skipTimerPhase()
                        }
                    }
                }
            }
        }
    }

    private var queueCard: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Focus Queue")
                        .font(BetaFocusedDashboardTypography.section)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                    Spacer(minLength: 0)

                    Text("\(recommendations.count.formatted()) tasks")
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                }

                if queueRecommendations.isEmpty {
                    Text(startRecommendation == nil ? "Plan My Day to build a queue." : "Only the start task is queued right now.")
                        .font(BetaFocusedDashboardTypography.body)
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(queueRecommendations) { recommendation in
                            let task = recommendation.task
                            let category = task.categoryOption(customCategories: customCategories)
                            let visuals = categoryVisuals(for: category)

                            BetaFocusedDashboardTaskRow(
                                task: task,
                                categoryOption: category,
                                visuals: visuals,
                                healthState: task.betaFocusedHealthState(),
                                onOpen: { onOpenTask(task) },
                                onToggleCompletion: { onToggleCompletion(task) }
                            )

                            if recommendation.id != queueRecommendations.last?.id {
                                Divider()
                                    .overlay(BetaFocusedDashboardPalette.border.opacity(0.8))
                            }
                        }
                    }
                }

                BetaFocusedDashboardActionChip(
                    title: "Plan My Day",
                    systemImage: "wand.and.stars",
                    tint: BetaFocusedDashboardPalette.heroAccent,
                    action: onOpenPlanMyDay
                )
            }
        }
    }

    private var healthCard: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Task Health")
                        .font(BetaFocusedDashboardTypography.section)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                    Spacer(minLength: 0)

                    Text(healthItems.isEmpty ? "Clear" : "\(healthItems.count.formatted()) need attention")
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                        .foregroundStyle(healthItems.isEmpty ? BetaFocusedDashboardPalette.completedTint : BetaFocusedDashboardPalette.warningTint)
                }

                if healthItems.isEmpty {
                    Text("No stale, blocked, recurring missed, or needs-date tasks in the current focus queue.")
                        .font(BetaFocusedDashboardTypography.body)
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(healthItems.prefix(3)) { item in
                            Button {
                                onOpenTask(item.task)
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: item.state.symbolName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(item.state.tint)
                                        .frame(width: 28, height: 28)
                                        .background(item.state.background, in: Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.task.title)
                                            .font(BetaFocusedDashboardTypography.body.weight(.semibold))
                                            .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                                            .lineLimit(1)

                                        Text(item.state.title)
                                            .font(BetaFocusedDashboardTypography.bodySmall)
                                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                                    }

                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if recommendations.contains(where: { $0.task.isOverdue }) {
                        BetaFocusedDashboardActionChip(
                            title: "Rescue Overdue",
                            systemImage: "lifepreserver",
                            tint: BetaFocusedDashboardPalette.overdueTint,
                            action: onOpenOverdueRescue
                        )
                    }
                }
            }
        }
    }

    private var timerLabel: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    private func scheduleHint(for recommendation: DailyFocusRecommendation) -> String {
        if let scheduledBlock {
            return "Fits \(BetaFocusedDashboardTimeFormatter.timeOnly.string(from: scheduledBlock.startDate))"
        }

        if recommendation.task.isOverdue {
            return "Rescue candidate"
        }

        return "Next best action"
    }

    private func focusCircleButton(systemImage: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            LifeTrackHaptics.lightImpact()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: isPrimary ? 17 : 14, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : BetaFocusedDashboardPalette.secondaryText)
                .frame(width: isPrimary ? 42 : 36, height: isPrimary ? 42 : 36)
                .background(isPrimary ? BetaFocusedDashboardPalette.heroAccent : Color.white, in: Circle())
                .overlay {
                    Circle()
                        .stroke(isPrimary ? Color.clear : BetaFocusedDashboardPalette.border, lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
    }

    private func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }

                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    isBreak.toggle()
                    timeRemaining = isBreak ? breakDuration : focusDuration
                    LifeTrackHaptics.lightImpact()
                }
            }
        }
    }

    private func pauseTimer() {
        timerTask?.cancel()
        timerTask = nil
        isTimerRunning = false
    }

    private func resetTimer() {
        pauseTimer()
        isBreak = false
        timeRemaining = focusDuration
    }

    private func skipTimerPhase() {
        pauseTimer()
        isBreak.toggle()
        timeRemaining = isBreak ? breakDuration : focusDuration
    }

    private func categoryVisuals(for option: TaskCategoryOption) -> BetaFocusedDashboardCategoryVisuals {
        switch option.id {
        case TaskCategory.finance.rawValue:
            BetaFocusedDashboardCategoryVisuals(tint: BetaFocusedDashboardPalette.financeTint, background: BetaFocusedDashboardPalette.financeBackground)
        case TaskCategory.health.rawValue:
            BetaFocusedDashboardCategoryVisuals(tint: BetaFocusedDashboardPalette.healthTint, background: BetaFocusedDashboardPalette.healthBackground)
        case TaskCategory.work.rawValue:
            BetaFocusedDashboardCategoryVisuals(tint: BetaFocusedDashboardPalette.workTint, background: BetaFocusedDashboardPalette.workBackground)
        case TaskCategory.home.rawValue:
            BetaFocusedDashboardCategoryVisuals(tint: BetaFocusedDashboardPalette.homeTint, background: BetaFocusedDashboardPalette.homeBackground)
        case TaskCategory.personal.rawValue:
            BetaFocusedDashboardCategoryVisuals(tint: BetaFocusedDashboardPalette.personalTint, background: BetaFocusedDashboardPalette.personalBackground)
        default:
            BetaFocusedDashboardCategoryVisuals(tint: BetaFocusedDashboardPalette.otherTint, background: BetaFocusedDashboardPalette.otherBackground)
        }
    }
}

private struct BetaFocusedDashboardFocusMetric: View {
    let value: Int
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value.formatted())
                    .font(BetaFocusedDashboardTypography.body.weight(.semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                    .monospacedDigit()

                Text(title)
                    .font(BetaFocusedDashboardTypography.bodySmall)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
        }
    }
}

private struct BetaFocusedDashboardFocusHealthItem: Identifiable {
    let task: LifeTask
    let state: BetaFocusedDashboardTaskHealthState

    var id: UUID { task.id }
}
