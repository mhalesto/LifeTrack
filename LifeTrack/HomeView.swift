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
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && !$0.isCompleted }, sort: \LifeTask.dueDate, order: .forward) private var openTasks: [LifeTask]
    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && $0.isCompleted }, sort: \LifeTask.dueDate, order: .reverse) private var completedTasks: [LifeTask]
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    @State private var isShowingTemplatePicker = false
    @State private var isShowingLogMoney = false
    @State private var isShowingTaskEditor = false
    @State private var isShowingQuickCapture = false
    @State private var isShowingVoiceCapture = false
    @State private var isShowingInbox = false
    @State private var shouldAutoStartVoice = false
    @State private var isShowingSettings = false
    @State private var isShowingAvailabilitySheet = false
    @State private var navigationPath: [HomeRoute] = []
    @State private var selectedTemplate: TaskTemplate?
    @State private var selectedCaptureDraft: CapturedTaskDraft?
    @State private var editingTask: LifeTask?
    @State private var selectedSummary: DashboardSummaryKind?
    @State private var pendingReopenTask: LifeTask?
    @State private var binUndoState: TaskBinUndoState?
    @State private var restoredToastState: TaskRestoredToastState?
    @State private var reminderActionTipState: ReminderActionTipToastState?
    @State private var availabilityShareRange: AvailabilityShareRange = .today
    @State private var dashboardMessageSeed = Int.random(in: 0...1_000_000)
    @State private var dashboardMessageSignal: DashboardMessageSignal?
    @State private var hasHandledInitialActivePhase = false
    @State private var isShowingDailyRitual = false
    @State private var isShowingHabits = false
    @State private var isShowingWeeklyReview = false
    @State private var isShowingAISuggestions = false
    @State private var isShowingSmartScheduling = false
    @State private var streakCelebration: String?
    @State private var hasQueuedStartupMaintenance = false
    @State private var cachedFocus: [DailyFocusRecommendation] = []
    @State private var cachedFocusGroups: [DailyFocusRecommendationGroup] = []
    @State private var cachedDocumentTasks: [LifeTask] = []
    @State private var cachedDocumentReminders: [LifeTask] = []
    @State private var inboxItems: [InboxItem] = InboxStore.loadOpenItems()
    @State private var cachedDueTodayCount = 0
    @State private var cachedUpcomingCount = 0
    @State private var cachedOverdueCount = 0
    @State private var cachedCompletedCount = 0
    @AppStorage(LifeTrackSettings.Keys.nickname) private var nickname = ""
    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.avatarVersion) private var avatarVersion = 0
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(LifeTrackSettings.Keys.binRetentionPeriod) private var binRetentionRawValue = TaskBinRetentionPeriod.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.lastDashboardMessageText) private var lastDashboardMessageText = ""
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var isShowingPaywall = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    let metrics = HomeLayoutMetrics(
                        availableHeight: proxy.size.height,
                        priorityCount: priorityTasks.count,
                        documentCount: documentTasks.count,
                        isEmpty: isActiveTasksEmpty
                    )

                    ScrollView {
                        dashboardContent(metrics: metrics)
                    }
                    .scrollIndicators(.hidden)
                }

                PrimaryFloatingButton(accessibilityLabel: "Quick capture") {
                    openQuickCapture()
                }
                .padding(.trailing, LifeTrackTheme.Spacing.xLarge)
                .padding(.bottom, LifeTrackTheme.Spacing.xLarge)

            }
            .overlay {
                if let pendingReopenTask {
                    LifeTrackConfirmationOverlay(
                        symbolName: "arrow.uturn.left.circle.fill",
                        title: "Move back to in progress?",
                        message: "\"\(pendingReopenTask.title)\" is already completed. Reopening it will return the task to your active lists and may schedule a reminder again.",
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
                    .padding(.bottom, 76)
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
                    .padding(.bottom, 76)
                    .task(id: restoredToastState.id) {
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        await MainActor.run {
                            dismissRestoredToast(id: restoredToastState.id)
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let celebration = streakCelebration {
                    StreakCelebrationBanner(message: celebration) {
                        streakCelebration = nil
                    }
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: celebration) {
                        try? await Task.sleep(nanoseconds: 2_800_000_000)
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.3)) { streakCelebration = nil }
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let reminderActionTipState {
                    ReminderActionTipToast {
                        dismissReminderActionTip(id: reminderActionTipState.id)
                    }
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .task(id: reminderActionTipState.id) {
                        try? await Task.sleep(nanoseconds: 6_000_000_000)
                        await MainActor.run {
                            dismissReminderActionTip(id: reminderActionTipState.id)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .statistics:
                    StatisticsView(tasks: activeTasks)
                case .calendar:
                    TaskCalendarView(
                        tasks: activeTasks,
                        customCategories: customCategories,
                        focusAvailabilityOnAppear: false,
                        initialAvailabilityRange: .today,
                        onToggleCompletion: toggleCompletion,
                        onEdit: openTaskFromCalendar,
                        onDelete: delete
                    )
                case .availabilityCalendar:
                    TaskCalendarView(
                        tasks: activeTasks,
                        customCategories: customCategories,
                        focusAvailabilityOnAppear: true,
                        initialAvailabilityRange: availabilityShareRange,
                        onToggleCompletion: toggleCompletion,
                        onEdit: openTaskFromCalendar,
                        onDelete: delete
                    )
                case .documents:
                    DocumentSearchView()
                case .taskData(let mode):
                    TaskDataExchangeView(initialMode: mode)
                case .money:
                    MoneyOverviewView()
                }
            }
            .sheet(isPresented: $isShowingTemplatePicker) {
                TemplatePickerView(
                    onSelectBlank: openBlankTaskFromPicker,
                    onSelectVoice: openVoiceTaskFromPicker,
                    onSelectLogMoney: openLogMoneyFromPicker,
                    onSelectTemplate: openTemplateFromPicker
                )
            }
            .sheet(isPresented: $isShowingLogMoney) {
                LogMoneyView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $isShowingAvailabilitySheet) {
                AvailabilityShareSheet(
                    selectedRange: $availabilityShareRange,
                    tasks: activeTasks,
                    customCategories: customCategories,
                    onOpenCalendar: openAvailabilityCalendar
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedSummary) { summary in
                DashboardSummarySheet(
                    summary: summary,
                    tasks: tasks(for: summary),
                    customCategories: customCategories,
                    onToggleCompletion: toggleCompletion,
                    onEdit: openTaskFromSummary,
                    onDelete: delete,
                    onCreateTask: openBlankTaskFromSummary
                )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingQuickCapture, onDismiss: refreshInboxItems) {
                QuickCaptureView(
                    onOpenEditor: openCapturedDraftInEditor,
                    onOpenVoiceCapture: openVoiceCapture
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
            .sheet(isPresented: $isShowingTaskEditor, onDismiss: {
                shouldAutoStartVoice = false
                selectedCaptureDraft = nil
            }) {
                NewTaskView(
                    template: selectedTemplate,
                    captureDraft: selectedCaptureDraft,
                    autoStartVoice: shouldAutoStartVoice
                )
            }
            .sheet(isPresented: $isShowingHabits) {
                HabitTrackerView(
                    tasks: activeTasks,
                    customCategories: customCategories,
                    onToggleCompletion: toggleCompletionWithStreak
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingWeeklyReview) {
                WeeklyReviewView(
                    tasks: activeTasks,
                    customCategories: customCategories
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $isShowingAISuggestions) {
                AITaskSuggestionsView(tasks: activeTasks)
            }
            .sheet(isPresented: $isShowingSmartScheduling) {
                SmartSchedulingOptimizerView(tasks: activeTasks)
            }
            .sheet(isPresented: $isShowingDailyRitual) {
                DailyPlanningRitualView(
                    tasks: activeTasks,
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
            .sheet(item: $editingTask) { task in
                NewTaskView(task: task)
            }
            .onReceive(NotificationCenter.default.publisher(for: TaskSpotlightIndexer.openTaskNotification)) { note in
                guard let id = note.userInfo?[TaskSpotlightIndexer.openTaskUserInfoKey] as? UUID,
                      let match = (openTasks + completedTasks).first(where: { $0.id == id })
                else { return }
                editingTask = match
            }
        }
        .tint(selectedTheme.accent)
        .onAppear {
            refreshInboxItems()
            refreshDerivedCaches()
            queueStartupMaintenanceIfNeeded()
            LocationReminderManager.shared.restoreAllRegions(from: activeTasks)
            if scenePhase == .active {
                hasHandledInitialActivePhase = true
            }
            refreshDashboardMessage(rotateSeed: false)
            openPendingNotificationTaskIfNeeded()
            showPendingReminderActionTipIfNeeded()
            drainSharedInbox()
        }
        .onChange(of: openTasks.count) { _, _ in
            refreshDerivedCaches()
        }
        .onChange(of: completedTasks.count) { _, _ in
            refreshDerivedCaches()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else {
                return
            }

            refreshDerivedCaches()
            refreshInboxItems()
            if hasHandledInitialActivePhase {
                refreshDashboardMessage(rotateSeed: true)
            } else {
                hasHandledInitialActivePhase = true
            }
            openPendingNotificationTaskIfNeeded()
            showPendingReminderActionTipIfNeeded()
            drainSharedInbox()
            checkPendingVoiceLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: ReminderScheduler.actionTipDidBecomePendingNotification)) { _ in
            showPendingReminderActionTipIfNeeded()
        }
        .onChange(of: dashboardMessageContextKey) { _, _ in
            refreshDashboardMessage(rotateSeed: false)
        }
        .onChange(of: binRetentionRawValue) { _, _ in
            purgeExpiredBinItems()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                    Text(Date().weekdayDateString)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                }

                Spacer()

                Button {
                    navigationPath.append(.statistics)
                } label: {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                        .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.82), lineWidth: 1)
                        }
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.94, pressedOpacity: 0.96))
                .accessibilityLabel("Open statistics")

                ProfileAvatarButton(avatarVersion: avatarVersion) {
                    isShowingSettings = true
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LifeTrackTheme.ColorPalette.accentGradient)
                        .frame(width: 8, height: 30)

                    Text("LifeTrack")
                        .font(.lifeTrack(.title, weight: .bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                }

                DashboardHeaderMessageView(message: dashboardMessage)
            }
        }
    }

    private func dashboardContent(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            header

            progressSection

            inboxSection

            summaryGrid(metrics: metrics)

            quickActions(metrics: metrics)

            if isActiveTasksEmpty {
                EmptyStateView(
                    title: "Start with one clear next step",
                    message: "Create a task, attach important files, and LifeTrack will keep the dashboard useful from day one.",
                    actionTitle: "Create Task",
                    action: openBlankTask
                )
            } else {
                prioritySection(metrics: metrics)
                documentRemindersSection(metrics: metrics)
                recentDocumentsSection(metrics: metrics)
            }
        }
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .padding(.top, LifeTrackTheme.Spacing.medium)
        .padding(.bottom, metrics.bottomPadding)
    }

    private func summaryGrid(metrics: HomeLayoutMetrics) -> some View {
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
                        showsDisclosure: true,
                        minHeight: metrics.statCardHeight,
                        iconSize: metrics.statIconSize,
                        valueFontSize: metrics.statValueFontSize,
                        cardPadding: metrics.statCardPadding
                    )
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
                .accessibilityLabel("View \(summary.title) tasks")
            }
        }
    }

    private var progressSection: some View {
        ProgressTrackerView(metrics: TaskProgressMetrics.build(from: activeTasks))
    }

    private var inboxSection: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Inbox",
                trailing: inboxItems.isEmpty ? "Clear" : "\(inboxItems.count) open",
                infoMessage: "Use inbox for rough capture first. Convert items into full tasks only when you are ready to classify or schedule them."
            )

            if inboxItems.isEmpty {
                Text("Capture something quickly and let LifeTrack hold the raw thought until you want to structure it.")
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    LifeTrackSecondaryButton(title: "Text Capture", systemImage: "square.and.pencil") {
                        openQuickCapture()
                    }

                    LifeTrackSecondaryButton(title: "Voice Capture", systemImage: "mic.fill") {
                        openVoiceCapture()
                    }
                }
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(Array(inboxItems.prefix(3))) { item in
                        Button {
                            isShowingInbox = true
                        } label: {
                            InboxDashboardPreviewRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if inboxItems.count > 3 {
                    Text("\(inboxItems.count - 3) more item\(inboxItems.count - 3 == 1 ? "" : "s") waiting in inbox.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                HStack(spacing: 10) {
                    LifeTrackSecondaryButton(title: "Open Inbox", systemImage: "tray.full") {
                        isShowingInbox = true
                    }

                    LifeTrackSecondaryButton(title: "Capture More", systemImage: "plus") {
                        openQuickCapture()
                    }
                }
            }
        }
    }

    private func quickActions(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            SectionHeaderView(
                title: "Quick Actions",
                infoMessage: "Move fast without losing structure. Capture to inbox, jump into a full task, or open your planning tools from here."
            )

            ScrollView(.horizontal) {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    if subscriptionManager.tier >= .standard {
                        QuickActionButton(
                            title: "Plan My Day",
                            subtitle: "Daily ritual",
                            symbolName: "sunrise.fill",
                            tint: Color(red: 0.95, green: 0.65, blue: 0.1),
                            width: metrics.quickActionWideWidth,
                            height: metrics.quickActionHeight,
                            iconSize: metrics.quickActionIconSize,
                            action: { isShowingDailyRitual = true }
                        )

                        QuickActionButton(
                            title: "Habits",
                            subtitle: "Streaks",
                            symbolName: "flame.fill",
                            tint: Color(red: 0.95, green: 0.35, blue: 0.15),
                            width: metrics.quickActionWidth,
                            height: metrics.quickActionHeight,
                            iconSize: metrics.quickActionIconSize,
                            action: { isShowingHabits = true }
                        )

                        QuickActionButton(
                            title: "Weekly Review",
                            subtitle: "Reflect & plan",
                            symbolName: "chart.bar.doc.horizontal.fill",
                            tint: Color(red: 0.35, green: 0.6, blue: 0.95),
                            width: metrics.quickActionWideWidth,
                            height: metrics.quickActionHeight,
                            iconSize: metrics.quickActionIconSize,
                            action: { isShowingWeeklyReview = true }
                        )

                        if subscriptionManager.tier >= .ultimate {
                            QuickActionButton(
                                title: "AI Suggestions",
                                subtitle: "Smart focus",
                                symbolName: "sparkles",
                                tint: Color(red: 0.95, green: 0.72, blue: 0.1),
                                width: metrics.quickActionWideWidth,
                                height: metrics.quickActionHeight,
                                iconSize: metrics.quickActionIconSize,
                                action: { isShowingAISuggestions = true }
                            )

                            QuickActionButton(
                                title: "Schedule",
                                subtitle: "Optimize day",
                                symbolName: "brain.head.profile",
                                tint: Color(red: 0.95, green: 0.72, blue: 0.1),
                                width: metrics.quickActionWideWidth,
                                height: metrics.quickActionHeight,
                                iconSize: metrics.quickActionIconSize,
                                action: { isShowingSmartScheduling = true }
                            )
                        }
                    }

                    QuickActionButton(
                        title: "Quick add",
                        subtitle: "Tasks & templates",
                        symbolName: "plus",
                        tint: LifeTrackTheme.ColorPalette.accent,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { isShowingTemplatePicker = true }
                    )

                    QuickActionButton(
                        title: "Inbox",
                        subtitle: inboxItems.isEmpty ? "Capture first" : "\(inboxItems.count) waiting",
                        symbolName: "tray.full",
                        tint: LifeTrackTheme.ColorPalette.secondaryAccent,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { isShowingInbox = true }
                    )

                    QuickActionButton(
                        title: "Voice capture",
                        subtitle: "Save or create",
                        symbolName: "mic.fill",
                        tint: Color(red: 0.95, green: 0.62, blue: 0.18),
                        width: metrics.quickActionWideWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: openVoiceCapture
                    )

                    QuickActionButton(
                        title: "Availability",
                        subtitle: "Share times",
                        symbolName: "calendar.badge.clock",
                        tint: LifeTrackTheme.ColorPalette.accent,
                        width: metrics.quickActionWideWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { isShowingAvailabilitySheet = true }
                    )

                    QuickActionButton(
                        title: "Email follow-up",
                        subtitle: "Use template",
                        symbolName: "envelope.badge",
                        tint: TaskCategory.work.style.tint,
                        width: metrics.quickActionWideWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { openTemplateShortcut(id: "email") }
                    )

                    QuickActionButton(
                        title: "Import",
                        subtitle: "From file",
                        symbolName: "tray.and.arrow.down",
                        tint: LifeTrackTheme.ColorPalette.accent,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { navigationPath.append(.taskData(.importTasks)) }
                    )

                    QuickActionButton(
                        title: "Export",
                        subtitle: "Share/AirDrop",
                        symbolName: "square.and.arrow.up",
                        tint: LifeTrackTheme.ColorPalette.success,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { navigationPath.append(.taskData(.exportTasks)) }
                    )

                    QuickActionButton(
                        title: "Pay bill",
                        subtitle: "Monthly",
                        symbolName: "creditcard",
                        tint: TaskCategory.finance.style.tint,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { openTemplateShortcut(id: "bill") }
                    )

                    QuickActionButton(
                        title: "Medication",
                        subtitle: "Daily routine",
                        symbolName: "cross.case",
                        tint: TaskCategory.health.style.tint,
                        width: metrics.quickActionWideWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { openTemplateShortcut(id: "medication") }
                    )

                    QuickActionButton(
                        title: "Money",
                        subtitle: "Budget & actuals",
                        symbolName: "chart.pie",
                        tint: TaskCategory.finance.style.tint,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { navigationPath.append(.money) }
                    )

                    QuickActionButton(
                        title: "Health check",
                        subtitle: "Book visit",
                        symbolName: "heart.text.square",
                        tint: TaskCategory.health.style.tint,
                        width: metrics.quickActionWideWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { openTemplateShortcut(id: "checkup") }
                    )

                    QuickActionButton(
                        title: "Calendar",
                        subtitle: "See dates",
                        symbolName: "calendar",
                        tint: LifeTrackTheme.ColorPalette.secondaryAccent,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { navigationPath.append(.calendar) }
                    )

                    QuickActionButton(
                        title: "Statistics",
                        subtitle: "See trends",
                        symbolName: "chart.bar.xaxis",
                        tint: LifeTrackTheme.ColorPalette.success,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { navigationPath.append(.statistics) }
                    )

                    QuickActionButton(
                        title: "Documents",
                        subtitle: "Search files",
                        symbolName: "doc.text.magnifyingglass",
                        tint: LifeTrackTheme.ColorPalette.warning,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { navigationPath.append(.documents) }
                    )

                    QuickActionButton(
                        title: "Templates",
                        subtitle: "Smart shortcuts",
                        symbolName: "sparkles",
                        tint: LifeTrackTheme.ColorPalette.secondaryAccent,
                        width: metrics.quickActionWidth,
                        height: metrics.quickActionHeight,
                        iconSize: metrics.quickActionIconSize,
                        action: { isShowingTemplatePicker = true }
                    )
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.visible)
        }
    }

    private func prioritySection(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            SectionHeaderView(
                title: "Daily Focus",
                trailing: "\(focusRecommendations.count)",
                infoMessage: "A local planner picks 3 to 5 tasks using due dates, overdue status, priority, routines, and document reminders."
            )

            if focusRecommendations.isEmpty {
                SectionCardView {
                    CompactMessageView(
                        symbolName: "checkmark.circle",
                        title: "No open focus tasks",
                        message: "Everything urgent is complete. Add a task when the next priority appears."
                    )
                }
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(focusRecommendationGroups) { group in
                        VStack(alignment: .leading, spacing: 7) {
                            DailyFocusReasonHeader(reason: group.reason, count: group.recommendations.count)

                            VStack(spacing: LifeTrackTheme.Spacing.small) {
                                ForEach(group.recommendations) { recommendation in
                                    DailyFocusTaskCard(
                                        recommendation: recommendation,
                                        categoryOption: recommendation.task.categoryOption(customCategories: customCategories),
                                        onToggleCompletion: { toggleCompletion(for: recommendation.task) },
                                        onEdit: { editingTask = recommendation.task },
                                        onDelete: { delete(recommendation.task) },
                                        verticalPadding: metrics.taskRowVerticalPadding,
                                        leadingIconSize: metrics.taskRowIconSize
                                    )
                                }
                            }
                        }
                    }

                    if shouldShowFocusActions {
                        HStack(spacing: LifeTrackTheme.Spacing.small) {
                            FocusPlanningButton(
                                title: "Reset My Day",
                                symbolName: "arrow.clockwise",
                                tint: LifeTrackTheme.ColorPalette.accent,
                                action: resetMyDay
                            )

                            FocusPlanningButton(
                                title: "Reschedule Overdue",
                                symbolName: "calendar.badge.clock",
                                tint: LifeTrackTheme.ColorPalette.warning,
                                action: rescheduleOverdueTasks
                            )
                        }
                    }
                }
                .animation(animationsEnabled ? .snappy(duration: 0.24) : nil, value: focusRecommendations.map(\.id))
            }
        }
    }

    private func documentRemindersSection(metrics: HomeLayoutMetrics) -> some View {
        Group {
            if !documentReminderTasks.isEmpty {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
                    SectionHeaderView(
                        title: "Document Reminders",
                        trailing: documentReminderTasks.count.formatted(),
                        infoMessage: "Document-based reminders are detected locally from uploaded files and stay linked to their tasks."
                    )

                    VStack(spacing: LifeTrackTheme.Spacing.small) {
                        ForEach(Array(documentReminderTasks.prefix(2))) { task in
                            NavigationLink {
                                TaskDetailView(task: task)
                            } label: {
                                DocumentReminderRow(
                                    task: task,
                                    categoryOption: task.categoryOption(customCategories: customCategories),
                                    verticalPadding: metrics.documentRowVerticalPadding,
                                    iconSize: metrics.documentRowIconSize
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func recentDocumentsSection(metrics: HomeLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            SectionHeaderView(
                title: "Recent Documents",
                trailing: documentTasks.isEmpty ? nil : "\(documentTasks.count)",
                infoMessage: "Files connected to your tasks. Recent attachments stay close so supporting documents are easy to reopen."
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
                            RecentDocumentRow(
                                task: task,
                                categoryOption: task.categoryOption(customCategories: customCategories),
                                verticalPadding: metrics.documentRowVerticalPadding,
                                iconSize: metrics.documentRowIconSize
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dueTodayTasks: [LifeTask] {
        openTasks.filter { Calendar.current.isDateInToday($0.dueDate) }
    }

    private var activeTasks: [LifeTask] {
        openTasks + completedTasks
    }

    private var isActiveTasksEmpty: Bool {
        openTasks.isEmpty && completedTasks.isEmpty
    }

    private var upcomingTasks: [LifeTask] {
        openTasks.filter { $0.dueDate > Date() && !Calendar.current.isDateInToday($0.dueDate) }
    }

    private var overdueTasks: [LifeTask] {
        openTasks.filter(\.isOverdue)
    }

    private var focusRecommendations: [DailyFocusRecommendation] {
        cachedFocus
    }

    private var focusRecommendationGroups: [DailyFocusRecommendationGroup] {
        cachedFocusGroups
    }

    private var priorityTasks: [LifeTask] {
        cachedFocus.map(\.task)
    }

    private var documentTasks: [LifeTask] {
        cachedDocumentTasks
    }

    private var documentReminderTasks: [LifeTask] {
        cachedDocumentReminders
    }

    private var shouldShowFocusActions: Bool {
        cachedOverdueCount > 0 || cachedDueTodayCount >= 5 || openTasks.count >= 12
    }

    private var dashboardMessage: DashboardMessageSignal {
        dashboardMessageSignal ?? makeDashboardMessage(seed: dashboardMessageSeed)
    }

    private var dashboardMessageContextKey: String {
        [
            openTasks.count + cachedCompletedCount,
            cachedDueTodayCount,
            cachedUpcomingCount,
            cachedCompletedCount,
            cachedOverdueCount
        ]
        .map(String.init)
        .joined(separator: "-")
    }

    private func makeDashboardMessage(seed: Int) -> DashboardMessageSignal {
        let source = dashboardMessageSource
        let messages = source.messages
        guard !messages.isEmpty else {
            return DashboardMessageSignal(text: "LifeTrack is ready when you are.", tone: .calm)
        }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let activeCount = openTasks.count + cachedCompletedCount
        let taskSignal = activeCount + (cachedDueTodayCount * 3) + (cachedUpcomingCount * 5) + (cachedCompletedCount * 7) + (cachedOverdueCount * 11)
        var index = (dayOfYear + taskSignal + seed) % messages.count

        if messages.count > 1 && messages[index] == lastDashboardMessageText {
            let offset = 1 + (seed % (messages.count - 1))
            index = (index + offset) % messages.count
        }

        return DashboardMessageSignal(
            text: messages[index],
            tone: source.tone
        )
    }

    private var dashboardMessageSource: DashboardMessageSource {
        let activeCount = openTasks.count + cachedCompletedCount

        if activeCount == 0 {
            return DashboardMessageSource(messages: emptyDashboardMessages, tone: .calm)
        }

        if cachedOverdueCount >= 3 {
            return DashboardMessageSource(messages: overdueDashboardMessages, tone: .overdue)
        }

        if cachedCompletedCount >= max(4, activeCount / 2) {
            return DashboardMessageSource(messages: completedDashboardMessages, tone: .completed)
        }

        if cachedDueTodayCount >= 4 {
            return DashboardMessageSource(messages: busyDashboardMessages, tone: .busy)
        }

        if cachedDueTodayCount == 0 && cachedOverdueCount == 0 {
            return DashboardMessageSource(messages: clearDayDashboardMessages, tone: .clear)
        }

        return DashboardMessageSource(messages: focusDashboardMessages, tone: .focus)
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

    private func refreshDashboardMessage(rotateSeed: Bool) {
        let seed = rotateSeed ? Int.random(in: 0...1_000_000) : dashboardMessageSeed
        dashboardMessageSeed = seed

        let message = makeDashboardMessage(seed: seed)
        performWithOptionalAnimation {
            dashboardMessageSignal = message
        }
        lastDashboardMessageText = message.text
    }

    private func openBlankTask() {
        selectedCaptureDraft = nil
        selectedTemplate = nil
        shouldAutoStartVoice = false
        isShowingTaskEditor = true
    }

    private func openTemplateShortcut(id: String) {
        selectedCaptureDraft = nil
        selectedTemplate = TaskTemplate.common.first { $0.id == id }
        shouldAutoStartVoice = false
        isShowingTaskEditor = true
    }

    private func openBlankTaskFromPicker() {
        selectedCaptureDraft = nil
        selectedTemplate = nil
        shouldAutoStartVoice = false
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func openLogMoneyFromPicker() {
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingLogMoney = true
        }
    }

    private func openVoiceTaskFromPicker() {
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            openVoiceCapture()
        }
    }

    private func openQuickCapture() {
        selectedTemplate = nil
        selectedCaptureDraft = nil
        shouldAutoStartVoice = false
        isShowingInbox = false
        isShowingVoiceCapture = false
        isShowingTemplatePicker = false
        isShowingQuickCapture = true
    }

    private func openVoiceCapture() {
        selectedTemplate = nil
        isShowingInbox = false
        isShowingQuickCapture = false
        selectedCaptureDraft = nil
        shouldAutoStartVoice = false
        isShowingVoiceCapture = true
    }

    private func openCapturedDraftInEditor(_ draft: CapturedTaskDraft) {
        selectedTemplate = nil
        selectedCaptureDraft = draft
        shouldAutoStartVoice = false
        isShowingQuickCapture = false
        isShowingVoiceCapture = false
        isShowingInbox = false
        isShowingTaskEditor = true
    }

    private func toggleCompletionWithStreak(for task: LifeTask) {
        let wasCompleted = task.isCompleted
        toggleCompletion(for: task)
        if !wasCompleted && task.isHabit && subscriptionManager.tier >= .standard {
            let streak = HabitEngine.currentStreak(for: task, in: activeTasks)
            if streak > 0 {
                withAnimation(.snappy) {
                    streakCelebration = streak == 1
                        ? "🔥 Habit started! Keep it up."
                        : "🔥 \(streak)-day streak! You're on fire."
                }
            }
        }
    }

    private func checkPendingVoiceLaunch() {
        let defaults = UserDefaults(suiteName: "group.com.currenttech.LifeTrack")

        if defaults?.bool(forKey: "pendingVoiceTaskLaunch") == true {
            defaults?.set(false, forKey: "pendingVoiceTaskLaunch")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                openVoiceCapture()
            }
            return
        }

        if defaults?.bool(forKey: "pendingBlankTaskLaunch") == true {
            defaults?.set(false, forKey: "pendingBlankTaskLaunch")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                openBlankTask()
            }
            return
        }

        if defaults?.bool(forKey: "pendingFocusLaunch") == true {
            defaults?.set(false, forKey: "pendingFocusLaunch")
            // Home dashboard already shows focus — bring app to foreground is enough
            return
        }

        if defaults?.bool(forKey: "pendingQuickComplete") == true {
            defaults?.set(false, forKey: "pendingQuickComplete")
            if let topTask = priorityTasks.first(where: { !$0.isCompleted }) {
                toggleCompletion(for: topTask)
            }
            return
        }
    }

    private func openTemplateFromPicker(_ template: TaskTemplate) {
        selectedCaptureDraft = nil
        selectedTemplate = template
        shouldAutoStartVoice = false
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func openBlankTaskFromSummary() {
        selectedSummary = nil
        selectedCaptureDraft = nil
        selectedTemplate = nil
        shouldAutoStartVoice = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func openTaskFromSummary(_ task: LifeTask) {
        selectedSummary = nil
        selectedCaptureDraft = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            editingTask = task
        }
    }

    private func openTaskFromCalendar(_ task: LifeTask) {
        selectedCaptureDraft = nil
        editingTask = task
    }

    private func openPendingNotificationTaskIfNeeded() {
        guard let task = LifeTrackNotificationActionHandler.consumePendingOpenTask(in: activeTasks) else {
            return
        }

        selectedSummary = nil
        isShowingTemplatePicker = false
        isShowingTaskEditor = false
        selectedCaptureDraft = nil
        editingTask = task
    }

    private func openAvailabilityCalendar() {
        isShowingAvailabilitySheet = false

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            navigationPath.append(.availabilityCalendar)
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
        guard !task.isCompleted else {
            pendingReopenTask = task
            return
        }

        let pending = TaskLifecycleManager.beginToggleCompletion(for: task)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            TaskLifecycleManager.finishToggleCompletion(
                pending,
                in: modelContext,
                customCategories: customCategories
            )
        }
    }

    private func delete(_ task: LifeTask) {
        performWithOptionalAnimation {
            let movedToBin = TaskLifecycleManager.delete(
                task,
                in: modelContext,
                retentionPeriod: binRetentionPeriod
            )

            if movedToBin {
                binUndoState = TaskBinUndoState(task: task)
            }
        }
    }

    private func confirmReopen(_ task: LifeTask) {
        pendingReopenTask = nil
        LifeTrackHaptics.lightImpact()
        performWithOptionalAnimation {
            TaskLifecycleManager.toggleCompletion(
                for: task,
                in: modelContext,
                customCategories: customCategories
            )
        }
    }

    private func restoreFromUndo(_ task: LifeTask) {
        let taskTitle = task.title
        dismissUndoToast(id: binUndoState?.id)
        LifeTrackHaptics.lightImpact()
        performWithOptionalAnimation {
            TaskLifecycleManager.restore(
                task,
                in: modelContext,
                customCategories: customCategories
            )
        }
        showRestoredToast(taskTitle: taskTitle)
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

    private func showPendingReminderActionTipIfNeeded() {
        guard
            reminderActionTipState == nil,
            ReminderScheduler.consumePendingActionTip()
        else {
            return
        }

        let tipState = ReminderActionTipToastState()

        guard animationsEnabled else {
            reminderActionTipState = tipState
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            reminderActionTipState = tipState
        }
    }

    private func dismissReminderActionTip(id: UUID?) {
        guard id == nil || reminderActionTipState?.id == id else {
            return
        }

        guard animationsEnabled else {
            reminderActionTipState = nil
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            reminderActionTipState = nil
        }
    }

    private func resetMyDay() {
        let focusIDs = Set(focusRecommendations.map(\.task.id))
        let plan = DailyFocusPlanner.resetSchedule(for: activeTasks, focusIDs: focusIDs)

        TaskLifecycleManager.applySchedule(
            plan,
            in: modelContext,
            customCategories: customCategories
        )
        refreshDerivedCaches()
    }

    private func rescheduleOverdueTasks() {
        let plan = DailyFocusPlanner.overdueReschedulePlan(for: activeTasks)

        TaskLifecycleManager.applySchedule(
            plan,
            in: modelContext,
            customCategories: customCategories
        )
        refreshDerivedCaches()
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

    private func queueStartupMaintenanceIfNeeded() {
        guard !hasQueuedStartupMaintenance else {
            return
        }

        hasQueuedStartupMaintenance = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            guard !Task.isCancelled else {
                return
            }

            archiveOldCompletedTasks()
            purgeExpiredBinItems()
        }
    }

    private var binRetentionPeriod: TaskBinRetentionPeriod {
        TaskBinRetentionPeriod(rawValue: binRetentionRawValue) ?? .fallback
    }

    private func purgeExpiredBinItems() {
        var descriptor = FetchDescriptor<LifeTask>(
            predicate: #Predicate<LifeTask> { $0.deletedAt != nil }
        )
        descriptor.fetchLimit = 500
        guard let deletedTasks = try? modelContext.fetch(descriptor) else {
            return
        }
        TaskLifecycleManager.purgeExpiredBinItems(
            from: deletedTasks,
            in: modelContext,
            retentionPeriod: binRetentionPeriod
        )
    }

    private func archiveOldCompletedTasks() {
        TaskLifecycleManager.archiveOldCompletedTasks(
            from: completedTasks,
            in: modelContext,
            archivePeriod: CompletedArchivePeriod.current
        )
    }

    private func refreshDerivedCaches() {
        let openSnapshot = openTasks
        let completedSnapshot = completedTasks

        let recommendations = DailyFocusPlanner.recommendations(from: openSnapshot)
        cachedFocus = recommendations

        let grouped = Dictionary(grouping: recommendations, by: \.reason)
        cachedFocusGroups = DailyFocusReason.displayOrder.compactMap { reason in
            guard let recs = grouped[reason], !recs.isEmpty else {
                return nil
            }
            return DailyFocusRecommendationGroup(reason: reason, recommendations: recs)
        }

        cachedDocumentReminders = openSnapshot
            .filter(\.hasDocumentIntelligence)
            .sorted {
                ($0.documentSuggestedDueDate ?? $0.dueDate) < ($1.documentSuggestedDueDate ?? $1.dueDate)
            }

        var combinedDocuments: [LifeTask] = []
        combinedDocuments.reserveCapacity(openSnapshot.count + completedSnapshot.count)
        for task in openSnapshot where task.hasDocument {
            combinedDocuments.append(task)
        }
        for task in completedSnapshot where task.hasDocument {
            combinedDocuments.append(task)
        }
        cachedDocumentTasks = combinedDocuments.sorted { $0.updatedAt > $1.updatedAt }

        let now = Date()
        let calendar = Calendar.current
        var dueToday = 0
        var upcoming = 0
        var overdue = 0
        for task in openSnapshot {
            let isToday = calendar.isDateInToday(task.dueDate)
            if isToday {
                dueToday += 1
            }
            if task.dueDate < now {
                overdue += 1
            } else if !isToday {
                upcoming += 1
            }
        }
        cachedDueTodayCount = dueToday
        cachedUpcomingCount = upcoming
        cachedOverdueCount = overdue
        cachedCompletedCount = completedSnapshot.count

        FocusWidgetSnapshotPublisher.publish(
            focusTasks: recommendations.map(\.task),
            overdueCount: overdue,
            dueTodayCount: dueToday,
            upcomingCount: upcoming
        )
    }

    private func drainSharedInbox() {
        let context = modelContext
        Task { @MainActor in
            await SharedInboxImporter.drain(context: context)
            refreshInboxItems()
        }
    }

    private func refreshInboxItems() {
        inboxItems = InboxStore.loadOpenItems()
    }
}

private enum HomeRoute: Hashable {
    case statistics
    case calendar
    case availabilityCalendar
    case documents
    case taskData(TaskDataExchangeEntryMode)
    case money
}

private struct StreakCelebrationBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, LifeTrackTheme.Spacing.large)
        .padding(.vertical, 12)
        .background(
            Color(red: 0.9, green: 0.35, blue: 0.1).opacity(0.95),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

private struct InboxDashboardPreviewRow: View {
    let item: InboxItem

    private var draft: CapturedTaskDraft {
        item.captureDraft
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.source.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(sourceTint)
                .frame(width: 34, height: 34)
                .background(sourceTint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.previewTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(draft.resolvedDueDate.dayMonthString)
                    Text("•")
                    Text(item.source.title)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.82), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.7)
        }
    }

    private var sourceTint: Color {
        switch item.source {
        case .typed:
            LifeTrackTheme.ColorPalette.accent
        case .voice:
            LifeTrackTheme.ColorPalette.secondaryAccent
        case .shared:
            LifeTrackTheme.ColorPalette.success
        }
    }
}

private struct HomeLayoutMetrics {
    let expansion: CGFloat

    init(availableHeight: CGFloat, priorityCount: Int, documentCount: Int, isEmpty: Bool) {
        let heightExpansion = min(max((availableHeight - 650) / 130, 0), 1)
        let sparseDashboard = isEmpty || (priorityCount <= 2 && documentCount <= 2)
        expansion = sparseDashboard ? heightExpansion : heightExpansion * 0.25
    }

    var sectionSpacing: CGFloat {
        LifeTrackTheme.Spacing.large + (4 * expansion)
    }

    var statCardHeight: CGFloat {
        82 + (14 * expansion)
    }

    var statIconSize: CGFloat {
        LifeTrackTheme.IconSize.smallCircle + (4 * expansion)
    }

    var statValueFontSize: CGFloat {
        27 + (2 * expansion)
    }

    var statCardPadding: CGFloat {
        13 + (2 * expansion)
    }

    var quickActionWidth: CGFloat {
        158 + (6 * expansion)
    }

    var quickActionWideWidth: CGFloat {
        188 + (8 * expansion)
    }

    var quickActionHeight: CGFloat {
        68 + (10 * expansion)
    }

    var quickActionIconSize: CGFloat {
        32 + (4 * expansion)
    }

    var taskRowVerticalPadding: CGFloat {
        12 + (3 * expansion)
    }

    var taskRowIconSize: CGFloat {
        28 + (3 * expansion)
    }

    var documentRowVerticalPadding: CGFloat {
        14 + (6 * expansion)
    }

    var documentRowIconSize: CGFloat {
        42 + (8 * expansion)
    }

    var bottomPadding: CGFloat {
        96
    }
}

private struct DailyFocusRecommendationGroup: Identifiable {
    let reason: DailyFocusReason
    let recommendations: [DailyFocusRecommendation]

    var id: String { reason.rawValue }
}

private struct DashboardMessageSource {
    let messages: [String]
    let tone: DashboardMessageTone
}

private struct DashboardMessageSignal {
    let text: String
    let tone: DashboardMessageTone
}

private enum DashboardMessageTone {
    case calm
    case focus
    case clear
    case completed
    case overdue
    case busy

    var tint: Color {
        switch self {
        case .calm:
            LifeTrackTheme.ColorPalette.accent
        case .focus:
            LifeTrackTheme.ColorPalette.secondaryAccent
        case .clear:
            LifeTrackTheme.ColorPalette.success
        case .completed:
            LifeTrackTheme.ColorPalette.success
        case .overdue:
            LifeTrackTheme.ColorPalette.danger
        case .busy:
            LifeTrackTheme.ColorPalette.warning
        }
    }

    var symbolName: String {
        switch self {
        case .calm:
            "sparkles"
        case .focus:
            "scope"
        case .clear:
            "checkmark.seal.fill"
        case .completed:
            "checkmark.circle.fill"
        case .overdue:
            "exclamationmark.triangle.fill"
        case .busy:
            "calendar.badge.clock"
        }
    }
}

private struct DashboardHeaderMessageView: View {
    let message: DashboardMessageSignal

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            ZStack {
                Circle()
                    .fill(message.tone.tint.opacity(0.13))

                Image(systemName: message.tone.symbolName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(message.tone.tint)
            }
            .frame(width: 25, height: 25)
            .padding(.top, 1)

            Text(message.text)
                .font(.callout.weight(.medium))
                .lineSpacing(1.5)
                .foregroundStyle(messageTextColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(messageBackground, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(message.tone.tint.opacity(0.17), lineWidth: 0.8)
        }
    }

    private var messageTextColor: Color {
        message.tone.tint.mixed(with: LifeTrackTheme.ColorPalette.primaryText, amount: 0.36)
    }

    private var messageBackground: Color {
        LifeTrackTheme.ColorPalette.cardElevated
            .mixed(with: message.tone.tint, amount: 0.055)
            .opacity(0.92)
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
        case .upcoming: LifeTrackTheme.ColorPalette.secondaryAccent
        case .completed: LifeTrackTheme.ColorPalette.success
        case .overdue: LifeTrackTheme.ColorPalette.danger
        }
    }
}

private struct DashboardSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(LifeTrackSettings.Keys.binRetentionPeriod) private var binRetentionRawValue = TaskBinRetentionPeriod.fallback.rawValue

    @State private var pendingReopenTask: LifeTask?
    @State private var pendingBulkAction: DashboardBulkAction?
    @State private var binUndoState: TaskBinUndoState?
    @State private var restoredToastState: TaskRestoredToastState?
    @State private var bulkToastState: DashboardBulkToastState?
    @State private var isBulkSelecting = false
    @State private var bulkAction: DashboardBulkAction = .moveToBin
    @State private var isShowingBulkActionMenu = false
    @State private var isShowingBulkActionPicker = false
    @State private var selectedTaskIDs: Set<UUID> = []

    let summary: DashboardSummaryKind
    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
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
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
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
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .overlay {
                if let pendingBulkAction {
                    LifeTrackConfirmationOverlay(
                        symbolName: pendingBulkAction.symbolName,
                        title: pendingBulkAction.confirmationTitle(count: selectedTasks.count),
                        message: pendingBulkAction.confirmationMessage(count: selectedTasks.count),
                        confirmTitle: pendingBulkAction.confirmTitle(count: selectedTasks.count),
                        cancelTitle: "Review",
                        tint: pendingBulkAction.tint,
                        isDestructive: pendingBulkAction.isDestructive,
                        onConfirm: { performBulkAction(pendingBulkAction) },
                        onCancel: { self.pendingBulkAction = nil }
                    )
                } else if let pendingReopenTask {
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
                if let bulkToastState {
                    DashboardBulkActionToast(
                        state: bulkToastState,
                        onDismiss: { dismissBulkToast(id: bulkToastState.id) }
                    )
                    .task(id: bulkToastState.id) {
                        try? await Task.sleep(nanoseconds: 2_600_000_000)
                        await MainActor.run {
                            dismissBulkToast(id: bulkToastState.id)
                        }
                    }
                } else if let binUndoState {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .onChange(of: tasks.map(\.id)) { _, taskIDs in
                selectedTaskIDs.formIntersection(Set(taskIDs))
                if taskIDs.isEmpty {
                    cancelBulkSelection()
                }
            }
        }
    }

    private var summaryHeader: some View {
        SectionCardView {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                DashboardSummaryHeroIcon(
                    summary: summary,
                    animationsEnabled: animationsEnabled
                )

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

                AnimatedCountText(
                    value: tasks.count,
                    animationsEnabled: animationsEnabled
                )
                    .font(.lifeTrack(.title, weight: .bold))
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
            taskListHeader

            if isShowingBulkActionMenu {
                DashboardBulkActionDropdown(
                    selectedAction: bulkAction,
                    title: "Bulk Action",
                    onSelect: { action in
                        startBulkSelection(action)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .topTrailing)))
            }

            if isBulkSelecting {
                bulkSelectionControls
            }

            LazyVStack(spacing: LifeTrackTheme.Spacing.small) {
                ForEach(tasks) { task in
                    DashboardSummaryTaskCard(
                        task: task,
                        categoryOption: task.categoryOption(customCategories: customCategories),
                        bulkAction: isBulkSelecting ? bulkAction : nil,
                        isSelected: selectedTaskIDs.contains(task.id),
                        onSelect: { toggleSelection(for: task) },
                        onToggleCompletion: { requestToggleCompletion(for: task) },
                        onEdit: { onEdit(task) },
                        onDelete: { moveToBin(task) }
                    )
                }
            }
        }
    }

    private var taskListHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: LifeTrackTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Tasks")
                        .font(.lifeTrackHeadline)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    InfoTipButton(message: "Use Actions to select multiple tasks, then move them to Bin, reopen them, mark them complete, or move their due date to tomorrow.")
                }

                Text(isBulkSelecting ? "\(selectedTaskIDs.count) selected for \(bulkAction.title.lowercased())." : summary.subtitle)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Button {
                withSelectionAnimation {
                    isShowingBulkActionMenu.toggle()
                    isShowingBulkActionPicker = false
                }
            } label: {
                Label(isBulkSelecting ? bulkAction.shortTitle : "Actions", systemImage: isBulkSelecting ? bulkAction.symbolName : "checklist")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isBulkSelecting ? bulkAction.tint : LifeTrackTheme.ColorPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background((isBulkSelecting ? bulkAction.tint : LifeTrackTheme.ColorPalette.accent).opacity(0.11), in: Capsule())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.94, pressedOpacity: 0.9))
        }
    }

    private var bulkSelectionControls: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(spacing: LifeTrackTheme.Spacing.small) {
                Button {
                    withSelectionAnimation {
                        isShowingBulkActionPicker.toggle()
                        isShowingBulkActionMenu = false
                    }
                } label: {
                    Label(bulkAction.title, systemImage: bulkAction.symbolName)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(bulkAction.tint)
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(bulkAction.tint.opacity(0.11), in: Capsule())
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.9))

                Spacer(minLength: 0)

                Button(selectedTaskIDs.count == tasks.count ? "Clear" : "All") {
                    toggleSelectAll()
                }
                .font(.footnote.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.9))

                Button("Cancel") {
                    cancelBulkSelection()
                }
                .font(.footnote.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Capsule())
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.9))
            }

            if isShowingBulkActionPicker {
                DashboardBulkActionDropdown(
                    selectedAction: bulkAction,
                    title: "Choose Action",
                    onSelect: { action in
                        withSelectionAnimation {
                            bulkAction = action
                            isShowingBulkActionPicker = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            Button {
                requestBulkAction()
            } label: {
                Label(bulkAction.applyTitle(count: selectedTaskIDs.count), systemImage: bulkAction.symbolName)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(selectedTaskIDs.isEmpty ? LifeTrackTheme.ColorPalette.tertiaryText : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        selectedTaskIDs.isEmpty ? AnyShapeStyle(LifeTrackTheme.ColorPalette.backgroundTop) : AnyShapeStyle(bulkAction.background),
                        in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    )
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: selectedTaskIDs.isEmpty ? 1 : 0.98, pressedOpacity: 0.92))
            .disabled(selectedTaskIDs.isEmpty)
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(bulkAction.tint.opacity(0.18), lineWidth: 0.8)
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

    private var binRetentionPeriod: TaskBinRetentionPeriod {
        TaskBinRetentionPeriod(rawValue: binRetentionRawValue) ?? .fallback
    }

    private var selectedTasks: [LifeTask] {
        tasks.filter { selectedTaskIDs.contains($0.id) }
    }

    private func requestToggleCompletion(for task: LifeTask) {
        guard !isBulkSelecting else {
            toggleSelection(for: task)
            return
        }

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
        guard !isBulkSelecting else {
            toggleSelection(for: task)
            return
        }

        let movedToBin = TaskLifecycleManager.delete(
            task,
            in: modelContext,
            retentionPeriod: binRetentionPeriod
        )

        if movedToBin {
            showUndoToast(for: task)
        }
    }

    private func startBulkSelection(_ action: DashboardBulkAction) {
        LifeTrackHaptics.lightImpact()
        withSelectionAnimation {
            bulkAction = action
            isBulkSelecting = true
            isShowingBulkActionMenu = false
            isShowingBulkActionPicker = false
        }
    }

    private func cancelBulkSelection() {
        withSelectionAnimation {
            isBulkSelecting = false
            pendingBulkAction = nil
            isShowingBulkActionMenu = false
            isShowingBulkActionPicker = false
            selectedTaskIDs.removeAll()
        }
    }

    private func toggleSelection(for task: LifeTask) {
        withSelectionAnimation {
            if selectedTaskIDs.contains(task.id) {
                selectedTaskIDs.remove(task.id)
            } else {
                selectedTaskIDs.insert(task.id)
            }
        }
    }

    private func toggleSelectAll() {
        withSelectionAnimation {
            if selectedTaskIDs.count == tasks.count {
                selectedTaskIDs.removeAll()
            } else {
                selectedTaskIDs = Set(tasks.map(\.id))
            }
        }
    }

    private func requestBulkAction() {
        guard !selectedTaskIDs.isEmpty else {
            return
        }

        pendingBulkAction = bulkAction
    }

    private func performBulkAction(_ action: DashboardBulkAction) {
        let tasksToUpdate = selectedTasks
        pendingBulkAction = nil

        guard !tasksToUpdate.isEmpty else {
            cancelBulkSelection()
            return
        }

        LifeTrackHaptics.lightImpact()

        let changedCount: Int
        switch action {
        case .moveToBin:
            changedCount = moveSelectedTasksToBin(tasksToUpdate)
        case .markOpen:
            changedCount = setSelectedTasks(tasksToUpdate, completed: false)
        case .markComplete:
            changedCount = setSelectedTasks(tasksToUpdate, completed: true)
        case .moveTomorrow:
            changedCount = moveSelectedTasksToTomorrow(tasksToUpdate)
        }

        cancelBulkSelection()
        showBulkToast(
            title: changedCount == 0 ? "No tasks changed" : action.toastTitle(count: changedCount),
            message: changedCount == 0 ? "Selected tasks already match that action." : action.toastMessage(count: changedCount),
            symbolName: action.symbolName,
            tint: action.tint
        )
    }

    private func moveSelectedTasksToBin(_ tasksToUpdate: [LifeTask]) -> Int {
        var changedCount = 0

        for task in tasksToUpdate {
            _ = TaskLifecycleManager.delete(
                task,
                in: modelContext,
                retentionPeriod: binRetentionPeriod
            )
            changedCount += 1
        }

        return changedCount
    }

    private func setSelectedTasks(_ tasksToUpdate: [LifeTask], completed: Bool) -> Int {
        let filteredTasks = tasksToUpdate.filter { $0.isCompleted != completed }

        for task in filteredTasks {
            TaskLifecycleManager.toggleCompletion(
                for: task,
                in: modelContext,
                customCategories: customCategories
            )
        }

        return filteredTasks.count
    }

    private func moveSelectedTasksToTomorrow(_ tasksToUpdate: [LifeTask]) -> Int {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let now = Date()

        for task in tasksToUpdate {
            let components = calendar.dateComponents([.hour, .minute, .second], from: task.dueDate)
            task.dueDate = calendar.date(
                bySettingHour: components.hour ?? 9,
                minute: components.minute ?? 0,
                second: components.second ?? 0,
                of: tomorrow
            ) ?? tomorrow
            task.updatedAt = now
            TaskLifecycleManager.synchronizeReminder(for: task, customCategories: customCategories)
        }

        try? modelContext.save()
        return tasksToUpdate.count
    }

    private func withSelectionAnimation(_ updates: () -> Void) {
        guard animationsEnabled else {
            updates()
            return
        }

        withAnimation(.snappy(duration: 0.2), updates)
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

    private func showBulkToast(title: String, message: String, symbolName: String, tint: Color) {
        let toastState = DashboardBulkToastState(
            title: title,
            message: message,
            symbolName: symbolName,
            tint: tint
        )

        guard animationsEnabled else {
            bulkToastState = toastState
            return
        }

        withAnimation(.snappy(duration: 0.2)) {
            bulkToastState = toastState
        }
    }

    private func dismissBulkToast(id: UUID?) {
        guard id == nil || bulkToastState?.id == id else {
            return
        }

        guard animationsEnabled else {
            bulkToastState = nil
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            bulkToastState = nil
        }
    }
}

private enum DashboardBulkAction: String, CaseIterable, Identifiable {
    case moveToBin
    case markOpen
    case markComplete
    case moveTomorrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moveToBin: "Move to Bin"
        case .markOpen: "Move to Open"
        case .markComplete: "Mark Complete"
        case .moveTomorrow: "Move to Tomorrow"
        }
    }

    var shortTitle: String {
        switch self {
        case .moveToBin: "Bin"
        case .markOpen: "Open"
        case .markComplete: "Complete"
        case .moveTomorrow: "Tomorrow"
        }
    }

    var menuSubtitle: String {
        switch self {
        case .moveToBin: "Move selected tasks into Bin"
        case .markOpen: "Return completed tasks to progress"
        case .markComplete: "Finish selected open tasks"
        case .moveTomorrow: "Push due dates forward one day"
        }
    }

    var symbolName: String {
        switch self {
        case .moveToBin: "trash"
        case .markOpen: "arrow.uturn.left"
        case .markComplete: "checkmark"
        case .moveTomorrow: "calendar.badge.clock"
        }
    }

    var selectedSymbolName: String {
        switch self {
        case .moveToBin: "trash.fill"
        case .markOpen: "arrow.uturn.left.circle.fill"
        case .markComplete: "checkmark.circle.fill"
        case .moveTomorrow: "calendar.badge.clock"
        }
    }

    var tint: Color {
        switch self {
        case .moveToBin:
            LifeTrackTheme.ColorPalette.danger
        case .markOpen:
            LifeTrackTheme.ColorPalette.accent
        case .markComplete:
            LifeTrackTheme.ColorPalette.success
        case .moveTomorrow:
            LifeTrackTheme.ColorPalette.warning
        }
    }

    var background: LinearGradient {
        LinearGradient(
            colors: [tint, tint.mixed(with: .black, amount: isDestructive ? 0.18 : 0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var isDestructive: Bool {
        self == .moveToBin
    }

    func applyTitle(count: Int) -> String {
        guard count > 0 else {
            return "Select Tasks"
        }

        return switch self {
        case .moveToBin: "Move \(count) to Bin"
        case .markOpen: "Move \(count) to Open"
        case .markComplete: "Mark \(count) Complete"
        case .moveTomorrow: "Move \(count) to Tomorrow"
        }
    }

    func confirmTitle(count: Int) -> String {
        return switch self {
        case .moveToBin: "Move \(count) to Bin"
        case .markOpen: "Move \(count) Back"
        case .markComplete: "Complete \(count)"
        case .moveTomorrow: "Move \(count)"
        }
    }

    func confirmationTitle(count: Int) -> String {
        return switch self {
        case .moveToBin: "Move \(count) \(taskWord(count)) to Bin?"
        case .markOpen: "Move \(count) \(taskWord(count)) to open?"
        case .markComplete: "Mark \(count) \(taskWord(count)) complete?"
        case .moveTomorrow: "Move \(count) \(taskWord(count)) to tomorrow?"
        }
    }

    func confirmationMessage(count: Int) -> String {
        return switch self {
        case .moveToBin:
            "Selected tasks will leave this list and move into Bin using your current retention setting."
        case .markOpen:
            "Selected completed tasks will return to your active lists and reminders may be scheduled again."
        case .markComplete:
            "Selected open tasks will be completed. Recurring tasks may create their next scheduled copy."
        case .moveTomorrow:
            "Selected tasks will keep their current time, but their due date will move to tomorrow."
        }
    }

    func toastTitle(count: Int) -> String {
        return switch self {
        case .moveToBin: "\(count) \(taskWord(count)) moved"
        case .markOpen: "\(count) \(taskWord(count)) reopened"
        case .markComplete: "\(count) \(taskWord(count)) completed"
        case .moveTomorrow: "\(count) \(taskWord(count)) rescheduled"
        }
    }

    func toastMessage(count: Int) -> String {
        return switch self {
        case .moveToBin: "Moved to Bin."
        case .markOpen: "Moved back to open."
        case .markComplete: "Marked complete."
        case .moveTomorrow: "Due date moved to tomorrow."
        }
    }

    private func taskWord(_ count: Int) -> String {
        count == 1 ? "task" : "tasks"
    }
}

private struct DashboardBulkActionDropdown: View {
    let selectedAction: DashboardBulkAction
    let title: String
    let onSelect: (DashboardBulkAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .padding(.horizontal, 2)

            VStack(spacing: 4) {
                ForEach(DashboardBulkAction.allCases) { action in
                    Button {
                        LifeTrackHaptics.lightImpact()
                        onSelect(action)
                    } label: {
                        HStack(spacing: LifeTrackTheme.Spacing.small) {
                            ZStack {
                                Circle()
                                    .fill(action.tint.opacity(action == selectedAction ? 0.18 : 0.11))

                                Image(systemName: action.symbolName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(action.tint)
                            }
                            .frame(width: 30, height: 30)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(action.title)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                                Text(action.menuSubtitle)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: LifeTrackTheme.Spacing.small)

                            Image(systemName: action == selectedAction ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(action == selectedAction ? action.tint : LifeTrackTheme.ColorPalette.tertiaryText.opacity(0.55))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .background(
                            action == selectedAction ? action.tint.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98, pressedOpacity: 0.92))
                }
            }
        }
        .padding(10)
        .background(dropdownBackground, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.24), lineWidth: 0.8)
        }
        .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.12), radius: 14, x: 0, y: 9)
        .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(0.9), radius: 12, x: 0, y: 7)
    }

    private var dropdownBackground: Color {
        LifeTrackTheme.ColorPalette.cardElevated
            .mixed(with: LifeTrackTheme.ColorPalette.accentSoft, amount: 0.34)
    }
}

private struct DashboardBulkToastState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let symbolName: String
    let tint: Color
}

private struct DashboardBulkActionToast: View {
    let state: DashboardBulkToastState
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: state.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(state.tint)
                .frame(width: 34, height: 34)
                .background(state.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(state.message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.9), in: Circle())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9))
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(state.tint.opacity(0.18), lineWidth: 0.8)
        }
        .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(1.1), radius: 18, x: 0, y: 12)
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: .bottom))
        ))
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

private struct DashboardSummaryHeroIcon: View {
    let summary: DashboardSummaryKind
    let animationsEnabled: Bool

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: summary.symbolName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(summary.tint)
            .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
            .background(summary.tint.opacity(0.12), in: Circle())
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onAppear(perform: runAnimationIfNeeded)
            .onChange(of: animationsEnabled) { _, _ in
                runAnimationIfNeeded()
            }
            .onChange(of: summary.id) { _, _ in
                runAnimationIfNeeded()
            }
            .onDisappear {
                animationTask?.cancel()
            }
    }

    @MainActor
    private func runAnimationIfNeeded() {
        animationTask?.cancel()
        rotation = 0
        scale = 1

        guard animationsEnabled else {
            return
        }

        scale = 0.82
        animationTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.82)) {
                rotation = 360
            }

            withAnimation(.spring(response: 0.36, dampingFraction: 0.62)) {
                scale = 1.17
            }

            try? await Task.sleep(nanoseconds: 420_000_000)

            guard !Task.isCancelled else {
                return
            }

            withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) {
                scale = 1
            }
        }
    }
}

private struct AnimatedCountText: View {
    let value: Int
    let animationsEnabled: Bool

    @State private var displayedValue = 0
    @State private var countTask: Task<Void, Never>?

    var body: some View {
        Text(displayedValue.formatted())
            .onAppear {
                startCountAnimation()
            }
            .onChange(of: value) { _, _ in
                startCountAnimation()
            }
            .onChange(of: animationsEnabled) { _, _ in
                startCountAnimation()
            }
            .onDisappear {
                countTask?.cancel()
            }
    }

    @MainActor
    private func startCountAnimation() {
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

        let duration = countDuration(for: target)
        let frameDelay: UInt64 = 16_666_667

        countTask = Task { @MainActor in
            let startedAt = Date()

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startedAt)
                let progress = min(elapsed / duration, 1)
                let easedProgress = 1 - ((1 - progress) * (1 - progress) * (1 - progress))
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

    private func countDuration(for target: Int) -> TimeInterval {
        guard target > 100 else {
            return 3
        }

        let extraDuration = min(Double(target - 100) / 400 * 2, 2)
        return min(3 + extraDuration, 5)
    }
}

private struct DashboardSummaryTaskCard: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let bulkAction: DashboardBulkAction?
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small + 2) {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
                leadingIndicator

                VStack(alignment: .leading, spacing: 7) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)
                        .layoutPriority(1)

                    WrappingChipLayout(spacing: 8, rowSpacing: 7) {
                        CategoryChipView(option: categoryOption)

                        StatusPillView(
                            title: task.dueDate.dayMonthString,
                            symbolName: task.isOverdue ? "exclamationmark.circle.fill" : "calendar",
                            tint: task.isOverdue ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.secondaryText
                        )

                        StatusPillView(
                            title: task.durationTitle,
                            symbolName: "timer",
                            tint: LifeTrackTheme.ColorPalette.secondaryText
                        )

                        if task.priority != .normal {
                            StatusPillView(
                                title: task.priority.title,
                                symbolName: task.priority.symbolName,
                                tint: task.priority.tint
                            )
                        }

                        if task.recurrence != .none {
                            StatusPillView(
                                title: task.recurrence.shortTitle,
                                symbolName: "repeat",
                                tint: task.recurrence.tint
                            )
                        }

                        if task.hasDocument {
                            StatusPillView(
                                title: "File",
                                symbolName: "paperclip",
                                tint: LifeTrackTheme.ColorPalette.secondaryText
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let bulkAction {
                        Label(isSelected ? "Selected for \(bulkAction.shortTitle.lowercased())" : "Tap to select", systemImage: isSelected ? "checkmark.circle.fill" : "hand.tap")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? bulkAction.tint : LifeTrackTheme.ColorPalette.secondaryText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background((isSelected ? bulkAction.tint : LifeTrackTheme.ColorPalette.secondaryText).opacity(0.10), in: Capsule())
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

            if bulkAction == nil {
                HStack(spacing: LifeTrackTheme.Spacing.small) {
                    Button(action: onToggleCompletion) {
                        Label(task.isCompleted ? "Move to Open" : "Complete", systemImage: task.isCompleted ? "arrow.uturn.left" : "checkmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.success)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background((task.isCompleted ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.success).opacity(0.11), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label("Move to Bin", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .frame(width: 32, height: 32)
                            .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(cardStrokeColor, lineWidth: isSelected ? 1.2 : 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .onTapGesture {
            if bulkAction != nil {
                onSelect()
            }
        }
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        if let bulkAction {
            Button(action: onSelect) {
                ZStack {
                    Circle()
                        .fill(isSelected ? bulkAction.tint : bulkAction.tint.opacity(0.10))
                        .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)

                    Circle()
                        .stroke(bulkAction.tint.opacity(isSelected ? 0.0 : 0.42), lineWidth: 1.5)
                        .frame(width: LifeTrackTheme.IconSize.mediumCircle - 2, height: LifeTrackTheme.IconSize.mediumCircle - 2)

                    Image(systemName: isSelected ? bulkAction.selectedSymbolName : bulkAction.symbolName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? .white : bulkAction.tint)
                }
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9, pressedOpacity: 0.9))
            .accessibilityLabel(isSelected ? "Deselect \(task.title)" : "Select \(task.title)")
        } else {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : task.isOverdue ? "exclamationmark.circle.fill" : "circle.dotted")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(statusTint)
                .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                .background(statusTint.opacity(0.11), in: Circle())
        }
    }

    private var cardStrokeColor: Color {
        guard let bulkAction else {
            return LifeTrackTheme.ColorPalette.hairline.opacity(0.8)
        }

        return isSelected ? bulkAction.tint.opacity(0.48) : bulkAction.tint.opacity(0.16)
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

private struct DailyFocusTaskCard: View {
    let recommendation: DailyFocusRecommendation
    let categoryOption: TaskCategoryOption
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var verticalPadding: CGFloat = 12
    var leadingIconSize: CGFloat = 28

    var body: some View {
        TaskRowView(
            task: recommendation.task,
            onToggleCompletion: onToggleCompletion,
            onEdit: onEdit,
            onDelete: onDelete,
            categoryOption: categoryOption,
            verticalPadding: verticalPadding,
            leadingIconSize: leadingIconSize
        )
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        ))
    }
}

private struct DailyFocusReasonHeader: View {
    let reason: DailyFocusReason
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Label(reason.title, systemImage: reason.symbolName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(reason.themeTint)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(reason.themeTint.opacity(0.11), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(reason.themeTint.opacity(0.18), lineWidth: 0.7)
                }

            Text("\(count) \(count == 1 ? "task" : "tasks")")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }
}

private extension DailyFocusReason {
    var themeTint: Color {
        switch self {
        case .overdue:
            LifeTrackTheme.ColorPalette.danger
        case .dueToday:
            LifeTrackTheme.ColorPalette.accent
        case .highPriority:
            LifeTrackTheme.ColorPalette.warning
        case .routine:
            LifeTrackTheme.ColorPalette.success
        case .documentReminder:
            LifeTrackTheme.ColorPalette.secondaryAccent
        case .upcoming:
            LifeTrackTheme.ColorPalette.secondaryText
        }
    }
}

private struct FocusPlanningButton: View {
    let title: String
    let symbolName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 9)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 0.8)
                }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97, pressedOpacity: 0.92))
    }
}

private struct RecentDocumentRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    var verticalPadding: CGFloat = 14
    var iconSize: CGFloat = 42

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(categoryOption.tint)
                .frame(width: iconSize, height: iconSize)
                .background(categoryOption.background, in: Circle())

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
        .padding(.horizontal, 14)
        .padding(.vertical, verticalPadding)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }
}

private struct DocumentReminderRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    var verticalPadding: CGFloat = 14
    var iconSize: CGFloat = 42

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(categoryOption.tint)
                .frame(width: iconSize, height: iconSize)
                .background(categoryOption.background, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.documentSuggestedTitle ?? task.documentDisplayName ?? "Document reminder")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, verticalPadding)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }

    private var subtitle: String {
        if let dueDate = task.documentSuggestedDueDate {
            return "Suggested for \(dueDate.dayMonthString) · \(task.title)"
        }

        if let firstKeyword = task.documentKeywords.first {
            return "\(firstKeyword.capitalized) · \(task.title)"
        }

        return task.title
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, CustomTaskCategory.self, configurations: configuration)

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
