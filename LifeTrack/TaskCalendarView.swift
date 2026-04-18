//
//  TaskCalendarView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI

struct TaskCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(LifeTrackSettings.Keys.binRetentionPeriod) private var binRetentionRawValue = TaskBinRetentionPeriod.fallback.rawValue

    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
    let focusAvailabilityOnAppear: Bool
    let initialAvailabilityRange: AvailabilityShareRange
    let onToggleCompletion: (LifeTask) -> Void
    let onEdit: (LifeTask) -> Void
    let onDelete: (LifeTask) -> Void

    @State private var selectedScope: TaskCalendarScope = .month
    @State private var selectedDate = Date()
    @State private var selectedAvailabilityRange: AvailabilityShareRange
    @State private var pendingReopenTask: LifeTask?
    @State private var binUndoState: TaskBinUndoState?
    @State private var restoredToastState: TaskRestoredToastState?

    private let calendar = Calendar.current

    init(
        tasks: [LifeTask],
        customCategories: [CustomTaskCategory],
        focusAvailabilityOnAppear: Bool = false,
        initialAvailabilityRange: AvailabilityShareRange = .today,
        onToggleCompletion: @escaping (LifeTask) -> Void,
        onEdit: @escaping (LifeTask) -> Void,
        onDelete: @escaping (LifeTask) -> Void
    ) {
        self.tasks = tasks
        self.customCategories = customCategories
        self.focusAvailabilityOnAppear = focusAvailabilityOnAppear
        self.initialAvailabilityRange = initialAvailabilityRange
        self.onToggleCompletion = onToggleCompletion
        self.onEdit = onEdit
        self.onDelete = onDelete
        _selectedAvailabilityRange = State(initialValue: initialAvailabilityRange)
    }

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        header
                        calendarCard
                        AvailabilityTimelineView(
                            selectedDate: selectedDate,
                            selectedRange: $selectedAvailabilityRange,
                            tasks: tasks,
                            customCategories: customCategories
                        )
                        .id(CalendarScrollTarget.availability)
                        selectedTasksSection
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    guard focusAvailabilityOnAppear else {
                        return
                    }

                    selectedAvailabilityRange = initialAvailabilityRange

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 220_000_000)
                        scrollToAvailability(with: proxy)
                    }
                }
            }
        }
        .overlay {
            if let pendingReopenTask {
                LifeTrackConfirmationOverlay(
                    symbolName: "arrow.uturn.left.circle.fill",
                    title: "Move back to in progress?",
                    message: "\"\(pendingReopenTask.title)\" is already completed. Reopening it will return the task to your active lists.",
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
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scrollToAvailability(with proxy: ScrollViewProxy) {
        guard animationsEnabled else {
            proxy.scrollTo(CalendarScrollTarget.availability, anchor: .top)
            return
        }

        withAnimation(.snappy(duration: 0.36)) {
            proxy.scrollTo(CalendarScrollTarget.availability, anchor: .top)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calendar")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("See your tasks, blocked time, and availability by date.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var calendarCard: some View {
        SectionCardView {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedDate.formatted(Date.FormatStyle().month(.wide).year()))
                        .font(.lifeTrackTitle)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(selectedScope.subtitle)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer()

                HStack(spacing: 8) {
                    calendarStepButton(symbolName: "chevron.left", direction: -1)
                    calendarStepButton(symbolName: "chevron.right", direction: 1)
                }
            }

            CalendarScopeSelector(selectedScope: $selectedScope)

            weekdayHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                ForEach(visibleDays, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        isCurrentMonth: calendar.isDate(date, equalTo: selectedDate, toGranularity: .month),
                        taskCount: tasks(on: date).count,
                        completedCount: tasks(on: date).filter(\.isCompleted).count
                    ) {
                        selectedDate = date
                    }
                }
            }
        }
    }

    private var selectedTasksSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            SectionHeaderView(
                title: selectedDate.formatted(Date.FormatStyle().weekday(.wide).month(.abbreviated).day()),
                trailing: selectedDayTasks.isEmpty ? nil : selectedDayTasks.count.formatted(),
                infoMessage: "Tasks shown here are grouped by their due date. Swipe a task to complete, edit, or delete it."
            )

            if selectedDayTasks.isEmpty {
                SectionCardView {
                    HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                            .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                            .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No tasks on this date")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                            Text("Pick another date or add a task with this due date.")
                                .font(.footnote)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        }
                    }
                }
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(selectedDayTasks) { task in
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

    private var weekdayHeader: some View {
        HStack(spacing: 7) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                Text(weekday.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var visibleDays: [Date] {
        switch selectedScope {
        case .month:
            monthDays(for: selectedDate)
        case .week:
            weekDays(for: selectedDate)
        }
    }

    private var selectedDayTasks: [LifeTask] {
        tasks(on: selectedDate)
            .sorted {
                if $0.isCompleted != $1.isCompleted {
                    return !$0.isCompleted
                }
                return $0.dueDate < $1.dueDate
            }
    }

    private func calendarStepButton(symbolName: String, direction: Int) -> some View {
        Button {
            moveCalendar(direction: direction)
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: 34, height: 34)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92))
    }

    private func moveCalendar(direction: Int) {
        let component: Calendar.Component = selectedScope == .month ? .month : .weekOfYear
        selectedDate = calendar.date(byAdding: component, value: direction, to: selectedDate) ?? selectedDate
    }

    private func tasks(on date: Date) -> [LifeTask] {
        tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) }
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

    private func monthDays(for date: Date) -> [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: date),
            let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end.addingTimeInterval(-1))
        else {
            return []
        }

        var days: [Date] = []
        var cursor = firstWeek.start

        while cursor < lastWeek.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return days
    }

    private func weekDays(for date: Date) -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekInterval.start)
        }
    }
}

private enum TaskCalendarScope: String, CaseIterable, Identifiable {
    case month
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "Month"
        case .week: "Week"
        }
    }

    var subtitle: String {
        switch self {
        case .month: "Monthly layout"
        case .week: "Weekly focus"
        }
    }
}

private struct CalendarScopeSelector: View {
    @Binding var selectedScope: TaskCalendarScope
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TaskCalendarScope.allCases) { scope in
                Button {
                    select(scope)
                } label: {
                    Text(scope.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selectedScope == scope ? Color.white : LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedScope == scope {
                                Capsule()
                                    .fill(LifeTrackTheme.ColorPalette.accentGradient)
                            }
                        }
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97, pressedOpacity: 0.92))
            }
        }
        .padding(4)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.88), in: Capsule())
        .overlay {
            Capsule()
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
        }
    }

    private func select(_ scope: TaskCalendarScope) {
        guard selectedScope != scope else {
            return
        }

        guard animationsEnabled else {
            selectedScope = scope
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            selectedScope = scope
        }
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let taskCount: Int
    let completedCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(date.formatted(Date.FormatStyle().day()))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(dayTextColor)

                HStack(spacing: 3) {
                    if taskCount == 0 {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 5, height: 5)
                    } else {
                        ForEach(0..<min(taskCount, 3), id: \.self) { index in
                            Circle()
                                .fill(index < completedCount ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.accent)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(cellBackground, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: isToday || isSelected ? 1 : 0.7)
            }
            .opacity(isCurrentMonth ? 1 : 0.45)
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.94, pressedOpacity: 0.94))
    }

    private var dayTextColor: Color {
        isSelected ? .white : LifeTrackTheme.ColorPalette.primaryText
    }

    private var cellBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient)
        }

        if taskCount > 0 {
            return AnyShapeStyle(LifeTrackTheme.ColorPalette.accentSoft.opacity(0.58))
        }

        return AnyShapeStyle(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.7))
    }

    private var borderColor: Color {
        if isSelected {
            return Color.white.opacity(0.38)
        }

        if isToday {
            return LifeTrackTheme.ColorPalette.accent.opacity(0.45)
        }

        return LifeTrackTheme.ColorPalette.hairline.opacity(0.75)
    }
}

private enum CalendarScrollTarget {
    case availability
}

#Preview {
    NavigationStack {
        TaskCalendarView(
            tasks: [
                LifeTask(title: "Review plan", category: .work, dueDate: Date()),
                LifeTask(title: "Pay bill", category: .finance, dueDate: Date(), isCompleted: true)
            ],
            customCategories: [],
            onToggleCompletion: { _ in },
            onEdit: { _ in },
            onDelete: { _ in }
        )
    }
}
