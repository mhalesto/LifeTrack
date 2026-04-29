//
//  BetaFocusedDashboardFocusView.swift
//  LifeTrack
//

import SwiftData
import SwiftUI

struct BetaFocusedDashboardFocusView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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

    @State private var timeRemaining = FocusSessionStore.focusDuration
    @State private var isTimerRunning = false
    @State private var isBreak = false
    @State private var timerTask: Task<Void, Never>?
    @State private var activeFocusTaskID: UUID?
    @State private var activeFocusTaskTitle: String?
    @State private var feedbackMessage: String?

    private var startRecommendation: DailyFocusRecommendation? {
        recommendations.first
    }

    private var queueRecommendations: [DailyFocusRecommendation] {
        Array(recommendations.dropFirst().prefix(4))
    }

    private var nextQueuedTask: LifeTask? {
        recommendations.first { recommendation in
            let task = recommendation.task
            return task.id != activeFocusTaskID && !task.isCompleted && !task.isDeleted
        }?.task
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
                    feedbackBanner
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
        .onAppear {
            restoreSession()
        }
        .onDisappear {
            suspendTicker()
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

    @ViewBuilder
    private var feedbackBanner: some View {
        if let feedbackMessage {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.completedTint)

                Text(feedbackMessage)
                    .font(BetaFocusedDashboardTypography.body.weight(.semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(BetaFocusedDashboardPalette.completedTint.opacity(0.18), lineWidth: 0.8)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
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

                    LazyVGrid(columns: actionColumns, spacing: 8) {
                        BetaFocusedDashboardActionChip(
                            title: "Start Focus",
                            systemImage: "play.fill",
                            tint: BetaFocusedDashboardPalette.completedTint
                        ) {
                            startFocus(for: task)
                        }

                        BetaFocusedDashboardActionChip(
                            title: "Done",
                            systemImage: "checkmark",
                            tint: BetaFocusedDashboardPalette.completedTint,
                            isCompact: true
                        ) {
                            completeTask(task)
                        }

                        BetaFocusedDashboardActionChip(
                            title: "Snooze",
                            systemImage: "clock.badge.plus",
                            tint: BetaFocusedDashboardPalette.warningTint,
                            isCompact: true
                        ) {
                            snoozeTask(task)
                        }

                        BetaFocusedDashboardActionChip(
                            title: "Tomorrow",
                            systemImage: "calendar.badge.plus",
                            tint: BetaFocusedDashboardPalette.captureTint,
                            isCompact: true
                        ) {
                            rescheduleTaskToTomorrow(task)
                        }
                    }
                }
            } else {
                emptyFocusState
            }
        }
    }

    private var actionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(timerLabel)
                            .font(.system(size: 36, weight: .semibold, design: .monospaced))
                            .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                            .monospacedDigit()

                        Text(sessionSubtitle)
                            .font(BetaFocusedDashboardTypography.bodySmall.weight(.medium))
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }

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

                    Text("\(BetaFocusedDashboardFormat.count(recommendations.count)) tasks")
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                }

                if queueRecommendations.isEmpty {
                    Text(startRecommendation == nil ? "Plan My Day to build a queue." : "Only the start task is queued right now.")
                        .font(BetaFocusedDashboardTypography.body)
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    if let nextQueuedTask {
                        BetaFocusedDashboardActionChip(
                            title: activeFocusTaskID == nil ? "Start Queue" : "Start Next",
                            systemImage: "play.circle.fill",
                            tint: BetaFocusedDashboardPalette.completedTint
                        ) {
                            startFocus(for: nextQueuedTask)
                        }
                    }

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
                                onToggleCompletion: { completeTask(task) }
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

                    Text(healthItems.isEmpty ? "Clear" : "\(BetaFocusedDashboardFormat.count(healthItems.count)) need attention")
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
                            HStack(spacing: 9) {
                                Button {
                                    onOpenTask(item.task)
                                } label: {
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
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            Button {
                                applyHealthFix(item)
                            } label: {
                                Text(healthActionTitle(for: item.state))
                                    .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                                    .foregroundStyle(item.state.tint)
                                    .lineLimit(1)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.9), in: Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(item.state.tint.opacity(0.18), lineWidth: 0.8)
                                    }
                            }
                            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.94, pressedOpacity: 0.9))
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

    private var sessionSubtitle: String {
        if let activeFocusTaskTitle, !activeFocusTaskTitle.isEmpty {
            return isTimerRunning ? "Running: \(activeFocusTaskTitle)" : "Pinned: \(activeFocusTaskTitle)"
        }

        if isTimerRunning {
            return "Running across the Focus screen"
        }

        return "Persists when you leave and return"
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

    private func startFocus(for task: LifeTask) {
        activeFocusTaskID = task.id
        activeFocusTaskTitle = task.title
        FocusActivityController.shared.start(for: task, customCategories: customCategories)
        startTimer()
    }

    private func startTimer() {
        guard !isTimerRunning else { return }
        if activeFocusTaskID == nil, let task = startRecommendation?.task {
            activeFocusTaskID = task.id
            activeFocusTaskTitle = task.title
            FocusActivityController.shared.start(for: task, customCategories: customCategories)
        }

        isTimerRunning = true
        FocusSessionStore.start(
            timeRemaining: timeRemaining,
            isBreak: isBreak,
            taskID: activeFocusTaskID,
            taskTitle: activeFocusTaskTitle
        )
        startTicker()
    }

    private func startTicker() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }

                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    isBreak.toggle()
                    timeRemaining = isBreak ? FocusSessionStore.breakDuration : FocusSessionStore.focusDuration
                    FocusSessionStore.start(
                        timeRemaining: timeRemaining,
                        isBreak: isBreak,
                        taskID: activeFocusTaskID,
                        taskTitle: activeFocusTaskTitle
                    )
                    LifeTrackHaptics.lightImpact()
                }
            }
        }
    }

    private func pauseTimer() {
        timerTask?.cancel()
        timerTask = nil
        isTimerRunning = false
        FocusSessionStore.pause(
            timeRemaining: timeRemaining,
            isBreak: isBreak,
            taskID: activeFocusTaskID,
            taskTitle: activeFocusTaskTitle
        )
    }

    private func resetTimer() {
        suspendTicker()
        isTimerRunning = false
        isBreak = false
        timeRemaining = FocusSessionStore.focusDuration
        FocusSessionStore.reset()
    }

    private func skipTimerPhase() {
        suspendTicker()
        isBreak.toggle()
        timeRemaining = isBreak ? FocusSessionStore.breakDuration : FocusSessionStore.focusDuration
        if isTimerRunning {
            FocusSessionStore.start(
                timeRemaining: timeRemaining,
                isBreak: isBreak,
                taskID: activeFocusTaskID,
                taskTitle: activeFocusTaskTitle
            )
            startTicker()
        } else {
            FocusSessionStore.pause(
                timeRemaining: timeRemaining,
                isBreak: isBreak,
                taskID: activeFocusTaskID,
                taskTitle: activeFocusTaskTitle
            )
        }
    }

    private func restoreSession() {
        let snapshot = FocusSessionStore.snapshot()
        timeRemaining = snapshot.timeRemaining
        isTimerRunning = snapshot.isRunning
        isBreak = snapshot.isBreak
        activeFocusTaskID = snapshot.taskID
        activeFocusTaskTitle = snapshot.taskTitle
        if let task = restoredActiveTask, snapshot.isRunning, !FocusActivityController.shared.isPinned(task) {
            FocusActivityController.shared.start(for: task, customCategories: customCategories)
        }
        if snapshot.isRunning {
            startTicker()
        }
    }

    private func suspendTicker() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func completeTask(_ task: LifeTask) {
        onToggleCompletion(task)
        if activeFocusTaskID == task.id {
            resetTimer()
            activeFocusTaskID = nil
            activeFocusTaskTitle = nil
            FocusSessionStore.clearTask()
        }
    }

    private func snoozeTask(_ task: LifeTask) {
        let date = snoozeDate(for: task)
        applyScheduleChange(
            task,
            date: date,
            feedback: "Snoozed to \(BetaFocusedDashboardTimeFormatter.timeOnly.string(from: date))"
        )
    }

    private func rescheduleTaskToTomorrow(_ task: LifeTask) {
        let date = tomorrowAt(hour: 9)
        applyScheduleChange(
            task,
            date: date,
            feedback: "Moved to tomorrow at \(BetaFocusedDashboardTimeFormatter.timeOnly.string(from: date))"
        )
    }

    private func applyHealthFix(_ item: BetaFocusedDashboardFocusHealthItem) {
        switch item.state {
        case .recurringMissed:
            applyScheduleChange(
                item.task,
                date: tomorrowAt(hour: 9),
                feedback: "Recurring task moved to tomorrow"
            )
        case .blocked:
            unblockTask(item.task)
        case .stale:
            refreshStaleTask(item.task)
        case .needsDate:
            applyScheduleChange(
                item.task,
                date: nextFocusDate(),
                feedback: "Date set for the next focus window"
            )
        }
    }

    private func healthActionTitle(for state: BetaFocusedDashboardTaskHealthState) -> String {
        switch state {
        case .recurringMissed: "Move"
        case .blocked: "Unblock"
        case .stale: "Refresh"
        case .needsDate: "Date"
        }
    }

    private func unblockTask(_ task: LifeTask) {
        task.notes = cleanedBlockerText(task.notes)
        task.advancedFields = task.advancedFields.mapValues(cleanedBlockerText)
        if task.dueDate < Date() {
            task.dueDate = nextFocusDate()
        }
        persistTaskUpdate(task, feedback: "Blocked wording cleared")
    }

    private func refreshStaleTask(_ task: LifeTask) {
        if task.dueDate < Calendar.current.startOfDay(for: Date()) {
            task.dueDate = tomorrowAt(hour: 10)
        }
        task.priority = maxPriority(task.priority, .normal)
        persistTaskUpdate(task, feedback: "Stale task refreshed")
    }

    private func applyScheduleChange(_ task: LifeTask, date: Date, feedback: String) {
        task.dueDate = date
        persistTaskUpdate(task, feedback: feedback)
    }

    private func persistTaskUpdate(_ task: LifeTask, feedback: String) {
        task.updatedAt = Date()
        try? modelContext.save()
        TaskLifecycleManager.synchronizeReminder(for: task, customCategories: customCategories)
        FocusActivityController.shared.update(for: task)
        showFeedback(feedback)
    }

    private func snoozeDate(for task: LifeTask) -> Date {
        let calendar = Calendar.current
        let base = max(task.dueDate, Date())
        return calendar.date(byAdding: .hour, value: 2, to: base) ?? base.addingTimeInterval(2 * 60 * 60)
    }

    private func tomorrowAt(hour: Int) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(24 * 60 * 60)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func nextFocusDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        if hour < 17,
           let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) {
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextHour)
            return calendar.date(from: components) ?? nextHour
        }
        return tomorrowAt(hour: 9)
    }

    private func cleanedBlockerText(_ value: String) -> String {
        var cleaned = value
        [
            ("blocked", "paused"),
            ("waiting", "pending"),
            ("on hold", "paused"),
            ("stuck", "paused"),
            ("depends", "needs")
        ].forEach { target, replacement in
            cleaned = cleaned.replacingOccurrences(of: target, with: replacement, options: [.caseInsensitive])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func maxPriority(_ lhs: TaskPriority, _ rhs: TaskPriority) -> TaskPriority {
        lhs.focusScore >= rhs.focusScore ? lhs : rhs
    }

    private func showFeedback(_ message: String) {
        LifeTrackHaptics.lightImpact()
        withAnimation(.snappy(duration: 0.22)) {
            feedbackMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if feedbackMessage == message {
                withAnimation(.snappy(duration: 0.22)) {
                    feedbackMessage = nil
                }
            }
        }
    }

    private var restoredActiveTask: LifeTask? {
        guard let activeFocusTaskID else { return nil }
        return recommendations.first(where: { $0.task.id == activeFocusTaskID })?.task
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
                Text(BetaFocusedDashboardFormat.count(value))
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
