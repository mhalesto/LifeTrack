//
//  HomeView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LifeTask.dueDate, order: .forward) private var tasks: [LifeTask]

    @State private var isShowingTemplatePicker = false
    @State private var isShowingTaskEditor = false
    @State private var isShowingSettings = false
    @State private var isShowingStatistics = false
    @State private var selectedTemplate: TaskTemplate?
    @State private var editingTask: LifeTask?
    @State private var selectedSummary: DashboardSummaryKind?
    @AppStorage(LifeTrackSettings.Keys.nickname) private var nickname = ""
    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.avatarVersion) private var avatarVersion = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                        header

                        summaryGrid

                        quickActions

                        if tasks.isEmpty {
                            EmptyStateView(
                                title: "Start with one clear next step",
                                message: "Create a task, attach important files, and LifeTrack will keep the dashboard useful from day one.",
                                actionTitle: "Create Task",
                                action: openBlankTask
                            )
                        } else {
                            prioritySection
                            recentDocumentsSection
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                    .padding(.bottom, 126)
                }
                .scrollIndicators(.hidden)

                PrimaryFloatingButton {
                    isShowingTemplatePicker = true
                }
                .padding(.trailing, LifeTrackTheme.Spacing.xLarge)
                .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingTemplatePicker) {
                TemplatePickerView(
                    onSelectBlank: openBlankTaskFromPicker,
                    onSelectTemplate: openTemplateFromPicker
                )
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(item: $selectedSummary) { summary in
                DashboardSummarySheet(
                    summary: summary,
                    tasks: tasks(for: summary),
                    onToggleCompletion: toggleCompletion,
                    onEdit: openTaskFromSummary,
                    onDelete: delete,
                    onCreateTask: openBlankTaskFromSummary
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingTaskEditor) {
                NewTaskView(template: selectedTemplate)
            }
            .sheet(item: $editingTask) { task in
                NewTaskView(task: task)
            }
        }
        .tint(selectedTheme.accent)
        .navigationDestination(isPresented: $isShowingStatistics) {
            StatisticsView(tasks: tasks)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(greeting)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                    Text(Date().weekdayDateString)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                }

                Spacer()

                Button {
                    isShowingStatistics = true
                } label: {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        .frame(width: 42, height: 42)
                        .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.82), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open statistics")

                ProfileAvatarButton(avatarVersion: avatarVersion) {
                    isShowingSettings = true
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [LifeTrackTheme.ColorPalette.accent, Color(hex: 0x6B7BFF)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 10, height: 34)

                    Text("LifeTrack")
                        .font(.lifeTrackHero)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                }

                Text(dashboardMessage)
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LifeTrackTheme.Spacing.medium) {
            ForEach(DashboardSummaryKind.allCases) { summary in
                Button {
                    selectedSummary = summary
                } label: {
                    StatCardView(
                        title: summary.title,
                        value: tasks(for: summary).count,
                        subtitle: summary.subtitle,
                        symbolName: summary.symbolName,
                        tint: summary.tint,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(summary.title) tasks")
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(title: "Quick Actions", subtitle: "Move fast without losing structure.")

            ScrollView(.horizontal) {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    QuickActionButton(
                        title: "New task",
                        subtitle: "Start fresh",
                        symbolName: "plus",
                        tint: LifeTrackTheme.ColorPalette.accent,
                        action: openBlankTask
                    )

                    QuickActionButton(
                        title: "Email follow-up",
                        subtitle: "Use template",
                        symbolName: "envelope.badge",
                        tint: TaskCategory.work.style.tint,
                        action: {
                            selectedTemplate = TaskTemplate.common.first { $0.id == "email" }
                            isShowingTaskEditor = true
                        }
                    )

                    QuickActionButton(
                        title: "Statistics",
                        subtitle: "See trends",
                        symbolName: "chart.bar.xaxis",
                        tint: LifeTrackTheme.ColorPalette.success,
                        action: { isShowingStatistics = true }
                    )

                    QuickActionButton(
                        title: "Templates",
                        subtitle: "Smart shortcuts",
                        symbolName: "sparkles",
                        tint: Color(hex: 0x7B61D1),
                        action: { isShowingTemplatePicker = true }
                    )
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(
                title: "Today's Focus",
                subtitle: "The highest-signal tasks right now.",
                trailing: "\(priorityTasks.count)"
            )

            if priorityTasks.isEmpty {
                SectionCardView {
                    CompactMessageView(
                        symbolName: "checkmark.circle",
                        title: "No open focus tasks",
                        message: "Everything urgent is complete. Add a task when the next priority appears."
                    )
                }
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(priorityTasks) { task in
                        TaskRowView(
                            task: task,
                            onToggleCompletion: { toggleCompletion(for: task) },
                            onEdit: { editingTask = task },
                            onDelete: { delete(task) }
                        )
                    }
                }
            }
        }
    }

    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(
                title: "Recent Documents",
                subtitle: "Files connected to your tasks.",
                trailing: documentTasks.isEmpty ? nil : "\(documentTasks.count)"
            )

            if documentTasks.isEmpty {
                SectionCardView {
                    CompactMessageView(
                        symbolName: "doc.badge.plus",
                        title: "No documents yet",
                        message: "Attach a file from any task to keep supporting context nearby."
                    )
                }
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(Array(documentTasks.prefix(3))) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            RecentDocumentRow(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dueTodayTasks: [LifeTask] {
        tasks.filter { !$0.isCompleted && Calendar.current.isDateInToday($0.dueDate) }
    }

    private var upcomingTasks: [LifeTask] {
        tasks.filter { !$0.isCompleted && $0.dueDate > Date() && !Calendar.current.isDateInToday($0.dueDate) }
    }

    private var completedTasks: [LifeTask] {
        tasks.filter(\.isCompleted)
    }

    private var overdueTasks: [LifeTask] {
        tasks.filter(\.isOverdue)
    }

    private var priorityTasks: [LifeTask] {
        Array((overdueTasks + dueTodayTasks + upcomingTasks).prefix(5))
    }

    private var documentTasks: [LifeTask] {
        tasks
            .filter(\.hasDocument)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var dashboardMessage: String {
        let messages = dashboardMessageCandidates
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let taskSignal = tasks.count + (dueTodayTasks.count * 3) + (upcomingTasks.count * 5) + (completedTasks.count * 7) + (overdueTasks.count * 11)
        return messages[(dayOfYear + taskSignal) % messages.count]
    }

    private var dashboardMessageCandidates: [String] {
        if tasks.isEmpty {
            return emptyDashboardMessages
        }

        if overdueTasks.count >= 3 {
            return overdueDashboardMessages
        }

        if completedTasks.count >= max(4, tasks.count / 2) {
            return completedDashboardMessages
        }

        if dueTodayTasks.count >= 4 {
            return busyDashboardMessages
        }

        if dueTodayTasks.isEmpty && overdueTasks.isEmpty {
            return clearDayDashboardMessages
        }

        return focusDashboardMessages
    }

    private var emptyDashboardMessages: [String] {
        [
            "A calm command center for tasks, reminders, and important documents.",
            "Start small today. One clear task is enough to build momentum.",
            "A quiet dashboard is a good place to decide what matters next.",
            "Your space is clear. Add only the tasks that deserve attention.",
            "Nothing is asking for your focus yet. Use that clarity well.",
            "A fresh day is ready when you are.",
            "Build the day one thoughtful next step at a time.",
            "Capture the next important thing before it starts carrying mental weight.",
            "Your dashboard is open and calm. Put the next move here when it appears.",
            "No pressure here. Just a clean place for the work that matters.",
            "A clear list gives you room to think.",
            "Use this space to protect your time, not fill it for no reason.",
            "When the next priority shows up, LifeTrack will hold it neatly.",
            "Keep the day light until something truly needs a plan.",
            "The best systems stay quiet until they are useful.",
            "Create one task when it helps you move with more confidence.",
            "This is a good moment to set one practical intention.",
            "Your command center is ready for the next useful step.",
            "Nothing due right now. That is progress too.",
            "Keep the calm. Add structure only where it helps."
        ]
    }

    private var focusDashboardMessages: [String] {
        [
            "You have a clear path today. Take the next task one step at a time.",
            "Your priorities are visible. Start with the smallest useful move.",
            "Stay steady. The important work is already organized here.",
            "A focused list beats a crowded mind.",
            "Today has shape now. Keep moving through it with intention.",
            "You have enough structure to act without overthinking.",
            "Choose one task, finish it well, then come back for the next.",
            "Your day is organized around what needs attention.",
            "Small completions create the calm that carries the rest of the day.",
            "You are not behind. You are looking at the next right thing.",
            "The work is clearer when it is out of your head and in front of you.",
            "Keep your attention on what is due, not on everything at once.",
            "One thoughtful completion can change the pace of the whole day.",
            "Your focus is protected when the details have a place to live.",
            "This is a good day to move with precision.",
            "Make the next task easy to finish, then let momentum do its part.",
            "The list is here to support your focus, not compete with it.",
            "Stay calm and work the visible priorities.",
            "A few well-chosen actions are enough to move the day forward.",
            "Your next step is already waiting."
        ]
    }

    private var clearDayDashboardMessages: [String] {
        [
            "Nothing urgent today. Use the space to plan ahead with care.",
            "Your day is clear. That gives you room to make better choices.",
            "No tasks need immediate attention. Protect that breathing room.",
            "A quiet today is a strong place to prepare for tomorrow.",
            "You are in a good position. Keep the system light and useful.",
            "No due items right now. Enjoy the clarity and plan only what matters.",
            "Today is open. Use it for progress, rest, or thoughtful planning.",
            "A clear day is not empty. It is flexible.",
            "Your current list is under control.",
            "The day has room. Decide where your energy will matter most.",
            "Nothing is pressing. Keep the calm and look ahead when ready.",
            "A clean schedule is a form of progress.",
            "You have space to prepare without rushing.",
            "No immediate tasks. That is a good signal.",
            "Use this calm window to sharpen what comes next.",
            "The dashboard is quiet because the day is manageable.",
            "You are free to plan, refine, or simply keep the list clear.",
            "Good systems make room for calm days too.",
            "Today does not need a rescue plan. Keep it simple.",
            "Clear today, ready for what comes next."
        ]
    }

    private var completedDashboardMessages: [String] {
        [
            "Strong work. Your completed list shows real follow-through.",
            "You have been putting in the work, and the dashboard shows it.",
            "A lot is already finished. Take a moment to recognize that progress.",
            "You are building momentum through completed tasks, not just plans.",
            "Your follow-through is visible. Keep that rhythm gentle and steady.",
            "Completed work counts. Let that progress give you confidence.",
            "You have moved a meaningful amount off your plate.",
            "Good progress today. The system is recording the effort.",
            "You are turning intention into finished work.",
            "The completed list is proof that small actions are adding up.",
            "You have earned the clarity that comes from finishing things.",
            "Keep going at the pace that still feels sustainable.",
            "Your progress is not abstract. It is right here.",
            "That is a solid amount of work completed.",
            "You are doing the quiet, useful work of staying on top of life.",
            "Finished tasks create space. You have created some today.",
            "Acknowledge the work already done before choosing the next step.",
            "Your completed tasks are a good signal. Keep the standard, not the pressure.",
            "You are carrying the day well.",
            "Progress looks like this: clear, visible, and finished."
        ]
    }

    private var overdueDashboardMessages: [String] {
        [
            "Some tasks are overdue. Start with one and reset the pace calmly.",
            "Overdue does not mean failed. It means the next decision is visible.",
            "A few items need attention. Choose the most important one first.",
            "You can recover this list one practical update at a time.",
            "The overdue list is a signal, not a judgment.",
            "Start by editing dates, deleting noise, or completing one real task.",
            "This is manageable when you reduce it to the next action.",
            "Pick one overdue task and give it a clear outcome.",
            "The goal is not panic. The goal is a cleaner next step.",
            "Bring the list back under control with one focused move.",
            "Overdue work gets lighter when every item has a decision.",
            "You can still make this dashboard useful today.",
            "Start where the pressure is highest, then simplify the rest.",
            "A reset is allowed. Move dates, trim tasks, and keep going.",
            "Nothing here needs shame. It needs attention and a plan.",
            "The best move now is a small honest one.",
            "Overdue items are easier once they stop living in your head.",
            "Clear one item and the list will already feel different.",
            "You have a path back to calm. Begin with the most useful task.",
            "Today can still become organized from here."
        ]
    }

    private var busyDashboardMessages: [String] {
        [
            "Today is full, but the work is visible and ready to move.",
            "You have several tasks due today. Work the list with calm focus.",
            "A busy day needs simple sequencing. Start with the most important item.",
            "The list is active today. Keep your next action small and clear.",
            "Do not carry the whole day at once. Carry the next task.",
            "Today has weight, but it also has structure.",
            "A full dashboard is easier when every task has a place.",
            "Move through today by priority, not pressure.",
            "There is a lot in motion. Keep the pace steady.",
            "Your focus today is valuable. Spend it on the task that matters most.",
            "The day is asking for attention. You have the plan in front of you.",
            "A packed list can still feel calm when the next step is clear.",
            "Handle the visible work one decision at a time.",
            "You do not need to solve everything at once.",
            "Today is a good day for clean execution.",
            "Keep returning to the list and let it guide the next move.",
            "Busy does not have to mean scattered.",
            "A full day becomes easier when it is broken into finished pieces.",
            "Start with the task that reduces the most friction.",
            "You can make meaningful progress without rushing."
        ]
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let baseGreeting: String
        switch hour {
        case 5..<12:
            baseGreeting = "Good morning"
        case 12..<17:
            baseGreeting = "Good afternoon"
        default:
            baseGreeting = "Good evening"
        }

        guard !cleanedNickname.isEmpty else {
            return baseGreeting
        }

        return "\(baseGreeting), \(cleanedNickname)"
    }

    private var cleanedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedTheme: LifeTrackAppTheme {
        LifeTrackAppTheme(rawValue: selectedThemeID) ?? .fallback
    }

    private func openBlankTask() {
        selectedTemplate = nil
        isShowingTaskEditor = true
    }

    private func openBlankTaskFromPicker() {
        selectedTemplate = nil
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func openTemplateFromPicker(_ template: TaskTemplate) {
        selectedTemplate = template
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func openBlankTaskFromSummary() {
        selectedSummary = nil
        selectedTemplate = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func openTaskFromSummary(_ task: LifeTask) {
        selectedSummary = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            editingTask = task
        }
    }

    private func tasks(for summary: DashboardSummaryKind) -> [LifeTask] {
        switch summary {
        case .dueToday:
            dueTodayTasks
        case .upcoming:
            upcomingTasks
        case .completed:
            completedTasks
        case .overdue:
            overdueTasks
        }
    }

    private func toggleCompletion(for task: LifeTask) {
        withAnimation(.snappy) {
            task.isCompleted.toggle()
            task.updatedAt = Date()
            try? modelContext.save()
            syncReminder(for: task)
        }
    }

    private func delete(_ task: LifeTask) {
        withAnimation(.snappy) {
            ReminderScheduler.cancel(taskID: task.id)
            DocumentStore.delete(storageName: task.documentStorageName)
            modelContext.delete(task)
            try? modelContext.save()
        }
    }

    private func syncReminder(for task: LifeTask) {
        ReminderScheduler.synchronizeReminder(
            taskID: task.id,
            title: task.title,
            categoryTitle: task.category.title,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted
        )
    }
}

private enum DashboardSummaryKind: String, CaseIterable, Identifiable {
    case dueToday
    case upcoming
    case completed
    case overdue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dueToday: "Due Today"
        case .upcoming: "Upcoming"
        case .completed: "Completed"
        case .overdue: "Overdue"
        }
    }

    var subtitle: String {
        switch self {
        case .dueToday: "Needs attention"
        case .upcoming: "Planned ahead"
        case .completed: "Finished"
        case .overdue: "Past due"
        }
    }

    var sheetSubtitle: String {
        switch self {
        case .dueToday: "Tasks that need attention before the day closes."
        case .upcoming: "Planned work coming up after today."
        case .completed: "Finished tasks you can review or move back to open."
        case .overdue: "Past-due tasks that need a new decision."
        }
    }

    var emptyTitle: String {
        switch self {
        case .dueToday: "Nothing due today"
        case .upcoming: "No upcoming tasks"
        case .completed: "No completed tasks yet"
        case .overdue: "Nothing overdue"
        }
    }

    var emptyMessage: String {
        switch self {
        case .dueToday: "Your day is clear. Create a task if something needs attention."
        case .upcoming: "Add due dates to see what is planned beyond today."
        case .completed: "Completed tasks will appear here once you finish them."
        case .overdue: "No past-due items. Keep the dashboard current by updating due dates."
        }
    }

    var symbolName: String {
        switch self {
        case .dueToday: "sun.max"
        case .upcoming: "calendar"
        case .completed: "checkmark.seal"
        case .overdue: "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .dueToday: LifeTrackTheme.ColorPalette.accent
        case .upcoming: Color(hex: 0x5865B8)
        case .completed: LifeTrackTheme.ColorPalette.success
        case .overdue: LifeTrackTheme.ColorPalette.danger
        }
    }
}

private struct DashboardSummarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let summary: DashboardSummaryKind
    let tasks: [LifeTask]
    let onToggleCompletion: (LifeTask) -> Void
    let onEdit: (LifeTask) -> Void
    let onDelete: (LifeTask) -> Void
    let onCreateTask: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                        summaryHeader

                        if tasks.isEmpty {
                            DashboardSummaryEmptyView(summary: summary) {
                                dismiss()
                                onCreateTask()
                            }
                        } else {
                            taskList
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
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

    private var summaryHeader: some View {
        SectionCardView {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: summary.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(summary.tint)
                    .frame(width: 48, height: 48)
                    .background(summary.tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.title)
                        .font(.lifeTrackTitle)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(summary.sheetSubtitle)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                Text(tasks.count.formatted())
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }

            HStack(spacing: LifeTrackTheme.Spacing.small) {
                SummaryMetricPill(title: "Categories", value: categoryCount.formatted())
                SummaryMetricPill(title: documentCount == 1 ? "File" : "Files", value: documentCount.formatted())
                SummaryMetricPill(title: timelineTitle, value: timelineValue)
            }
        }
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(
                title: "Tasks",
                subtitle: summary.subtitle,
                trailing: tasks.count.formatted()
            )

            LazyVStack(spacing: LifeTrackTheme.Spacing.small) {
                ForEach(tasks) { task in
                    DashboardSummaryTaskCard(
                        task: task,
                        onToggleCompletion: { onToggleCompletion(task) },
                        onEdit: { onEdit(task) },
                        onDelete: { onDelete(task) }
                    )
                }
            }
        }
    }

    private var categoryCount: Int {
        Set(tasks.map(\.categoryRawValue)).count
    }

    private var documentCount: Int {
        tasks.filter(\.hasDocument).count
    }

    private var timelineTitle: String {
        summary == .completed ? "Latest" : "Next Due"
    }

    private var timelineValue: String {
        guard !tasks.isEmpty else {
            return "None"
        }

        if summary == .completed {
            return tasks.sorted { $0.updatedAt > $1.updatedAt }.first?.updatedAt.dayMonthString ?? "None"
        }

        return tasks.sorted { $0.dueDate < $1.dueDate }.first?.dueDate.dayMonthString ?? "None"
    }
}

private struct SummaryMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.9), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.7)
        }
    }
}

private struct DashboardSummaryTaskCard: View {
    let task: LifeTask
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : task.isOverdue ? "exclamationmark.circle.fill" : "circle.dotted")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: 34, height: 34)
                    .background(statusTint.opacity(0.11), in: Circle())

                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        CategoryChipView(category: task.category)

                        StatusPillView(
                            title: statusTitle,
                            symbolName: statusSymbol,
                            tint: statusTint
                        )

                        if task.hasDocument {
                            StatusPillView(
                                title: "File",
                                symbolName: "paperclip",
                                tint: LifeTrackTheme.ColorPalette.secondaryText
                            )
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(task.notes)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: LifeTrackTheme.Spacing.small) {
                Button(action: onToggleCompletion) {
                    Label(task.isCompleted ? "Move to Open" : "Complete", systemImage: task.isCompleted ? "arrow.uturn.left" : "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.success)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background((task.isCompleted ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.success).opacity(0.11), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }

    private var statusTitle: String {
        if task.isCompleted {
            return "Completed"
        }

        if task.isOverdue {
            return "Overdue"
        }

        if Calendar.current.isDateInToday(task.dueDate) {
            return "Today \(task.dueDate.timeString)"
        }

        return task.dueDate.dayMonthString
    }

    private var statusSymbol: String {
        if task.isCompleted {
            return "checkmark.circle.fill"
        }

        return task.isOverdue ? "exclamationmark.circle.fill" : "clock"
    }

    private var statusTint: Color {
        if task.isCompleted {
            return LifeTrackTheme.ColorPalette.success
        }

        return task.isOverdue ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.accent
    }
}

private struct DashboardSummaryEmptyView: View {
    let summary: DashboardSummaryKind
    let onCreateTask: () -> Void

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                Image(systemName: summary.symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(summary.tint)
                    .frame(width: 58, height: 58)
                    .background(summary.tint.opacity(0.12), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(summary.tint.opacity(0.16), lineWidth: 10)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.emptyTitle)
                        .font(.lifeTrackHeadline)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(summary.emptyMessage)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LifeTrackPrimaryButton(title: "Create Task", systemImage: "plus", action: onCreateTask)
            }
        }
    }
}

private struct CompactMessageView: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: 38, height: 38)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct RecentDocumentRow: View {
    let task: LifeTask

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(task.category.style.tint)
                .frame(width: 42, height: 42)
                .background(task.category.style.background, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.documentDisplayName ?? "Document")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)

                Text(task.title)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
        }
        .padding(14)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, configurations: configuration)

    container.mainContext.insert(
        LifeTask(
            title: "Review insurance documents",
            category: .finance,
            dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
            documentStorageName: "insurance.pdf",
            documentDisplayName: "Insurance policy.pdf"
        )
    )
    container.mainContext.insert(
        LifeTask(
            title: "Book health check",
            category: .health,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )
    )

    return HomeView()
        .modelContainer(container)
}
