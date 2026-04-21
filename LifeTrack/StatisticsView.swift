//
//  StatisticsView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    let tasks: [LifeTask]

    @State private var selectedRange: StatisticsTimeRange = .days
    @State private var hasAppeared = false
    @State private var chartProgress = 1.0
    @State private var statsSnapshot = ProductivityStatsSnapshot.empty
    @State private var isPreparingStats = true
    @State private var statsRefreshID = UUID()
    @State private var selectedSummaryAction: StatisticsSummaryAction?
    @State private var editingTask: LifeTask?
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    private var points: [ProductivityStatPoint] {
        statsSnapshot.points
    }

    private var activeTasks: [LifeTask] {
        tasks.filter { !$0.isDeleted }
    }

    private var totalCompleted: Int {
        statsSnapshot.totalCompleted
    }

    private var totalOverdue: Int {
        statsSnapshot.totalOverdue
    }

    private var bestPoint: ProductivityStatPoint? {
        statsSnapshot.bestPoint
    }

    private var completionRate: Int {
        statsSnapshot.completionRate
    }

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                    header
                        .statisticsEntrance(index: 0, isVisible: hasAppeared, animationsEnabled: animationsEnabled)
                    rangeSelector
                        .statisticsEntrance(index: 1, isVisible: hasAppeared, animationsEnabled: animationsEnabled)

                    if isPreparingStats {
                        statisticsLoadingState
                            .statisticsEntrance(index: 2, isVisible: hasAppeared, animationsEnabled: animationsEnabled)
                    } else {
                        summarySection
                            .statisticsEntrance(index: 2, isVisible: hasAppeared, animationsEnabled: animationsEnabled)
                        insightsSection
                            .statisticsEntrance(index: 3, isVisible: hasAppeared, animationsEnabled: animationsEnabled)
                        completedChart
                            .statisticsEntrance(index: 4, isVisible: hasAppeared, animationsEnabled: animationsEnabled)
                        overdueChart
                            .statisticsEntrance(index: 5, isVisible: hasAppeared, animationsEnabled: animationsEnabled)
                    }
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.large)
                .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            runEntranceAnimation()
            refreshStats()
        }
        .onChange(of: selectedRange) { _, _ in
            refreshStats()
        }
        .onChange(of: animationsEnabled) { _, _ in
            runEntranceAnimation()
            if !isPreparingStats {
                runChartAnimation()
            }
        }
        .sheet(item: $selectedSummaryAction) { action in
            StatisticsSummaryActionSheet(
                action: action,
                range: selectedRange,
                tasks: tasks(for: action),
                totalCompleted: totalCompleted,
                totalOverdue: totalOverdue,
                completionRate: completionRate,
                bestPoint: bestPoint,
                customCategories: customCategories,
                onToggleCompletion: toggleCompletion,
                onEdit: openTaskFromSummaryAction,
                onDelete: delete,
                onShowAction: { selectedSummaryAction = $0 }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingTask) { task in
            NewTaskView(task: task)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Track your completion rhythm and overdue trends over time.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rangeSelector: some View {
        StatisticsRangeSelector(selectedRange: $selectedRange)
    }

    private var statisticsLoadingState: some View {
        SectionCardView {
            HStack(alignment: .center, spacing: LifeTrackTheme.Spacing.medium) {
                ProgressView()
                    .tint(LifeTrackTheme.ColorPalette.accent)
                    .scaleEffect(1.05)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Preparing Statistics")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Building the chart snapshot locally.")
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .center)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(title: "Summary", subtitle: selectedRange.summarySubtitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LifeTrackTheme.Spacing.medium) {
                Button {
                    selectedSummaryAction = .completed
                } label: {
                    StatisticsSummaryCard(
                        title: "Completed",
                        value: totalCompleted,
                        subtitle: "Finished in range",
                        symbolName: "checkmark.seal.fill",
                        tint: LifeTrackTheme.ColorPalette.success,
                        animationID: selectedRange.id,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))

                Button {
                    selectedSummaryAction = .overdue
                } label: {
                    StatisticsSummaryCard(
                        title: "Overdue",
                        value: totalOverdue,
                        subtitle: "Past due in range",
                        symbolName: "exclamationmark.triangle.fill",
                        tint: LifeTrackTheme.ColorPalette.danger,
                        animationID: selectedRange.id,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))

                Button {
                    selectedSummaryAction = .completion
                } label: {
                    StatisticsSummaryCard(
                        title: "Completion",
                        value: completionRate,
                        suffix: "%",
                        subtitle: "Completed vs overdue",
                        symbolName: "chart.pie.fill",
                        tint: LifeTrackTheme.ColorPalette.accent,
                        animationID: selectedRange.id,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))

                Button {
                    selectedSummaryAction = .best
                } label: {
                    StatisticsSummaryCard(
                        title: "Best \(selectedRange.unitTitle)",
                        value: bestPoint?.completedCount ?? 0,
                        subtitle: bestPoint?.label ?? "No activity yet",
                        symbolName: "sparkles",
                        tint: LifeTrackTheme.ColorPalette.warning,
                        animationID: selectedRange.id,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(
                title: "Insights",
                subtitle: "Spot the patterns behind your completions."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LifeTrackTheme.Spacing.medium) {
                StreakInsightCard(
                    currentStreak: statsSnapshot.currentStreak,
                    bestStreak: statsSnapshot.bestStreak,
                    animationID: selectedRange.id
                )

                FocusInsightCard(
                    totalMinutes: statsSnapshot.focusMinutesCompleted,
                    topEntry: statsSnapshot.focusByCategory.first,
                    customCategories: customCategories,
                    animationID: selectedRange.id
                )
            }

            CategoryMixCard(
                entries: statsSnapshot.categoryShare,
                customCategories: customCategories,
                chartProgress: chartProgress,
                animationsEnabled: animationsEnabled
            )

            BestWeekdayCard(
                weekdayBreakdown: statsSnapshot.weekdayBreakdown,
                bestWeekday: statsSnapshot.bestWeekday,
                chartProgress: chartProgress,
                animationsEnabled: animationsEnabled
            )
        }
    }

    private var completedChart: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Completed Tasks",
                subtitle: "Tasks finished per \(selectedRange.unitTitle.lowercased()).",
                trailing: totalCompleted.formatted()
            )

            Chart(points) { point in
                BarMark(
                    x: .value(selectedRange.unitTitle, point.date),
                    y: .value("Completed", animatedValue(point.completedCount))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            LifeTrackTheme.ColorPalette.accent,
                            LifeTrackTheme.ColorPalette.accent.opacity(0.58)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: selectedRange.axisDates(for: points)) { value in
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.55))
                    AxisTick()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(selectedRange.axisLabel(for: date))
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.7))
                    AxisValueLabel()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .chartYScale(domain: 0...max(1, points.map(\.completedCount).max() ?? 1))
            .frame(height: 230)
            .animation(animationsEnabled ? .smooth(duration: 0.85) : nil, value: chartProgress)

            chartFootnote(
                symbolName: "checkmark.circle",
                text: totalCompleted == 0 ? "Completed tasks will appear here once you finish them." : completionInsight
            )
        }
    }

    private var overdueChart: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Overdue Trend",
                subtitle: "Past-due tasks by \(selectedRange.unitTitle.lowercased()).",
                trailing: totalOverdue.formatted()
            )

            Chart(points) { point in
                AreaMark(
                    x: .value(selectedRange.unitTitle, point.date),
                    y: .value("Overdue", animatedValue(point.overdueCount))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            LifeTrackTheme.ColorPalette.danger.opacity(0.22),
                            LifeTrackTheme.ColorPalette.danger.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value(selectedRange.unitTitle, point.date),
                    y: .value("Overdue", animatedValue(point.overdueCount))
                )
                .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value(selectedRange.unitTitle, point.date),
                    y: .value("Overdue", animatedValue(point.overdueCount))
                )
                .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                .symbolSize(point.overdueCount == 0 ? 0 : 38 * chartProgress)
            }
            .chartXAxis {
                AxisMarks(values: selectedRange.axisDates(for: points)) { value in
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.55))
                    AxisTick()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(selectedRange.axisLabel(for: date))
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.7))
                    AxisValueLabel()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .chartYScale(domain: 0...max(1, points.map(\.overdueCount).max() ?? 1))
            .frame(height: 230)
            .animation(animationsEnabled ? .smooth(duration: 0.85) : nil, value: chartProgress)

            chartFootnote(
                symbolName: totalOverdue == 0 ? "checkmark.circle" : "exclamationmark.circle",
                text: overdueInsight
            )
        }
    }

    private var completionInsight: String {
        guard let bestPoint, bestPoint.completedCount > 0 else {
            return "No completed tasks in this range yet."
        }

        return "\(bestPoint.label) had the strongest completion count with \(bestPoint.completedCount) finished."
    }

    private var overdueInsight: String {
        if totalOverdue == 0 {
            return "No overdue tasks in this range. The schedule is holding steady."
        }

        let peak = points.max { $0.overdueCount < $1.overdueCount }
        guard let peak else {
            return "Overdue tasks will appear here as trends develop."
        }

        return "The highest overdue count was \(peak.overdueCount) around \(peak.label)."
    }

    private func chartFootnote(symbolName: String, text: String) -> some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .frame(width: 26, height: 26)
                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())

            Text(text)
                .font(.footnote)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func animatedValue(_ value: Int) -> Double {
        animationsEnabled ? Double(value) * chartProgress : Double(value)
    }

    private func tasks(for action: StatisticsSummaryAction) -> [LifeTask] {
        switch action {
        case .completed:
            completedTasksInRange
        case .overdue:
            overdueTasksInRange
        case .completion:
            (completedTasksInRange + overdueTasksInRange).sorted { $0.updatedAt > $1.updatedAt }
        case .best:
            tasksForBestPoint
        }
    }

    private var completedTasksInRange: [LifeTask] {
        guard let interval = selectedRangeInterval else {
            return []
        }

        return activeTasks
            .filter { $0.isCompleted && $0.updatedAt >= interval.start && $0.updatedAt < interval.end }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var overdueTasksInRange: [LifeTask] {
        guard let interval = selectedRangeInterval else {
            return []
        }

        return activeTasks
            .filter { $0.isOverdue && $0.dueDate >= interval.start && $0.dueDate < interval.end }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var tasksForBestPoint: [LifeTask] {
        guard let bestPoint else {
            return []
        }

        return activeTasks
            .filter { $0.isCompleted && $0.updatedAt >= bestPoint.date && $0.updatedAt < bestPoint.endDate }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var selectedRangeInterval: DateInterval? {
        guard let first = points.first, let last = points.last else {
            return nil
        }

        return DateInterval(start: first.date, end: last.endDate)
    }

    private func toggleCompletion(for task: LifeTask) {
        performWithOptionalAnimation {
            TaskLifecycleManager.toggleCompletion(
                for: task,
                in: modelContext,
                customCategories: customCategories
            )
        }
        refreshStats(showLoader: false)
    }

    private func delete(_ task: LifeTask) {
        performWithOptionalAnimation {
            TaskLifecycleManager.delete(task, in: modelContext)
        }
        refreshStats(showLoader: false)
    }

    private func openTaskFromSummaryAction(_ task: LifeTask) {
        selectedSummaryAction = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            editingTask = task
        }
    }

    private func syncReminder(for task: LifeTask) {
        TaskLifecycleManager.synchronizeReminder(for: task, customCategories: customCategories)
    }

    private func performWithOptionalAnimation(_ updates: () -> Void) {
        guard animationsEnabled else {
            updates()
            return
        }

        withAnimation(.snappy) {
            updates()
        }
    }

    @MainActor
    private func refreshStats(showLoader: Bool = true) {
        let refreshID = UUID()
        statsRefreshID = refreshID

        let taskSnapshots = tasks.map(StatisticsTaskSnapshot.init(task:))
        let range = selectedRange

        if showLoader {
            if animationsEnabled {
                withAnimation(.snappy(duration: 0.18)) {
                    isPreparingStats = true
                }
            } else {
                isPreparingStats = true
            }
        }

        chartProgress = 0

        let calendar = Calendar.current  // capture on @MainActor before crossing to detached

        Task.detached(priority: .userInitiated) {
            let snapshot = ProductivityStatsBuilder.snapshot(for: taskSnapshots, range: range, calendar: calendar)

            await MainActor.run {
                guard statsRefreshID == refreshID else {
                    return
                }

                statsSnapshot = snapshot

                if animationsEnabled {
                    withAnimation(.snappy(duration: 0.22)) {
                        isPreparingStats = false
                    }
                } else {
                    isPreparingStats = false
                }

                runChartAnimation()
            }
        }
    }

    private func runEntranceAnimation() {
        guard animationsEnabled else {
            hasAppeared = true
            return
        }

        hasAppeared = false
        DispatchQueue.main.async {
            withAnimation(.smooth(duration: 0.42)) {
                hasAppeared = true
            }
        }
    }

    private func runChartAnimation() {
        guard animationsEnabled else {
            chartProgress = 1
            return
        }

        chartProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 1.05)) {
                chartProgress = 1
            }
        }
    }
}

private enum StatisticsTimeRange: String, CaseIterable, Identifiable, Sendable {
    case days
    case weeks
    case months

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days: "Days"
        case .weeks: "Weeks"
        case .months: "Months"
        }
    }

    var unitTitle: String {
        switch self {
        case .days: "Day"
        case .weeks: "Week"
        case .months: "Month"
        }
    }

    var summarySubtitle: String {
        switch self {
        case .days: "Past 14 days"
        case .weeks: "Past 8 weeks"
        case .months: "Past 6 months"
        }
    }

    var bucketCount: Int {
        switch self {
        case .days: 14
        case .weeks: 8
        case .months: 6
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        }
    }

    func axisDates(for points: [ProductivityStatPoint]) -> [Date] {
        let dates = points.map(\.date)

        switch self {
        case .days:
            return dates.atReadableAxisIndexes([0, 3, 6, 9, 13])
        case .weeks:
            return dates.atReadableAxisIndexes([0, 2, 4, 6, 7])
        case .months:
            return dates
        }
    }

    func axisLabel(for date: Date) -> String {
        switch self {
        case .days, .weeks:
            return date.formatted(Date.FormatStyle().day().month(.abbreviated))
        case .months:
            return date.formatted(Date.FormatStyle().month(.abbreviated))
        }
    }
}

private extension Array where Element == Date {
    func atReadableAxisIndexes(_ indexes: [Int]) -> [Date] {
        indexes.compactMap { index in
            guard indices.contains(index) else {
                return nil
            }

            return self[index]
        }
    }
}

private struct ProductivityStatPoint: Identifiable, Sendable {
    var id: Date { date }

    let date: Date
    let endDate: Date
    let label: String
    let completedCount: Int
    let overdueCount: Int
}

private struct ProductivityStatsSnapshot: Sendable {
    let points: [ProductivityStatPoint]
    let totalCompleted: Int
    let totalOverdue: Int
    let bestPoint: ProductivityStatPoint?
    let completionRate: Int
    let currentStreak: Int
    let bestStreak: Int
    let weekdayBreakdown: [WeekdayPoint]
    let bestWeekday: WeekdayPoint?
    let focusMinutesCompleted: Int
    let focusByCategory: [CategoryShareEntry]
    let categoryShare: [CategoryShareEntry]

    static let empty = ProductivityStatsSnapshot(
        points: [],
        totalCompleted: 0,
        totalOverdue: 0,
        bestPoint: nil,
        completionRate: 0,
        currentStreak: 0,
        bestStreak: 0,
        weekdayBreakdown: [],
        bestWeekday: nil,
        focusMinutesCompleted: 0,
        focusByCategory: [],
        categoryShare: []
    )
}

private struct WeekdayPoint: Sendable, Identifiable {
    var id: Int { weekday }
    let weekday: Int
    let shortTitle: String
    let fullTitle: String
    let completedCount: Int
}

private struct CategoryShareEntry: Sendable, Identifiable {
    var id: String { rawValue }
    let rawValue: String
    let completedCount: Int
    let focusMinutes: Int
    let percent: Double
}

private struct StatisticsTaskSnapshot: Sendable {
    let id: UUID
    let dueDate: Date
    let updatedAt: Date
    let isCompleted: Bool
    let isDeleted: Bool
    let categoryRawValue: String
    let scheduledDurationMinutes: Int

    init(task: LifeTask) {
        id = task.id
        dueDate = task.dueDate
        updatedAt = task.updatedAt
        isCompleted = task.isCompleted
        isDeleted = task.isDeleted
        categoryRawValue = task.categoryRawValue
        scheduledDurationMinutes = task.scheduledDurationMinutes
    }

    func isOverdue(at date: Date) -> Bool {
        !isDeleted && !isCompleted && dueDate < date
    }
}

private enum StatisticsSummaryAction: String, Identifiable {
    case completed
    case overdue
    case completion
    case best

    var id: String { rawValue }

    var title: String {
        switch self {
        case .completed: "Completed"
        case .overdue: "Overdue"
        case .completion: "Completion"
        case .best: "Best Period"
        }
    }

    var subtitle: String {
        switch self {
        case .completed: "Finished tasks in this range."
        case .overdue: "Past-due tasks that still need a decision."
        case .completion: "Compare finished work against overdue work."
        case .best: "Review the strongest completion period."
        }
    }

    var symbolName: String {
        switch self {
        case .completed: "checkmark.seal.fill"
        case .overdue: "exclamationmark.triangle.fill"
        case .completion: "chart.pie.fill"
        case .best: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .completed: LifeTrackTheme.ColorPalette.success
        case .overdue: LifeTrackTheme.ColorPalette.danger
        case .completion: LifeTrackTheme.ColorPalette.accent
        case .best: LifeTrackTheme.ColorPalette.warning
        }
    }
}

private struct StatisticsSummaryActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(LifeTrackSettings.Keys.binRetentionPeriod) private var binRetentionRawValue = TaskBinRetentionPeriod.fallback.rawValue

    @State private var pendingReopenTask: LifeTask?
    @State private var binUndoState: TaskBinUndoState?
    @State private var restoredToastState: TaskRestoredToastState?

    let action: StatisticsSummaryAction
    let range: StatisticsTimeRange
    let tasks: [LifeTask]
    let totalCompleted: Int
    let totalOverdue: Int
    let completionRate: Int
    let bestPoint: ProductivityStatPoint?
    let customCategories: [CustomTaskCategory]
    let onToggleCompletion: (LifeTask) -> Void
    let onEdit: (LifeTask) -> Void
    let onDelete: (LifeTask) -> Void
    let onShowAction: (StatisticsSummaryAction) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        headerCard

                        if action == .completion {
                            completionActions
                        }

                        taskSection
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .overlay {
                if let pendingReopenTask {
                    LifeTrackConfirmationOverlay(
                        symbolName: "arrow.uturn.left.circle.fill",
                        title: "Move back to in progress?",
                        message: "\"\(pendingReopenTask.title)\" is already completed. Reopening it will return the task to your active lists and affect completion stats.",
                        confirmTitle: "Move Back",
                        cancelTitle: "Keep Completed",
                        tint: LifeTrackTheme.ColorPalette.warning,
                        onConfirm: { confirmReopen(pendingReopenTask) },
                        onCancel: { self.pendingReopenTask = nil }
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if let binUndoState {
                    TaskBinUndoToast(
                        taskTitle: binUndoState.task.title,
                        onRestore: { restoreFromUndo(binUndoState.task) },
                        onDismiss: { dismissUndoToast(id: binUndoState.id) }
                    )
                    .task(id: binUndoState.id) {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        await MainActor.run {
                            dismissUndoToast(id: binUndoState.id)
                        }
                    }
                } else if let restoredToastState {
                    TaskRestoredToast(
                        taskTitle: restoredToastState.taskTitle,
                        onDismiss: { dismissRestoredToast(id: restoredToastState.id) }
                    )
                    .task(id: restoredToastState.id) {
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        await MainActor.run {
                            dismissRestoredToast(id: restoredToastState.id)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
        }
    }

    private var headerCard: some View {
        SectionCardView {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                    .background(action.tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(action.title)
                        .font(.lifeTrackTitle)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(headerSubtitle)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                Text(headerValue)
                    .font(.system(.title, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }

            HStack(spacing: LifeTrackTheme.Spacing.small) {
                SummaryActionMetricPill(title: "Completed", value: totalCompleted.formatted(), tint: LifeTrackTheme.ColorPalette.success)
                SummaryActionMetricPill(title: "Overdue", value: totalOverdue.formatted(), tint: LifeTrackTheme.ColorPalette.danger)
                SummaryActionMetricPill(title: "Rate", value: "\(completionRate)%", tint: LifeTrackTheme.ColorPalette.accent)
            }
        }
    }

    private var completionActions: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            SummaryActionButton(
                title: "Review Completed",
                subtitle: "\(totalCompleted) finished",
                symbolName: "checkmark.circle",
                tint: LifeTrackTheme.ColorPalette.success
            ) {
                onShowAction(.completed)
            }

            SummaryActionButton(
                title: "Review Overdue",
                subtitle: "\(totalOverdue) past due",
                symbolName: "exclamationmark.circle",
                tint: LifeTrackTheme.ColorPalette.danger
            ) {
                onShowAction(.overdue)
            }
        }
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            SectionHeaderView(
                title: taskSectionTitle,
                trailing: tasks.isEmpty ? nil : tasks.count.formatted(),
                infoMessage: taskSectionInfo
            )

            if tasks.isEmpty {
                StatisticsSummaryEmptyView(action: action)
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(tasks) { task in
                        TaskRowView(
                            task: task,
                            onToggleCompletion: { requestToggleCompletion(for: task) },
                            onEdit: { onEdit(task) },
                            onDelete: { moveToBin(task) },
                            categoryOption: task.categoryOption(customCategories: customCategories)
                        )
                    }
                }
            }
        }
    }

    private var headerSubtitle: String {
        switch action {
        case .best:
            if let bestPoint, bestPoint.completedCount > 0 {
                return "\(bestPoint.label) was your strongest \(range.unitTitle.lowercased()) with \(bestPoint.completedCount) completed."
            }
            return "No standout \(range.unitTitle.lowercased()) yet."
        default:
            return action.subtitle
        }
    }

    private var headerValue: String {
        switch action {
        case .completed:
            totalCompleted.formatted()
        case .overdue:
            totalOverdue.formatted()
        case .completion:
            "\(completionRate)%"
        case .best:
            (bestPoint?.completedCount ?? 0).formatted()
        }
    }

    private var taskSectionTitle: String {
        switch action {
        case .completion:
            "Tasks Behind This Rate"
        case .best:
            "Best \(range.unitTitle) Tasks"
        default:
            "Tasks"
        }
    }

    private var taskSectionInfo: String {
        switch action {
        case .completed:
            "Completed tasks can be moved back to open, edited, or deleted."
        case .overdue:
            "Overdue tasks can be completed, edited with a new due date, or deleted."
        case .completion:
            "This list combines completed and overdue tasks used for the completion rate."
        case .best:
            "These are the completed tasks from the strongest period in this range."
        }
    }

    private var binRetentionPeriod: TaskBinRetentionPeriod {
        TaskBinRetentionPeriod(rawValue: binRetentionRawValue) ?? .fallback
    }

    private func requestToggleCompletion(for task: LifeTask) {
        guard !task.isCompleted else {
            pendingReopenTask = task
            return
        }

        onToggleCompletion(task)
    }

    private func confirmReopen(_ task: LifeTask) {
        pendingReopenTask = nil
        LifeTrackHaptics.lightImpact()
        onToggleCompletion(task)
    }

    private func moveToBin(_ task: LifeTask) {
        let movedToBin = TaskLifecycleManager.delete(
            task,
            in: modelContext,
            retentionPeriod: binRetentionPeriod
        )

        if movedToBin {
            showUndoToast(for: task)
        }
    }

    private func restoreFromUndo(_ task: LifeTask) {
        let taskTitle = task.title
        dismissUndoToast(id: binUndoState?.id)
        LifeTrackHaptics.lightImpact()
        TaskLifecycleManager.restore(
            task,
            in: modelContext,
            customCategories: customCategories
        )
        showRestoredToast(taskTitle: taskTitle)
    }

    private func showUndoToast(for task: LifeTask) {
        guard animationsEnabled else {
            binUndoState = TaskBinUndoState(task: task)
            return
        }

        withAnimation(.snappy(duration: 0.2)) {
            binUndoState = TaskBinUndoState(task: task)
        }
    }

    private func dismissUndoToast(id: UUID?) {
        guard id == nil || binUndoState?.id == id else {
            return
        }

        guard animationsEnabled else {
            binUndoState = nil
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            binUndoState = nil
        }
    }

    private func showRestoredToast(taskTitle: String) {
        let toastState = TaskRestoredToastState(taskTitle: taskTitle)

        guard animationsEnabled else {
            restoredToastState = toastState
            return
        }

        withAnimation(.snappy(duration: 0.2)) {
            restoredToastState = toastState
        }
    }

    private func dismissRestoredToast(id: UUID?) {
        guard id == nil || restoredToastState?.id == id else {
            return
        }

        guard animationsEnabled else {
            restoredToastState = nil
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            restoredToastState = nil
        }
    }
}

private struct SummaryActionMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.7)
        }
    }
}

private struct SummaryActionButton: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LifeTrackTheme.Spacing.small) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
            }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97))
    }
}

private struct StatisticsSummaryEmptyView: View {
    let action: StatisticsSummaryAction

    var body: some View {
        SectionCardView {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                    .background(action.tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(emptyTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(emptyMessage)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var emptyTitle: String {
        switch action {
        case .completed: "No completed tasks here"
        case .overdue: "No overdue tasks here"
        case .completion: "No rate details yet"
        case .best: "No best period yet"
        }
    }

    private var emptyMessage: String {
        switch action {
        case .completed: "Finished tasks in this range will appear here."
        case .overdue: "Past-due tasks in this range will appear here."
        case .completion: "Complete tasks or clear overdue items to build a rate."
        case .best: "A best period appears after tasks are completed in this range."
        }
    }
}

private enum ProductivityStatsBuilder {
    nonisolated static func snapshot(
        for tasks: [StatisticsTaskSnapshot],
        range: StatisticsTimeRange,
        calendar: Calendar
    ) -> ProductivityStatsSnapshot {
        let points = points(for: tasks, range: range, calendar: calendar)
        let totalCompleted = points.reduce(0) { $0 + $1.completedCount }
        let totalOverdue = points.reduce(0) { $0 + $1.overdueCount }
        let bestPoint = points.max { $0.completedCount < $1.completedCount }
        let comparedTotal = totalCompleted + totalOverdue
        let completionRate = comparedTotal > 0
            ? Int((Double(totalCompleted) / Double(comparedTotal) * 100).rounded())
            : 0

        let activeTasks = tasks.filter { !$0.isDeleted }
        let interval = rangeInterval(for: range, calendar: calendar)
        let streakData = streaks(for: activeTasks, calendar: calendar)
        let weekdayBreakdown = weekdayBreakdown(for: activeTasks, interval: interval, calendar: calendar)
        let bestWeekdayCandidate = weekdayBreakdown.max { $0.completedCount < $1.completedCount }
        let bestWeekday = (bestWeekdayCandidate?.completedCount ?? 0) > 0 ? bestWeekdayCandidate : nil
        let focus = focusStats(for: activeTasks, interval: interval)
        let categoryShare = categoryShare(for: activeTasks, interval: interval)

        return ProductivityStatsSnapshot(
            points: points,
            totalCompleted: totalCompleted,
            totalOverdue: totalOverdue,
            bestPoint: bestPoint,
            completionRate: completionRate,
            currentStreak: streakData.current,
            bestStreak: streakData.best,
            weekdayBreakdown: weekdayBreakdown,
            bestWeekday: bestWeekday,
            focusMinutesCompleted: focus.totalMinutes,
            focusByCategory: focus.byCategory,
            categoryShare: categoryShare
        )
    }

    nonisolated private static func rangeInterval(for range: StatisticsTimeRange, calendar: Calendar) -> DateInterval {
        let now = Date()
        let currentBucketStart = bucketStart(for: now, range: range, calendar: calendar)
        let firstBucketStart = calendar.date(
            byAdding: range.calendarComponent,
            value: -(range.bucketCount - 1),
            to: currentBucketStart
        ) ?? currentBucketStart
        let end = calendar.date(byAdding: range.calendarComponent, value: 1, to: currentBucketStart) ?? now
        return DateInterval(start: firstBucketStart, end: end)
    }

    nonisolated private static func streaks(for tasks: [StatisticsTaskSnapshot], calendar: Calendar) -> (current: Int, best: Int) {
        let completionDays = Set(
            tasks
                .filter { $0.isCompleted }
                .map { calendar.startOfDay(for: $0.updatedAt) }
        )
        guard !completionDays.isEmpty else {
            return (0, 0)
        }

        let sorted = completionDays.sorted()
        var best = 1
        var run = 1
        for index in 1..<sorted.count {
            let previous = sorted[index - 1]
            let day = sorted[index]
            if let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }

        var current = 0
        var cursor = calendar.startOfDay(for: Date())
        if !completionDays.contains(cursor) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
               completionDays.contains(yesterday) {
                cursor = yesterday
            } else {
                return (0, best)
            }
        }

        while completionDays.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return (current, max(best, current))
    }

    nonisolated private static func weekdayBreakdown(
        for tasks: [StatisticsTaskSnapshot],
        interval: DateInterval,
        calendar: Calendar
    ) -> [WeekdayPoint] {
        let completed = tasks.filter { $0.isCompleted && interval.contains($0.updatedAt) }
        let byWeekday = Dictionary(grouping: completed) { calendar.component(.weekday, from: $0.updatedAt) }

        let shortSymbols = calendar.veryShortStandaloneWeekdaySymbols
        let longSymbols = calendar.standaloneWeekdaySymbols

        return (1...7).map { weekday in
            let idx = weekday - 1
            let shortTitle = idx < shortSymbols.count ? shortSymbols[idx] : ""
            let fullTitle = idx < longSymbols.count ? longSymbols[idx] : shortTitle
            return WeekdayPoint(
                weekday: weekday,
                shortTitle: shortTitle,
                fullTitle: fullTitle,
                completedCount: byWeekday[weekday]?.count ?? 0
            )
        }
    }

    nonisolated private static func focusStats(
        for tasks: [StatisticsTaskSnapshot],
        interval: DateInterval
    ) -> (totalMinutes: Int, byCategory: [CategoryShareEntry]) {
        let completed = tasks.filter { $0.isCompleted && interval.contains($0.updatedAt) }
        let total = completed.reduce(0) { $0 + $1.scheduledDurationMinutes }
        let byCategory = Dictionary(grouping: completed, by: \.categoryRawValue)

        let entries = byCategory
            .map { rawValue, items -> CategoryShareEntry in
                let minutes = items.reduce(0) { $0 + $1.scheduledDurationMinutes }
                let percent = total > 0 ? Double(minutes) / Double(total) : 0
                return CategoryShareEntry(
                    rawValue: rawValue,
                    completedCount: items.count,
                    focusMinutes: minutes,
                    percent: percent
                )
            }
            .sorted { $0.focusMinutes > $1.focusMinutes }

        return (total, entries)
    }

    nonisolated private static func categoryShare(
        for tasks: [StatisticsTaskSnapshot],
        interval: DateInterval
    ) -> [CategoryShareEntry] {
        let completed = tasks.filter { $0.isCompleted && interval.contains($0.updatedAt) }
        let byCategory = Dictionary(grouping: completed, by: \.categoryRawValue)
        let totalCount = completed.count

        return byCategory
            .map { rawValue, items in
                CategoryShareEntry(
                    rawValue: rawValue,
                    completedCount: items.count,
                    focusMinutes: items.reduce(0) { $0 + $1.scheduledDurationMinutes },
                    percent: totalCount > 0 ? Double(items.count) / Double(totalCount) : 0
                )
            }
            .sorted { $0.completedCount > $1.completedCount }
    }

    nonisolated private static func points(
        for tasks: [StatisticsTaskSnapshot],
        range: StatisticsTimeRange,
        calendar: Calendar = .current
    ) -> [ProductivityStatPoint] {
        let now = Date()
        let currentBucketStart = bucketStart(for: now, range: range, calendar: calendar)
        let firstBucketStart = calendar.date(
            byAdding: range.calendarComponent,
            value: -(range.bucketCount - 1),
            to: currentBucketStart
        ) ?? currentBucketStart
        let activeTasks = tasks.filter { !$0.isDeleted }

        return (0..<range.bucketCount).compactMap { offset in
            guard
                let bucketStart = calendar.date(byAdding: range.calendarComponent, value: offset, to: firstBucketStart),
                let bucketEnd = calendar.date(byAdding: range.calendarComponent, value: 1, to: bucketStart)
            else {
                return nil
            }

            let completedCount = activeTasks.filter { task in
                task.isCompleted && task.updatedAt >= bucketStart && task.updatedAt < bucketEnd
            }.count

            let overdueCount = activeTasks.filter { task in
                task.isOverdue(at: now) && task.dueDate >= bucketStart && task.dueDate < bucketEnd
            }.count

            return ProductivityStatPoint(
                date: bucketStart,
                endDate: bucketEnd,
                label: label(for: bucketStart, range: range),
                completedCount: completedCount,
                overdueCount: overdueCount
            )
        }
    }

    nonisolated private static func bucketStart(for date: Date, range: StatisticsTimeRange, calendar: Calendar) -> Date {
        switch range {
        case .days:
            return calendar.startOfDay(for: date)
        case .weeks:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .months:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    nonisolated private static func label(for date: Date, range: StatisticsTimeRange) -> String {
        switch range {
        case .days, .weeks:
            return date.formatted(Date.FormatStyle().month(.abbreviated).day())
        case .months:
            return date.formatted(Date.FormatStyle().month(.abbreviated))
        }
    }
}

private struct StatisticsRangeSelector: View {
    @Binding var selectedRange: StatisticsTimeRange
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StatisticsTimeRange.allCases) { range in
                Button {
                    select(range)
                } label: {
                    Text(range.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selectedRange == range ? Color.white : LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedRange == range {
                                Capsule()
                                    .fill(LifeTrackTheme.ColorPalette.accentGradient)
                                    .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.20), radius: 8, x: 0, y: 4)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97, pressedOpacity: 0.92))
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
            }
        }
        .padding(4)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.88), in: Capsule())
        .overlay {
            Capsule()
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
        }
    }

    private func select(_ range: StatisticsTimeRange) {
        guard selectedRange != range else {
            return
        }

        guard animationsEnabled else {
            selectedRange = range
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            selectedRange = range
        }
    }
}

private struct StatisticsEntranceModifier: ViewModifier {
    let index: Int
    let isVisible: Bool
    let animationsEnabled: Bool

    func body(content: Content) -> some View {
        content
            .opacity(animationsEnabled ? (isVisible ? 1 : 0) : 1)
            .offset(y: animationsEnabled ? (isVisible ? 0 : 14) : 0)
            .scaleEffect(animationsEnabled ? (isVisible ? 1 : 0.985) : 1, anchor: .top)
            .animation(
                animationsEnabled ? .smooth(duration: 0.42).delay(Double(index) * 0.055) : nil,
                value: isVisible
            )
    }
}

private extension View {
    func statisticsEntrance(index: Int, isVisible: Bool, animationsEnabled: Bool) -> some View {
        modifier(
            StatisticsEntranceModifier(
                index: index,
                isVisible: isVisible,
                animationsEnabled: animationsEnabled
            )
        )
    }
}

private struct StatisticsSummaryCard: View {
    let title: String
    let value: Int
    var suffix = ""
    let subtitle: String
    let symbolName: String
    let tint: Color
    let animationID: String
    var showsDisclosure = false

    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(alignment: .top) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 32, height: 32)
                        .background(tint.opacity(0.12), in: Circle())

                    if showsDisclosure {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(tint)
                            .frame(width: 14, height: 14)
                            .background(LifeTrackTheme.ColorPalette.cardElevated, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    StatisticsCountText(
                        value: value,
                        suffix: suffix,
                        animationID: animationID,
                        animationsEnabled: animationsEnabled
                    )
                    .font(.system(.title2, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                    if showsDisclosure {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText.opacity(0.62))
                            .offset(y: -1)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .lifeTrackCard(padding: LifeTrackTheme.Spacing.medium, backgroundColor: LifeTrackTheme.ColorPalette.cardElevated)
    }
}

private struct StatisticsCountText: View {
    let value: Int
    let suffix: String
    let animationID: String
    let animationsEnabled: Bool

    @State private var displayedValue = 0

    var body: some View {
        Text("\(displayedValue.formatted())\(suffix)")
            .contentTransition(animationsEnabled ? .numericText(value: Double(displayedValue)) : .identity)
            .onAppear { snap() }
            .onChange(of: value) { _, _ in animate() }
            .onChange(of: animationID) { _, _ in animate() }
            .onChange(of: animationsEnabled) { _, _ in animate() }
    }

    private func snap() {
        displayedValue = value
    }

    private func animate() {
        guard animationsEnabled else {
            displayedValue = value
            return
        }
        withAnimation(.easeOut(duration: value > 100 ? 1.45 : 1.05)) {
            displayedValue = value
        }
    }
}

private struct StreakInsightCard: View {
    let currentStreak: Int
    let bestStreak: Int
    let animationID: String

    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    private var subtitle: String {
        if currentStreak == 0 && bestStreak == 0 {
            return "Complete a task to start a streak."
        }
        if currentStreak == 0 {
            return "Best: \(bestStreak) day\(bestStreak == 1 ? "" : "s")"
        }
        if bestStreak > currentStreak {
            return "Best: \(bestStreak) day\(bestStreak == 1 ? "" : "s")"
        }
        return "Personal best!"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(alignment: .top) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.warning)
                    .frame(width: 32, height: 32)
                    .background(LifeTrackTheme.ColorPalette.warning.opacity(0.12), in: Circle())

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    StatisticsCountText(
                        value: currentStreak,
                        suffix: "",
                        animationID: animationID,
                        animationsEnabled: animationsEnabled
                    )
                    .font(.system(.title2, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(currentStreak == 1 ? "day" : "days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Streak")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .lifeTrackCard(padding: LifeTrackTheme.Spacing.medium, backgroundColor: LifeTrackTheme.ColorPalette.cardElevated)
    }
}

private struct FocusInsightCard: View {
    let totalMinutes: Int
    let topEntry: CategoryShareEntry?
    let customCategories: [CustomTaskCategory]
    let animationID: String

    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    private var hours: Int { totalMinutes / 60 }
    private var minutesRemainder: Int { totalMinutes % 60 }

    private var topOption: TaskCategoryOption? {
        guard let topEntry else { return nil }
        return TaskCategoryOption.resolved(rawValue: topEntry.rawValue, customCategories: customCategories)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(alignment: .top) {
                Image(systemName: "hourglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: 32, height: 32)
                    .background(LifeTrackTheme.ColorPalette.accent.opacity(0.12), in: Circle())

                Spacer()

                valueLabel
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Focus")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                if let topOption, totalMinutes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: topOption.symbolName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(topOption.tint)
                        Text("Top: \(topOption.title)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .lineLimit(1)
                    }
                } else {
                    Text("Scheduled minutes completed")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .lifeTrackCard(padding: LifeTrackTheme.Spacing.medium, backgroundColor: LifeTrackTheme.ColorPalette.cardElevated)
    }

    @ViewBuilder
    private var valueLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if totalMinutes == 0 {
                Text("0")
                    .font(.system(.title2, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text("m")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            } else if hours > 0 {
                StatisticsCountText(
                    value: hours,
                    suffix: "",
                    animationID: "\(animationID)-h",
                    animationsEnabled: animationsEnabled
                )
                .font(.system(.title2, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text("h")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                if minutesRemainder > 0 {
                    StatisticsCountText(
                        value: minutesRemainder,
                        suffix: "",
                        animationID: "\(animationID)-m",
                        animationsEnabled: animationsEnabled
                    )
                    .font(.system(.title3, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("m")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            } else {
                StatisticsCountText(
                    value: minutesRemainder,
                    suffix: "",
                    animationID: "\(animationID)-m",
                    animationsEnabled: animationsEnabled
                )
                .font(.system(.title2, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text("m")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
        }
    }
}

private struct CategoryMixCard: View {
    let entries: [CategoryShareEntry]
    let customCategories: [CustomTaskCategory]
    let chartProgress: Double
    let animationsEnabled: Bool

    private var topEntries: [CategoryShareEntry] {
        Array(entries.prefix(5))
    }

    private var totalCompleted: Int {
        entries.reduce(0) { $0 + $1.completedCount }
    }

    var body: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Category Mix",
                subtitle: "Where your completed tasks land.",
                trailing: totalCompleted > 0 ? totalCompleted.formatted() : nil
            )

            if topEntries.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                    stackedBar
                    legend
                }
                .padding(.top, 2)
            }
        }
    }

    private var stackedBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(topEntries) { entry in
                    let option = TaskCategoryOption.resolved(rawValue: entry.rawValue, customCategories: customCategories)
                    let progress = animationsEnabled ? chartProgress : 1
                    let width = max(0, geo.size.width * CGFloat(entry.percent) * progress)
                    Rectangle()
                        .fill(option.tint)
                        .frame(width: width)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 16)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.6), lineWidth: 0.7)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(topEntries) { entry in
                let option = TaskCategoryOption.resolved(rawValue: entry.rawValue, customCategories: customCategories)
                HStack(spacing: 10) {
                    Circle()
                        .fill(option.tint)
                        .frame(width: 9, height: 9)

                    Text(option.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: LifeTrackTheme.Spacing.small)

                    Text("\(entry.completedCount) · \(Int((entry.percent * 100).rounded()))%")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .monospacedDigit()
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .frame(width: 26, height: 26)
                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())

            Text("Completed tasks in this range will be grouped by category here.")
                .font(.footnote)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct BestWeekdayCard: View {
    let weekdayBreakdown: [WeekdayPoint]
    let bestWeekday: WeekdayPoint?
    let chartProgress: Double
    let animationsEnabled: Bool

    var body: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Best Day of Week",
                subtitle: subtitle,
                trailing: bestWeekday.map { "\($0.completedCount)" }
            )

            if bestWeekday == nil {
                emptyState
            } else {
                chart
            }
        }
    }

    private var subtitle: String {
        guard let bestWeekday else {
            return "Your strongest day will emerge here."
        }
        let suffix = bestWeekday.completedCount == 1 ? "completion" : "completions"
        return "\(bestWeekday.fullTitle) leads with \(bestWeekday.completedCount) \(suffix)."
    }

    private var chart: some View {
        Chart(weekdayBreakdown) { point in
            BarMark(
                x: .value("Day", point.shortTitle),
                y: .value("Completed", animatedValue(point.completedCount)),
                width: .ratio(0.65)
            )
            .foregroundStyle(barStyle(for: point))
            .cornerRadius(5)
        }
        .chartXScale(domain: weekdayBreakdown.map(\.shortTitle))
        .chartXAxis {
            AxisMarks(values: weekdayBreakdown.map(\.shortTitle)) { value in
                AxisValueLabel {
                    if let title = value.as(String.self) {
                        Text(title)
                            .font(.caption2)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.7))
                AxisValueLabel()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
        }
        .chartYScale(domain: 0...max(1, weekdayBreakdown.map(\.completedCount).max() ?? 1))
        .frame(height: 170)
        .animation(animationsEnabled ? .smooth(duration: 0.85) : nil, value: chartProgress)
    }

    private func barStyle(for point: WeekdayPoint) -> AnyShapeStyle {
        if point.weekday == bestWeekday?.weekday {
            return AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient)
        }
        return AnyShapeStyle(LifeTrackTheme.ColorPalette.accent.opacity(0.28))
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .frame(width: 26, height: 26)
                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())

            Text("Complete tasks across the week to discover your strongest day.")
                .font(.footnote)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func animatedValue(_ value: Int) -> Double {
        animationsEnabled ? Double(value) * chartProgress : Double(value)
    }
}

#Preview {
    NavigationStack {
        StatisticsView(
            tasks: [
                LifeTask(title: "Send report", category: .work, dueDate: Date(), isCompleted: true, updatedAt: Date()),
                LifeTask(title: "Book appointment", category: .health, dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            ]
        )
    }
}
