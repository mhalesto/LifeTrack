//
//  BetaDashboardSheets.swift
//  LifeTrack
//
//  Modal sheets presented from the beta dashboard: daily focus sort,
//  stat summary, focus timer, and quick-actions customize.
//

import SwiftData
import SwiftUI

// MARK: - Daily Focus Sort Sheet

struct DailyFocusSortSheet: View {
    @Binding var selectedOrder: DashboardSortOrder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(BetaPalette.accent)
                        .frame(width: 42, height: 42)
                        .background(BetaPalette.accent.opacity(0.13), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sort Daily Focus")
                            .font(.lifeTrack(.title3, weight: .bold, defaultDesign: .serif))
                            .foregroundStyle(BetaPalette.primaryText)
                        Text("Choose what this list should show first.")
                            .font(.lifeTrack(.footnote, weight: .medium))
                            .foregroundStyle(BetaPalette.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(DashboardSortOrder.allCases, id: \.self) { order in
                        sortOption(order)
                    }
                }
            }
            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
            .padding(.top, LifeTrackTheme.Spacing.large)
            .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
        }
    }

    private func sortOption(_ order: DashboardSortOrder) -> some View {
        let isSelected = selectedOrder == order
        return Button {
            selectedOrder = order
            dismiss()
        } label: {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                ZStack {
                    Circle()
                        .fill(isSelected ? BetaPalette.accent : BetaPalette.accent.opacity(0.08))
                    Image(systemName: isSelected ? "checkmark" : iconName(for: order))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isSelected ? .white : BetaPalette.accent)
                }
                .frame(width: 34, height: 34)
                .animation(.snappy(duration: 0.2), value: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(order.rawValue)
                        .font(.lifeTrack(.headline, weight: .semibold))
                        .foregroundStyle(BetaPalette.primaryText)
                    Text(subtitle(for: order))
                        .font(.lifeTrack(.caption, weight: .medium))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(LifeTrackTheme.Spacing.medium)
            .background(
                isSelected ? BetaPalette.accent.opacity(0.09) : Color.white.opacity(0.82),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? BetaPalette.accent.opacity(0.35) : BetaPalette.faintBorder, lineWidth: 1)
            }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98, pressedOpacity: 0.94))
    }

    private func iconName(for order: DashboardSortOrder) -> String {
        switch order {
        case .today: "sun.max.fill"
        case .dueDate: "calendar"
        case .priority: "flag.fill"
        case .title: "textformat"
        }
    }

    private func subtitle(for order: DashboardSortOrder) -> String {
        switch order {
        case .today: "Only tasks for today"
        case .dueDate: "Earliest dates first"
        case .priority: "High priority first"
        case .title: "Alphabetical order"
        }
    }
}

// MARK: - Stat Summary Sheet

struct BetaStatSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && !$0.isCompleted }, sort: \LifeTask.dueDate)
    private var openTasks: [LifeTask]
    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && $0.isCompleted }, sort: \LifeTask.dueDate, order: .reverse)
    private var completedTasks: [LifeTask]
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]
    @State private var editingTask: LifeTask?
    @AppStorage(LifeTrackSettings.Keys.themeID) private var themeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.colorStrength) private var colorStrength: Double = 1.0

    let kind: BetaSummaryKind

    private var filteredTasks: [LifeTask] {
        let cal = Calendar.current
        let now = Date()
        switch kind {
        case .dueToday:
            return openTasks.filter { cal.isDateInToday($0.dueDate) }
        case .upcoming:
            return openTasks.filter { $0.dueDate > now && !cal.isDateInToday($0.dueDate) }
        case .completed:
            return completedTasks
        case .overdue:
            return openTasks.filter(\.isOverdue)
        }
    }

    private var uniqueCategoryCount: Int {
        Set(filteredTasks.map(\.categoryRawValue)).count
    }

    private var fileCount: Int {
        filteredTasks.filter(\.hasDocument).count
    }

    private var latestLabel: String {
        if kind == .completed {
            return filteredTasks.compactMap(\.completedAt).max()?.dayMonthString ?? "—"
        }
        return filteredTasks.map(\.dueDate).min()?.dayMonthString ?? "—"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryHeader

                        statsRow

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Tasks")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            Text(kind.subtitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        }

                        if filteredTasks.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: LifeTrackTheme.Spacing.small) {
                                ForEach(filteredTasks) { task in
                                    BetaSummaryTaskCard(
                                        task: task,
                                        categoryOption: task.categoryOption(customCategories: customCategories),
                                        onToggleCompletion: { toggleCompletion(task) },
                                        onEdit: { editingTask = task },
                                        onDelete: { deleteTask(task) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
        }
        .sheet(item: $editingTask) { task in
            NewTaskView(task: task)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(kind.iconBg)
                    .frame(width: 56, height: 56)
                Image(systemName: kind.symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(kind.iconTint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(kind.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text("\(filteredTasks.count)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(kind.iconTint)
                }
                Text(kind.sheetSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.6), lineWidth: 0.7)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(uniqueCategoryCount)", label: "Categories")
            Divider().frame(height: 36)
            statCell(value: "\(fileCount)", label: "Files")
            Divider().frame(height: 36)
            statCell(value: latestLabel, label: kind == .completed ? "Latest" : "Nearest")
        }
        .padding(.vertical, 12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.6), lineWidth: 0.7)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            Text(kind.emptyTitle)
                .font(.headline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            Text(kind.emptyMessage)
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggleCompletion(_ task: LifeTask) {
        let pending = TaskLifecycleManager.beginToggleCompletion(for: task)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            TaskLifecycleManager.finishToggleCompletion(pending, in: modelContext, customCategories: customCategories)
        }
    }

    private func deleteTask(_ task: LifeTask) {
        _ = TaskLifecycleManager.delete(task, in: modelContext)
    }
}

// MARK: - Focus Timer Sheet

struct FocusTimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var timeRemaining: Int = 25 * 60
    @State private var isRunning = false
    @State private var isBreak = false
    @State private var timerTask: Task<Void, Never>?

    private let workDuration = 25 * 60
    private let breakDuration = 5 * 60

    var body: some View {
        NavigationView {
            VStack(spacing: 36) {
                Spacer()

                Text(isBreak ? "Break" : "Focus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isBreak ? BetaPalette.statCompleted : BetaPalette.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(isBreak ? BetaPalette.statCompletedBg : BetaPalette.accentSoft)
                    )

                ZStack {
                    Circle()
                        .stroke(BetaPalette.faintBorder, lineWidth: 14)
                        .frame(width: 240, height: 240)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isBreak ? BetaPalette.statCompleted : BetaPalette.accent,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 240, height: 240)
                        .animation(.linear(duration: 0.8), value: progress)

                    Text(timeString)
                        .font(.system(size: 54, weight: .bold, design: .monospaced))
                        .foregroundStyle(BetaPalette.primaryText)
                }

                HStack(spacing: 24) {
                    circleButton(icon: "arrow.counterclockwise", size: 56) {
                        resetTimer()
                    }

                    circleButton(icon: isRunning ? "pause.fill" : "play.fill", size: 72, isPrimary: true) {
                        isRunning ? pauseTimer() : startTimer()
                    }

                    circleButton(icon: "forward.end.fill", size: 56) {
                        skipPhase()
                    }
                }

                HStack(spacing: 24) {
                    sessionLabel(value: "25 min", caption: "Focus")
                    Rectangle()
                        .fill(BetaPalette.faintBorder)
                        .frame(width: 1, height: 32)
                    sessionLabel(value: "5 min", caption: "Break")
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(BetaPalette.appBackground.ignoresSafeArea())
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BetaPalette.accent)
                }
            }
        }
        .onDisappear { pauseTimer() }
    }

    private var timeString: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    private var progress: Double {
        let total = isBreak ? Double(breakDuration) : Double(workDuration)
        return 1.0 - Double(timeRemaining) / total
    }

    private func startTimer() {
        isRunning = true
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    isBreak.toggle()
                    timeRemaining = isBreak ? breakDuration : workDuration
                    LifeTrackHaptics.lightImpact()
                }
            }
        }
    }

    private func pauseTimer() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
    }

    private func resetTimer() {
        pauseTimer()
        isBreak = false
        timeRemaining = workDuration
        LifeTrackHaptics.lightImpact()
    }

    private func skipPhase() {
        pauseTimer()
        isBreak.toggle()
        timeRemaining = isBreak ? breakDuration : workDuration
        LifeTrackHaptics.lightImpact()
    }

    private func circleButton(icon: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            LifeTrackHaptics.lightImpact()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 26 : 20, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : BetaPalette.secondaryText)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isPrimary ? AnyShapeStyle(BetaPalette.primaryGradient) : AnyShapeStyle(Color.white))
                        .shadow(
                            color: isPrimary ? BetaPalette.accent.opacity(0.4) : Color.black.opacity(0.06),
                            radius: isPrimary ? 12 : 8,
                            y: isPrimary ? 6 : 3
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func sessionLabel(value: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(BetaPalette.primaryText)
            Text(caption)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BetaPalette.secondaryText)
        }
    }
}

// MARK: - Quick Actions Customize Sheet

struct QuickActionsCustomizeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showPlanMyDay: Bool
    @Binding var showHabits: Bool
    @Binding var showReview: Bool
    @Binding var showFocusTimer: Bool
    @Binding var showNewTask: Bool
    @Binding var showTemplates: Bool
    @Binding var showAvailability: Bool
    @Binding var showCalendar: Bool
    @Binding var showStatistics: Bool
    @Binding var showDocuments: Bool
    @Binding var showImport: Bool
    @Binding var showExport: Bool
    @Binding var showEmail: Bool
    @Binding var showBill: Bool
    @Binding var showMedication: Bool
    @Binding var showBudget: Bool
    @Binding var showCheckup: Bool
    @Binding var showAISuggestions: Bool
    @Binding var showSmartSchedule: Bool

    var body: some View {
        NavigationView {
            List {
                Section("Rituals & focus") {
                    actionRow(title: "Plan My Day", subtitle: "Daily ritual",
                              icon: "sun.max.fill", iconBg: BetaPalette.qaPlanBg, iconTint: BetaPalette.qaPlanTint,
                              isOn: $showPlanMyDay)
                    actionRow(title: "Habits", subtitle: "Streaks",
                              icon: "flame.fill", iconBg: BetaPalette.qaHabitsBg, iconTint: BetaPalette.qaHabitsTint,
                              isOn: $showHabits)
                    actionRow(title: "Review", subtitle: "Progress",
                              icon: "chart.bar.fill", iconBg: BetaPalette.qaReviewBg, iconTint: BetaPalette.qaReviewTint,
                              isOn: $showReview)
                    actionRow(title: "Focus Timer", subtitle: "Deep work",
                              icon: "timer", iconBg: BetaPalette.qaFocusBg, iconTint: BetaPalette.qaFocusTint,
                              isOn: $showFocusTimer)
                    actionRow(title: "AI Suggestions", subtitle: "Smart focus",
                              icon: "sparkles", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                              isOn: $showAISuggestions)
                    actionRow(title: "Schedule", subtitle: "Optimize day",
                              icon: "brain.head.profile", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                              isOn: $showSmartSchedule)
                }

                Section("Capture") {
                    actionRow(title: "New Task", subtitle: "Start fresh",
                              icon: "plus", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint,
                              isOn: $showNewTask)
                    actionRow(title: "Templates", subtitle: "Smart shortcuts",
                              icon: "sparkles", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint,
                              isOn: $showTemplates)
                    actionRow(title: "Availability", subtitle: "Share times",
                              icon: "calendar.badge.clock", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint,
                              isOn: $showAvailability)
                    actionRow(title: "Email follow-up", subtitle: "Use template",
                              icon: "envelope.badge", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint,
                              isOn: $showEmail)
                    actionRow(title: "Pay bill", subtitle: "Monthly",
                              icon: "creditcard", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint,
                              isOn: $showBill)
                    actionRow(title: "Medication", subtitle: "Daily routine",
                              icon: "cross.case", iconBg: BetaPalette.qaDangerBg, iconTint: BetaPalette.qaDangerTint,
                              isOn: $showMedication)
                    actionRow(title: "Money", subtitle: "Budget & actuals",
                              icon: "chart.pie", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint,
                              isOn: $showBudget)
                    actionRow(title: "Health check", subtitle: "Book visit",
                              icon: "heart.text.square", iconBg: BetaPalette.qaDangerBg, iconTint: BetaPalette.qaDangerTint,
                              isOn: $showCheckup)
                }

                Section("Navigate") {
                    actionRow(title: "Calendar", subtitle: "See dates",
                              icon: "calendar", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint,
                              isOn: $showCalendar)
                    actionRow(title: "Statistics", subtitle: "See trends",
                              icon: "chart.bar.xaxis", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint,
                              isOn: $showStatistics)
                    actionRow(title: "Documents", subtitle: "Search files",
                              icon: "doc.text.magnifyingglass", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                              isOn: $showDocuments)
                    actionRow(title: "Import", subtitle: "From file",
                              icon: "tray.and.arrow.down", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint,
                              isOn: $showImport)
                    actionRow(title: "Export", subtitle: "Share/AirDrop",
                              icon: "square.and.arrow.up", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint,
                              isOn: $showExport)
                }
            }
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BetaPalette.accent)
                }
            }
        }
    }

    private func actionRow(title: String, subtitle: String, icon: String, iconBg: Color, iconTint: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconBg).frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(iconTint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(BetaPalette.accent)
        }
        .padding(.vertical, 4)
    }
}
