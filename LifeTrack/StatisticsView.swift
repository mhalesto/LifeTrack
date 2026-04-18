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
    @State private var selectedSummaryAction: StatisticsSummaryAction?
    @State private var editingTask: LifeTask?
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    private var points: [ProductivityStatPoint] {
        ProductivityStatsBuilder.points(for: activeTasks, range: selectedRange)
    }

    private var activeTasks: [LifeTask] {
        tasks.filter { !$0.isDeleted }
    }

    private var totalCompleted: Int {
        points.reduce(0) { $0 + $1.completedCount }
    }

    private var totalOverdue: Int {
        points.reduce(0) { $0 + $1.overdueCount }
    }

    private var bestPoint: ProductivityStatPoint? {
        points.max { $0.completedCount < $1.completedCount }
    }

    private var completionRate: Int {
        let total = totalCompleted + totalOverdue
        guard total > 0 else {
            return 0
        }

        return Int((Double(totalCompleted) / Double(total) * 100).rounded())
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
                    summarySection
                        .statisticsEntrance(index: 2, isVisible: hasAppeared, animationsEnabled: animationsEnabled)
                    completedChart
                        .statisticsEntrance(index: 3, isVisible: hasAppeared, animationsEnabled: animationsEnabled)
                    overdueChart
                        .statisticsEntrance(index: 4, isVisible: hasAppeared, animationsEnabled: animationsEnabled)
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
            runChartAnimation()
        }
        .onChange(of: selectedRange) { _, _ in
            runChartAnimation()
        }
        .onChange(of: animationsEnabled) { _, _ in
            runEntranceAnimation()
            runChartAnimation()
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
                AxisMarks(values: .stride(by: selectedRange.axisComponent)) { value in
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.55))
                    AxisTick()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline)
                    AxisValueLabel(format: selectedRange.axisFormat)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
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
                AxisMarks(values: .stride(by: selectedRange.axisComponent)) { value in
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.55))
                    AxisTick()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline)
                    AxisValueLabel(format: selectedRange.axisFormat)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
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
    }

    private func delete(_ task: LifeTask) {
        performWithOptionalAnimation {
            TaskLifecycleManager.delete(task, in: modelContext)
        }
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

private enum StatisticsTimeRange: String, CaseIterable, Identifiable {
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

    var axisComponent: Calendar.Component {
        switch self {
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        }
    }

    var axisFormat: Date.FormatStyle {
        switch self {
        case .days:
            return Date.FormatStyle().month(.abbreviated).day()
        case .weeks:
            return Date.FormatStyle().month(.abbreviated).day()
        case .months:
            return Date.FormatStyle().month(.abbreviated)
        }
    }
}

private struct ProductivityStatPoint: Identifiable {
    let id = UUID()
    let date: Date
    let endDate: Date
    let label: String
    let completedCount: Int
    let overdueCount: Int
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
        dismissUndoToast(id: binUndoState?.id)
        TaskLifecycleManager.restore(
            task,
            in: modelContext,
            customCategories: customCategories
        )
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
    static func points(for tasks: [LifeTask], range: StatisticsTimeRange, calendar: Calendar = .current) -> [ProductivityStatPoint] {
        let now = Date()
        let currentBucketStart = bucketStart(for: now, range: range, calendar: calendar)
        let firstBucketStart = calendar.date(
            byAdding: range.calendarComponent,
            value: -(range.bucketCount - 1),
            to: currentBucketStart
        ) ?? currentBucketStart

        return (0..<range.bucketCount).compactMap { offset in
            guard
                let bucketStart = calendar.date(byAdding: range.calendarComponent, value: offset, to: firstBucketStart),
                let bucketEnd = calendar.date(byAdding: range.calendarComponent, value: 1, to: bucketStart)
            else {
                return nil
            }

            let completedCount = tasks.filter { task in
                task.isCompleted && task.updatedAt >= bucketStart && task.updatedAt < bucketEnd
            }.count

            let overdueCount = tasks.filter { task in
                task.isOverdue && task.dueDate >= bucketStart && task.dueDate < bucketEnd
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

    private static func bucketStart(for date: Date, range: StatisticsTimeRange, calendar: Calendar) -> Date {
        switch range {
        case .days:
            return calendar.startOfDay(for: date)
        case .weeks:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .months:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private static func label(for date: Date, range: StatisticsTimeRange) -> String {
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
    @State private var countTask: Task<Void, Never>?

    var body: some View {
        Text("\(displayedValue.formatted())\(suffix)")
            .contentTransition(animationsEnabled ? .numericText(value: Double(displayedValue)) : .identity)
            .onAppear {
                startCount()
            }
            .onChange(of: value) { _, _ in
                startCount()
            }
            .onChange(of: animationID) { _, _ in
                startCount()
            }
            .onChange(of: animationsEnabled) { _, _ in
                startCount()
            }
            .onDisappear {
                countTask?.cancel()
            }
    }

    @MainActor
    private func startCount() {
        countTask?.cancel()

        guard animationsEnabled else {
            displayedValue = value
            return
        }

        let target = max(value, 0)
        displayedValue = 0

        guard target > 0 else {
            return
        }

        let duration = target > 100 ? 1.45 : 1.05
        let frameDelay: UInt64 = 16_666_667

        countTask = Task { @MainActor in
            let startedAt = Date()

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                let progress = min(elapsed / duration, 1)
                let easedProgress = 1 - pow(1 - progress, 3)
                displayedValue = min(Int((Double(target) * easedProgress).rounded()), target)

                if progress >= 1 {
                    break
                }

                try? await Task.sleep(nanoseconds: frameDelay)
            }

            guard !Task.isCancelled else {
                return
            }

            displayedValue = target
        }
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
