//
//  BetaFocusedDashboardHomeView.swift
//  LifeTrack
//

import SwiftData
import SwiftUI

struct CurrentDashboardHomeView: View {
    var body: some View {
        BetaDashboardHomeView()
    }
}

struct BetaFocusedDashboardHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var calendarManager = CalendarIntegrationManager.shared
    @ObservedObject private var energyReader = HealthKitEnergyReader.shared

    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && !$0.isCompleted }, sort: \LifeTask.dueDate, order: .forward)
    private var openTasks: [LifeTask]

    @Query private var todayCompletedTasks: [LifeTask]

    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    @AppStorage(LifeTrackSettings.Keys.nickname) private var nickname = ""
    @AppStorage(LifeTrackSettings.Keys.avatarVersion) private var avatarVersion = 0

    @State private var navigationPath: [BetaFocusedDashboardRoute] = []
    @State private var selectedTab: BetaFocusedDashboardTab = .home
    @State private var isShowingSettings = false
    @State private var isShowingQuickCapture = false
    @State private var isShowingVoiceCapture = false
    @State private var isShowingInbox = false
    @State private var isShowingDailyRitual = false
    @State private var isShowingOverdueRescue = false
    @State private var isShowingTaskEditor = false
    @State private var isShowingCategoryManager = false
    @State private var isShowingPaywall = false
    @State private var selectedCaptureDraft: CapturedTaskDraft? = nil
    @State private var editingTask: LifeTask? = nil
    @State private var inboxItems: [InboxItem] = InboxStore.loadOpenItems()
    @State private var totalCompletedCount: Int = 0
    @State private var dueTodayTasks: [LifeTask] = []
    @State private var overdueTasks: [LifeTask] = []
    @State private var focusTasks: [LifeTask] = []
    @State private var dayCompleteSummary: DayCompleteSummary?
    @AppStorage("beta.dashboard.lastDayCompleteCelebration") private var lastCelebrationDayKey: String = ""

    init() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        _todayCompletedTasks = Query(
            filter: #Predicate<LifeTask> { task in
                task.deletedAt == nil && task.isCompleted && task.updatedAt >= startOfDay
            },
            sort: \LifeTask.updatedAt,
            order: .reverse
        )
    }

    private var todayProgressLabel: String {
        let total = dueTodayTasks.count + todayCompletedTasks.count
        let completed = todayCompletedTasks.count

        if total > 0 {
            return "\(completed)/\(total) completed today"
        }

        return focusTasks.isEmpty ? "No tasks selected" : "\(focusTasks.count) in focus"
    }

    private var todayProgressValue: Double {
        let total = dueTodayTasks.count + todayCompletedTasks.count
        guard total > 0 else { return 0 }
        return min(max(Double(todayCompletedTasks.count) / Double(total), 0), 1)
    }

    private var dashboardPlanningInterval: DateInterval {
        CalendarAwareScheduleEngine.dayLoadInterval(for: Date())
    }

    private var dashboardBusyBlocks: [CalendarBusyBlock] {
        calendarManager.busyBlocks(overlapping: dashboardPlanningInterval)
    }

    private var focusRecommendations: [DailyFocusRecommendation] {
        DailyFocusPlanner.recommendations(from: openTasks, energyLevel: energyReader.energyLevel)
    }

    private var nextBestRecommendation: DailyFocusRecommendation? {
        focusRecommendations.first
    }

    private var focusListTasks: [LifeTask] {
        let nextBestID = nextBestRecommendation?.task.id
        var seen = Set<UUID>()
        var candidates = focusTasks.filter { task in
            guard task.id != nextBestID else { return false }
            return seen.insert(task.id).inserted
        }

        for recommendation in focusRecommendations {
            let task = recommendation.task
            guard task.id != nextBestID else { continue }
            guard seen.insert(task.id).inserted else { continue }
            candidates.append(task)
        }

        return candidates
    }

    private var hiddenFocusTaskCount: Int {
        max(focusListTasks.count - 3, 0)
    }

    private var focusListHeight: CGFloat {
        guard !focusListTasks.isEmpty else { return 0 }
        let visibleRows = min(max(focusListTasks.count, 1), 3)
        return CGFloat(visibleRows) * 65
    }

    private var nextBestScheduledBlock: ScheduledBlock? {
        guard let task = nextBestRecommendation?.task else { return nil }
        return CalendarAwareScheduleEngine.sequentialPlan(
            for: [task],
            busyBlocks: dashboardBusyBlocks,
            referenceDate: Date(),
            energyLevel: energyReader.energyLevel
        ).blocks.first
    }

    private var planPreview: BetaFocusedDashboardPlanPreviewModel {
        let candidates = Array(focusRecommendations.prefix(5).map(\.task))
        guard !candidates.isEmpty else {
            return BetaFocusedDashboardPlanPreviewModel(
                summary: "Nothing needs planning",
                detail: "Inbox capture is ready when something comes up.",
                rescueCount: overdueTasks.count,
                busyBlockCount: dashboardBusyBlocks.count
            )
        }

        let plan = CalendarAwareScheduleEngine.sequentialPlan(
            for: candidates,
            busyBlocks: dashboardBusyBlocks,
            referenceDate: Date(),
            energyLevel: energyReader.energyLevel
        )
        let fitCount = plan.blocks.count
        let moveCount = plan.unscheduledTitles.count
        let fitLabel = "\(fitCount) task\(fitCount == 1 ? "" : "s") fit today"
        let moveLabel = moveCount == 0 ? "calendar-aware" : "\(moveCount) should move"
        let rescueLabel = overdueTasks.isEmpty ? nil : "\(overdueTasks.count) overdue"
        let detail = [moveLabel, rescueLabel].compactMap(\.self).joined(separator: " • ")

        return BetaFocusedDashboardPlanPreviewModel(
            summary: fitLabel,
            detail: detail,
            rescueCount: overdueTasks.count,
            busyBlockCount: dashboardBusyBlocks.count
        )
    }

    private var staleInboxItems: [InboxItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return inboxItems.filter { $0.createdAt < cutoff }
    }

    private var oldestInboxLine: String? {
        guard let oldest = inboxItems.min(by: { $0.createdAt < $1.createdAt }) else {
            return nil
        }

        let ageDays = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: oldest.createdAt),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0

        guard ageDays >= 1 else { return nil }
        return ageDays == 1 ? "Oldest capture is 1 day old" : "Oldest capture is \(ageDays) days old"
    }

    private func recomputeDerivedTasks() {
        let calendar = Calendar.current
        let dueToday = openTasks.filter { calendar.isDateInToday($0.dueDate) }
        let sortedDueToday = dueToday.sorted { $0.dueDate < $1.dueDate }

        dueTodayTasks = sortedDueToday
        overdueTasks = openTasks.filter(\.isOverdue)
        focusTasks = sortedDueToday + todayCompletedTasks
    }

    private func refreshTotalCompletedCount() {
        let descriptor = FetchDescriptor<LifeTask>(
            predicate: #Predicate { $0.deletedAt == nil && $0.isCompleted }
        )
        totalCompletedCount = (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let phase: String

        switch hour {
        case 0..<12:
            phase = "Good morning"
        case 12..<17:
            phase = "Good afternoon"
        default:
            phase = "Good evening"
        }

        let trimmedName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? phase : "\(phase), \(trimmedName)"
    }

    private var dateLabel: String {
        Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                BetaFocusedDashboardBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 13) {
                        header
                        todaySummaryCard
                        dailyFocusSection
                        inboxSection
                        toolsSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom) {
                BetaFocusedDashboardTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 0)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: BetaFocusedDashboardRoute.self) { route in
                switch route {
                case .tools:
                    BetaFocusedDashboardToolsView(
                        dueTodayCount: dueTodayTasks.count,
                        overdueCount: overdueTasks.count,
                        inboxCount: inboxItems.count,
                        planPreview: planPreview,
                        staleInboxCount: staleInboxItems.count,
                        oldestInboxLine: oldestInboxLine,
                        onNavigate: navigate,
                        onOpenPlanMyDay: presentDailyRitual,
                        onOpenOverdueRescue: { isShowingOverdueRescue = true },
                        onOpenSettings: { isShowingSettings = true },
                        onOpenCategories: { isShowingCategoryManager = true },
                        onOpenInbox: openInbox
                    )
                case .statistics:
                    StatisticsView(tasks: fetchAllTasksForLookup())
                case .calendar:
                    TaskCalendarView(
                        tasks: openTasks,
                        customCategories: customCategories,
                        focusAvailabilityOnAppear: false,
                        initialAvailabilityRange: .today,
                        onToggleCompletion: toggleCompletion,
                        onEdit: { editingTask = $0 },
                        onDelete: { _ in }
                    )
                case .documents:
                    DocumentSearchView()
                case .taskData:
                    TaskDataExchangeView()
                case .money:
                    MoneyOverviewView()
                case .bin:
                    TaskBinView()
                case .weeklyReview:
                    WeeklyReviewView(tasks: fetchAllTasksForLookup(), customCategories: customCategories)
                case .backup:
                    CloudBackupView()
                case .aiSuggestions:
                    AITaskSuggestionsView(tasks: fetchAllTasksForLookup())
                }
            }
            .onChange(of: selectedTab) { _, tab in
                guard tab != .home else { return }
                DispatchQueue.main.async {
                    handleTabSelection(tab)
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $isShowingQuickCapture, onDismiss: refreshInboxItems) {
            QuickCaptureView(
                onOpenEditor: openCapturedDraftInEditor,
                onOpenVoiceCapture: openVoiceCapture,
                onOpenQuickAdd: nil
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingVoiceCapture, onDismiss: refreshInboxItems) {
            VoiceCaptureView(onOpenEditor: openCapturedDraftInEditor)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingInbox, onDismiss: refreshInboxItems) {
            InboxView(
                onOpenEditor: openCapturedDraftInEditor,
                onOpenTextCapture: openQuickCapture,
                onOpenVoiceCapture: openVoiceCapture
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingDailyRitual) {
            DailyPlanningRitualView(
                tasks: openTasks,
                customCategories: customCategories,
                onToggleCompletion: toggleCompletion,
                onReschedule: { task, date in
                    task.dueDate = date
                    task.updatedAt = Date()
                    try? modelContext.save()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingOverdueRescue, onDismiss: {
            recomputeDerivedTasks()
            refreshTotalCompletedCount()
        }) {
            BetaFocusedDashboardOverdueRescueSheet(
                tasks: overdueTasks,
                customCategories: customCategories,
                onOpenTask: openTaskFromRescue,
                onReschedule: { rescueReschedule($0, daysFromNow: 1, hour: 10) },
                onSnooze: { rescueReschedule($0, daysFromNow: 3, hour: 14) },
                onSomeday: rescueMoveToSomeday,
                onComplete: toggleCompletion,
                onDelete: rescueDelete
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingTaskEditor, onDismiss: {
            selectedCaptureDraft = nil
        }) {
            NewTaskView(captureDraft: selectedCaptureDraft)
        }
        .sheet(item: $editingTask) { task in
            NewTaskView(task: task)
        }
        .sheet(isPresented: $isShowingCategoryManager) {
            CategoryManagerView { _ in }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(requiredTier: .standard, featureName: "Plan My Day")
                .environmentObject(subscriptionManager)
        }
        .fullScreenCover(item: $dayCompleteSummary) { summary in
            DayCompleteCelebrationView(
                summary: summary,
                nickname: nickname,
                onDismiss: { dayCompleteSummary = nil }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: TaskSpotlightIndexer.openTaskNotification)) { note in
            guard let id = note.userInfo?[TaskSpotlightIndexer.openTaskUserInfoKey] as? UUID,
                  let match = fetchTaskByID(id)
            else {
                return
            }

            editingTask = match
        }
        .onAppear {
            refreshInboxItems()
            recomputeDerivedTasks()
            refreshTotalCompletedCount()
            loadDashboardPlanningContext()
            if scenePhase == .active {
                openPendingNotificationTaskIfNeeded()
                drainSharedInbox()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else {
                return
            }

            refreshInboxItems()
            recomputeDerivedTasks()
            refreshTotalCompletedCount()
            loadDashboardPlanningContext()
            openPendingNotificationTaskIfNeeded()
            drainSharedInbox()
        }
        .onChange(of: openTasks) { _, _ in
            recomputeDerivedTasks()
            loadDashboardPlanningContext()
        }
        .onChange(of: todayCompletedTasks) { _, _ in
            recomputeDerivedTasks()
            refreshTotalCompletedCount()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(BetaFocusedDashboardTypography.greeting)
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.46)
                    .layoutPriority(1)

                Text(dateLabel)
                    .font(BetaFocusedDashboardTypography.date)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button {
                    navigate(to: .statistics)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Stats")
                            .font(BetaFocusedDashboardTypography.button)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(BetaFocusedDashboardPalette.statsPillText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minWidth: 78)
                    .background(BetaFocusedDashboardPalette.statsPillBackground, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    isShowingSettings = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatarView(size: 48, avatarVersion: avatarVersion)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(BetaFocusedDashboardPalette.statsPillText)
                            .frame(width: 19, height: 19)
                            .background(Color.white, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
                            }
                            .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var todaySummaryCard: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardBackground) {
            ZStack(alignment: .topTrailing) {
                BetaFocusedDashboardSunBackdrop()
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Today")
                        .font(BetaFocusedDashboardTypography.heroTitle)
                        .foregroundStyle(BetaFocusedDashboardPalette.heroAccent)

                    HStack(spacing: 0) {
                        BetaFocusedDashboardMetricColumn(
                            symbolName: "calendar",
                            tint: BetaFocusedDashboardPalette.dueTodayTint,
                            value: dueTodayTasks.count,
                            label: "Due Today"
                        )

                        BetaFocusedDashboardVerticalRule()

                        Button {
                            guard !overdueTasks.isEmpty else { return }
                            isShowingOverdueRescue = true
                        } label: {
                            BetaFocusedDashboardMetricColumn(
                                symbolName: "exclamationmark.circle",
                                tint: BetaFocusedDashboardPalette.overdueTint,
                                value: overdueTasks.count,
                                label: "Overdue"
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(overdueTasks.isEmpty)
                        .accessibilityHint(overdueTasks.isEmpty ? "No overdue tasks" : "Open overdue rescue")

                        BetaFocusedDashboardVerticalRule()

                        BetaFocusedDashboardMetricColumn(
                            symbolName: "checkmark.circle",
                            tint: BetaFocusedDashboardPalette.completedTint,
                            value: totalCompletedCount,
                            label: "Completed"
                        )
                    }

                    BetaFocusedDashboardPlanPreview(
                        preview: planPreview,
                        onRescue: overdueTasks.isEmpty ? nil : { isShowingOverdueRescue = true }
                    )

                    Button {
                        presentDailyRitual()
                    } label: {
                        HStack {
                            Spacer(minLength: 0)
                            Text("Plan My Day")
                                .font(BetaFocusedDashboardTypography.button)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [
                                    BetaFocusedDashboardPalette.heroAccent,
                                    BetaFocusedDashboardPalette.heroAccentDeep
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: BetaFocusedDashboardPalette.heroAccent.opacity(0.16), radius: 14, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dailyFocusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Focus")
                    .font(BetaFocusedDashboardTypography.section)
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(todayProgressLabel)
                        .font(BetaFocusedDashboardTypography.body)
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(BetaFocusedDashboardPalette.border.opacity(0.45))

                            Capsule()
                                .fill(BetaFocusedDashboardPalette.progressTint)
                                .frame(width: max(proxy.size.width * CGFloat(todayProgressValue), todayProgressValue == 0 ? 0 : 18))
                        }
                    }
                    .frame(width: 88, height: 5)
                }
            }

            BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
                if focusTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your day is clear.")
                            .font(.system(size: 18, weight: .medium, design: .default))
                            .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                        Text("Capture something new or run Plan My Day to build a focused list.")
                            .font(BetaFocusedDashboardTypography.bodySmall)
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            BetaFocusedDashboardActionChip(
                                title: "Text Capture",
                                systemImage: "bubble.left.and.text.bubble.right",
                                tint: BetaFocusedDashboardPalette.captureTint
                            ) {
                                openQuickCapture()
                            }

                            BetaFocusedDashboardActionChip(
                                title: "Plan My Day",
                                systemImage: "calendar.badge.clock",
                                tint: BetaFocusedDashboardPalette.heroAccent
                            ) {
                                presentDailyRitual()
                            }
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        if let nextBestRecommendation {
                            let option = nextBestRecommendation.task.categoryOption(customCategories: customCategories)
                            BetaFocusedDashboardStartHereBand(
                                recommendation: nextBestRecommendation,
                                categoryOption: option,
                                visuals: categoryVisuals(for: option),
                                scheduledBlock: nextBestScheduledBlock,
                                healthState: nextBestRecommendation.task.betaFocusedHealthState(),
                                onOpen: { editingTask = nextBestRecommendation.task },
                                onComplete: { toggleCompletion(nextBestRecommendation.task) }
                            )
                        }

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(focusListTasks.enumerated()), id: \.element.id) { index, task in
                                    let option = task.categoryOption(customCategories: customCategories)
                                    BetaFocusedDashboardTaskRow(
                                        task: task,
                                        categoryOption: option,
                                        visuals: categoryVisuals(for: option),
                                        healthState: task.betaFocusedHealthState(),
                                        onOpen: { editingTask = task },
                                        onToggleCompletion: { toggleCompletion(task) }
                                    )

                                    if index < focusListTasks.count - 1 {
                                        Divider()
                                            .overlay(BetaFocusedDashboardPalette.border)
                                            .padding(.leading, 56)
                                    }
                                }
                                .padding(.bottom, 2)
                            }
                        }
                        .scrollIndicators(hiddenFocusTaskCount > 0 ? .visible : .hidden)
                        .frame(height: focusListHeight)

                        if hiddenFocusTaskCount > 0 {
                            HStack(spacing: 6) {
                                Text("Scroll for \(hiddenFocusTaskCount) more")
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                            .foregroundStyle(BetaFocusedDashboardPalette.heroAccent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }

    private var inboxSection: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    openInbox()
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(BetaFocusedDashboardPalette.financeBackground)
                            .frame(width: 38, height: 38)
                            .overlay {
                                Image(systemName: "tray.full")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(BetaFocusedDashboardPalette.captureTint)
                            }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 7) {
                                Text("Inbox")
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                                    .lineLimit(1)

                                if !staleInboxItems.isEmpty {
                                    BetaFocusedDashboardTinyBadge(
                                        title: "\(staleInboxItems.count) old",
                                        tint: BetaFocusedDashboardPalette.warningTint,
                                        background: BetaFocusedDashboardPalette.warningBackground
                                    )
                                }
                            }

                            Text(inboxItems.isEmpty ? "Nothing waiting" : "\(inboxItems.count) waiting")
                                .font(BetaFocusedDashboardTypography.body)
                                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    if inboxItems.isEmpty {
                        BetaFocusedDashboardActionChip(
                            title: "Text Capture",
                            systemImage: "bubble.left.and.text.bubble.right",
                            tint: BetaFocusedDashboardPalette.captureTint,
                            isCompact: true
                        ) {
                            openQuickCapture()
                        }

                        BetaFocusedDashboardActionChip(
                            title: "Voice Capture",
                            systemImage: "waveform",
                            tint: BetaFocusedDashboardPalette.captureTint,
                            isCompact: true
                        ) {
                            openVoiceCapture()
                        }
                    } else {
                        BetaFocusedDashboardActionChip(
                            title: "Review Newest",
                            systemImage: "arrow.up.doc",
                            tint: BetaFocusedDashboardPalette.captureTint,
                            isCompact: true
                        ) {
                            reviewNewestInboxItem()
                        }

                        BetaFocusedDashboardActionChip(
                            title: "Process All",
                            systemImage: "checklist",
                            tint: BetaFocusedDashboardPalette.completedTint,
                            isCompact: true
                        ) {
                            openInbox()
                        }
                    }
                }

                if let oldestInboxLine {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text(oldestInboxLine)
                            .font(BetaFocusedDashboardTypography.bodySmall)
                    }
                    .foregroundStyle(BetaFocusedDashboardPalette.warningTint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var toolsSection: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tools")
                        .font(BetaFocusedDashboardTypography.section)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                    Spacer(minLength: 0)

                    Text("Quick access to essentials")
                        .font(BetaFocusedDashboardTypography.bodySmall)
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        BetaFocusedDashboardToolTile(
                            title: "Calendar",
                            systemImage: "calendar",
                            tint: BetaFocusedDashboardPalette.captureTint
                        ) {
                            navigate(to: .calendar)
                        }

                        BetaFocusedDashboardToolTile(
                            title: "Documents",
                            systemImage: "doc.text",
                            tint: BetaFocusedDashboardPalette.workTint
                        ) {
                            navigate(to: .documents)
                        }

                        BetaFocusedDashboardToolTile(
                            title: "Money",
                            systemImage: "dollarsign.circle",
                            tint: BetaFocusedDashboardPalette.homeTint
                        ) {
                            navigate(to: .money)
                        }

                        BetaFocusedDashboardToolTile(
                            title: "Import / Export",
                            systemImage: "arrow.up.arrow.down",
                            tint: BetaFocusedDashboardPalette.importExportTint
                        ) {
                            navigate(to: .taskData)
                        }

                        BetaFocusedDashboardToolTile(
                            title: "Settings",
                            systemImage: "gearshape",
                            tint: BetaFocusedDashboardPalette.statsPillText
                        ) {
                            isShowingSettings = true
                        }

                        BetaFocusedDashboardToolTile(
                            title: "Bin",
                            systemImage: "trash",
                            tint: BetaFocusedDashboardPalette.overdueTint
                        ) {
                            navigate(to: .bin)
                        }

                        BetaFocusedDashboardToolTile(
                            title: "Categories",
                            systemImage: "tag",
                            tint: BetaFocusedDashboardPalette.personalTint
                        ) {
                            isShowingCategoryManager = true
                        }

                        BetaFocusedDashboardToolTile(
                            title: "Weekly Review",
                            systemImage: "calendar.badge.clock",
                            tint: BetaFocusedDashboardPalette.completedTint
                        ) {
                            navigate(to: .weeklyReview)
                        }

                        BetaFocusedDashboardToolTile(
                            title: "Backup",
                            systemImage: "icloud",
                            tint: BetaFocusedDashboardPalette.financeTint
                        ) {
                            navigate(to: .backup)
                        }

                        BetaFocusedDashboardToolTile(
                            title: "AI Suggestions",
                            systemImage: "sparkles",
                            tint: BetaFocusedDashboardPalette.warningTint
                        ) {
                            navigate(to: .aiSuggestions)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func handleTabSelection(_ tab: BetaFocusedDashboardTab) {
        switch tab {
        case .home:
            break
        case .capture:
            openQuickCapture()
            resetTabSelection()
        case .focus:
            presentDailyRitual()
            resetTabSelection()
        case .tools:
            navigate(to: .tools)
            resetTabSelection()
        }
    }

    private func resetTabSelection() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            selectedTab = .home
        }
    }

    private func navigate(to route: BetaFocusedDashboardRoute) {
        DispatchQueue.main.async {
            navigationPath.append(route)
        }
    }

    private func presentDailyRitual() {
        guard subscriptionManager.tier >= .standard else {
            isShowingPaywall = true
            return
        }

        isShowingDailyRitual = true
    }

    private func loadDashboardPlanningContext() {
        let interval = dashboardPlanningInterval
        Task { @MainActor in
            await calendarManager.loadBusyBlocks(in: interval)
        }
    }

    private func openQuickCapture() {
        selectedCaptureDraft = nil
        isShowingVoiceCapture = false
        isShowingInbox = false
        isShowingQuickCapture = true
    }

    private func openVoiceCapture() {
        selectedCaptureDraft = nil
        isShowingQuickCapture = false
        isShowingInbox = false
        isShowingVoiceCapture = true
    }

    private func openInbox() {
        selectedCaptureDraft = nil
        isShowingQuickCapture = false
        isShowingVoiceCapture = false
        refreshInboxItems()
        isShowingInbox = true
    }

    private func reviewNewestInboxItem() {
        guard let newest = inboxItems.sorted(by: { $0.createdAt > $1.createdAt }).first else {
            openInbox()
            return
        }

        openCapturedDraftInEditor(newest.captureDraft)
    }

    private func openCapturedDraftInEditor(_ draft: CapturedTaskDraft) {
        selectedCaptureDraft = draft
        isShowingQuickCapture = false
        isShowingVoiceCapture = false
        isShowingInbox = false
        isShowingTaskEditor = true
    }

    private func openPendingNotificationTaskIfNeeded() {
        guard let task = LifeTrackNotificationActionHandler.consumePendingOpenTask(in: fetchAllTasksForLookup()) else {
            return
        }

        selectedCaptureDraft = nil
        isShowingQuickCapture = false
        isShowingVoiceCapture = false
        isShowingTaskEditor = false
        editingTask = task
    }

    private func fetchAllTasksForLookup() -> [LifeTask] {
        let descriptor = FetchDescriptor<LifeTask>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchTaskByID(_ id: UUID) -> LifeTask? {
        var descriptor = FetchDescriptor<LifeTask>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func refreshInboxItems() {
        inboxItems = InboxStore.loadOpenItems()
    }

    private func drainSharedInbox() {
        let context = modelContext
        Task { @MainActor in
            await SharedInboxImporter.drain(context: context)
            refreshInboxItems()
        }
    }

    private func toggleCompletion(_ task: LifeTask) {
        let wasCompleted = task.isCompleted
        let pending = withAnimation(.snappy(duration: 0.24)) {
            TaskLifecycleManager.beginToggleCompletion(for: task)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            TaskLifecycleManager.finishToggleCompletion(pending, in: modelContext, customCategories: customCategories)
            FocusActivityController.shared.update(for: task)

            if !wasCompleted {
                try? await Task.sleep(nanoseconds: 320_000_000)
                presentDayCompleteCelebrationIfNeeded()
            }
        }
    }

    private func openTaskFromRescue(_ task: LifeTask) {
        isShowingOverdueRescue = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            editingTask = task
        }
    }

    private func rescueReschedule(_ task: LifeTask, daysFromNow: Int, hour: Int) {
        let calendar = Calendar.current
        let targetDay = calendar.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        let targetDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: targetDay) ?? targetDay
        task.dueDate = targetDate
        task.updatedAt = Date()
        try? modelContext.save()
        TaskLifecycleManager.synchronizeReminder(for: task, customCategories: customCategories)
        recomputeDerivedTasks()
    }

    private func rescueMoveToSomeday(_ task: LifeTask) {
        let calendar = Calendar.current
        let targetDay = calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let targetDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: targetDay) ?? targetDay
        task.dueDate = targetDate
        task.priority = .low
        task.updatedAt = Date()
        try? modelContext.save()
        TaskLifecycleManager.synchronizeReminder(for: task, customCategories: customCategories)
        recomputeDerivedTasks()
    }

    private func rescueDelete(_ task: LifeTask) {
        TaskLifecycleManager.delete(task, in: modelContext)
        recomputeDerivedTasks()
    }

    private func presentDayCompleteCelebrationIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayKey = ISO8601DateFormatter.string(from: today, timeZone: .current, formatOptions: [.withFullDate])

        guard lastCelebrationDayKey != todayKey else { return }
        guard !todayCompletedTasks.isEmpty else { return }
        guard openTasks.allSatisfy({ !calendar.isDateInToday($0.dueDate) }) else { return }

        let entries = todayCompletedTasks
            .map { task in
                DayCompleteSummary.Entry(
                    id: task.id,
                    title: task.title,
                    completedAt: task.completedAt ?? task.updatedAt,
                    category: task.categoryOption(customCategories: customCategories)
                )
            }
            .sorted { $0.completedAt < $1.completedAt }

        lastCelebrationDayKey = todayKey
        dayCompleteSummary = DayCompleteSummary(date: today, entries: entries)
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
