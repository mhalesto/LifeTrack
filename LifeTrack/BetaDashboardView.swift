//
//  BetaDashboardView.swift
//  LifeTrack
//

import Combine
import SwiftData
import SwiftUI

// MARK: - Animated background

// MARK: - Serif font helpers

extension Font {
    static var betaBrand: Font { .lifeTrack(size: 30, role: .title, weight: .bold, defaultDesign: .serif) }
    static var betaGreeting: Font { .lifeTrack(size: 22, role: .title, weight: .semibold, defaultDesign: .serif) }
    static var betaHeroTitle: Font { .lifeTrack(size: 28, role: .title, weight: .bold, defaultDesign: .serif) }
    static var betaSection: Font { .lifeTrack(size: 20, role: .title, weight: .bold, defaultDesign: .serif) }
    static var betaMetric: Font { .lifeTrack(size: 26, role: .title, weight: .bold, defaultDesign: .serif) }
    static var betaStreakStat: Font { .lifeTrack(size: 20, role: .title, weight: .bold, defaultDesign: .serif) }

    static func betaBody(_ size: CGFloat, weight: Font.Weight = .regular, defaultDesign: Font.Design = .default) -> Font {
        .lifeTrack(size: size, role: .body, weight: weight, defaultDesign: defaultDesign)
    }

    static func betaCaption(_ size: CGFloat, weight: Font.Weight = .medium, defaultDesign: Font.Design = .default) -> Font {
        .lifeTrack(size: size, role: .caption, weight: weight, defaultDesign: defaultDesign)
    }

    static func betaRounded(_ size: CGFloat, role: LifeTrackTypography.Role, weight: Font.Weight = .semibold) -> Font {
        .lifeTrack(size: size, role: role, weight: weight, defaultDesign: .rounded)
    }
}

// Sibling files:
//   BetaDashboardShapes.swift        — StatSparkline, StatWave, PedestalShape,
//                                      FlameShape, MountainShape, BetaLeafShape,
//                                      BetaMetricTrends
//   BetaDashboardIllustrations.swift — StreakHeroIllustration, DailyFocusBackdrop
//   BetaDashboardPalette.swift       — BetaPalette
//   BetaDashboardTypes.swift         — BetaTab, BetaHomeRoute, BetaQuickAction,
//                                      DashboardSortOrder, BetaSummaryKind
//   BetaDashboardComponents.swift    — BetaDashboardTabBar, BetaRecentDocumentRow,
//                                      BetaSummaryTaskCard, HeroPager, HeroPagerDots
//   BetaDashboardSheets.swift        — DailyFocusSortSheet, BetaStatSummarySheet,
//                                      FocusTimerSheet, QuickActionsCustomizeSheet
//   BetaDashboardHeroHelpers.swift   — productivityHeroShell, heroMetricPill,
//                                      heroProgressRow, heroInsightRow,
//                                      heroActionButton, heroInlineActionButton,
//                                      streakStatCell, betaFocusPlanningButton

// MARK: - BetaDashboardHomeView

struct BetaDashboardHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && !$0.isCompleted }, sort: \LifeTask.dueDate, order: .forward)
    private var openTasks: [LifeTask]

    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && $0.isCompleted }, sort: \LifeTask.dueDate, order: .reverse)
    private var completedTasks: [LifeTask]

    private var allTasks: [LifeTask] { openTasks + completedTasks }

    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    @State private var navigationPath: [BetaHomeRoute] = []
    @State private var selectedTab: BetaTab = .home
    @State private var isShowingSettings = false
    @State private var isShowingTemplatePicker = false
    @State private var isShowingLogMoney = false
    @State private var isShowingTaskEditor = false
    @State private var isShowingQuickCapture = false
    @State private var isShowingVoiceCapture = false
    @State private var isShowingInbox = false
    @State private var isShowingHabits = false
    @State private var isShowingDailyRitual = false
    @State private var isShowingWeeklyReview = false
    @State private var selectedTemplate: TaskTemplate? = nil
    @State private var selectedCaptureDraft: CapturedTaskDraft? = nil
    @State private var shouldAutoStartVoice = false
    @State private var editingTask: LifeTask? = nil
    @State private var isShowingAISuggestions = false
    @State private var isShowingSmartScheduling = false
    @State private var isShowingAvailability = false
    @State private var isShowingPaywall = false
    @State private var availabilityShareRange: AvailabilityShareRange = .today
    @State private var inboxItems: [InboxItem] = InboxStore.loadOpenItems()
    @AppStorage(LifeTrackSettings.Keys.betaShapesOpacity) private var shapesOpacity: Double = 0.35

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                ZStack {
                    BetaAnimatedShapesBackground(opacity: shapesOpacity)
                        .ignoresSafeArea()

                    BetaDashboardView(
                        onOpenStatistics: { navigationPath.append(.statistics) },
                        onOpenSettings: { isShowingSettings = true },
                        inboxItems: inboxItems,
                        onPresentSheet: handleSheetRequest,
                        onNavigate: { navigationPath.append($0) }
                    )
                }
                .frame(maxHeight: .infinity)

                tabBarOverlay
                    .background(BetaPalette.appBackground.ignoresSafeArea(edges: .bottom))
            }
            .overlay(alignment: .bottomTrailing) { fabOverlay }
            .navigationBarHidden(true)
            .navigationDestination(for: BetaHomeRoute.self) { route in
                switch route {
                case .statistics:
                    StatisticsView(tasks: allTasks)
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
                case .importTasks:
                    TaskDataExchangeView(initialMode: .importTasks)
                case .exportTasks:
                    TaskDataExchangeView(initialMode: .exportTasks)
                case .money:
                    MoneyOverviewView()
                }
            }
            .onChange(of: selectedTab) { _, tab in
                handleTabSelection(tab)
            }
        }
        .tint(BetaPalette.accent)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $isShowingTemplatePicker) {
            TemplatePickerView(
                onSelectBlank: openBlankTaskFromPicker,
                onSelectVoice: openVoiceTaskFromPicker,
                onSelectLogMoney: openLogMoneyFromPicker,
                onSelectTemplate: openTemplateFromPicker
            )
        }
        .sheet(isPresented: $isShowingQuickCapture, onDismiss: refreshInboxItems) {
            QuickCaptureView(
                onOpenEditor: openCapturedDraftInEditor,
                onOpenVoiceCapture: openVoiceCapture,
                onOpenQuickAdd: openQuickAdd
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
        .sheet(isPresented: $isShowingLogMoney) {
            LogMoneyView()
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
        .sheet(item: $editingTask) { task in
            NewTaskView(task: task)
        }
        .onReceive(NotificationCenter.default.publisher(for: TaskSpotlightIndexer.openTaskNotification)) { note in
            guard let id = note.userInfo?[TaskSpotlightIndexer.openTaskUserInfoKey] as? UUID,
                  let match = allTasks.first(where: { $0.id == id })
            else { return }
            editingTask = match
        }
        .sheet(isPresented: $isShowingHabits) {
            HabitTrackerView(
                tasks: openTasks,
                customCategories: customCategories,
                onToggleCompletion: toggleCompletion
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
        .sheet(isPresented: $isShowingWeeklyReview) {
            WeeklyReviewView(tasks: openTasks, customCategories: customCategories)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingAISuggestions) {
            AITaskSuggestionsView(tasks: openTasks)
        }
        .sheet(isPresented: $isShowingSmartScheduling) {
            SmartSchedulingOptimizerView(tasks: openTasks)
        }
        .sheet(isPresented: $isShowingAvailability) {
            AvailabilityShareSheet(
                selectedRange: $availabilityShareRange,
                tasks: openTasks,
                customCategories: customCategories,
                onOpenCalendar: {
                    isShowingAvailability = false
                    navigationPath.append(.calendar)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
        .onAppear {
            refreshInboxItems()
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
            openPendingNotificationTaskIfNeeded()
            drainSharedInbox()
        }
    }

    private var fabOverlay: some View {
        Button {
            openQuickCapture()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(BetaPalette.fabGradient, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: BetaPalette.accent.opacity(0.55), radius: 18, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 22)
        .padding(.bottom, 16)
        .accessibilityLabel("Capture to inbox")
    }

    private var tabBarOverlay: some View {
        BetaDashboardTabBar(selectedTab: $selectedTab)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }

    private func handleTabSelection(_ tab: BetaTab) {
        switch tab {
        case .home:
            break
        case .tasks:
            isShowingWeeklyReview = true
            resetTab()
        case .focus:
            isShowingDailyRitual = true
            resetTab()
        case .habits:
            isShowingHabits = true
            resetTab()
        case .more:
            isShowingSettings = true
            resetTab()
        }
    }

    private func resetTab() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            selectedTab = .home
        }
    }

    private func handleSheetRequest(_ sheet: BetaDashboardView.Sheet) {
        switch sheet {
        case .streaks: isShowingHabits = true
        case .planMyDay: isShowingDailyRitual = true
        case .review: isShowingWeeklyReview = true
        case .newTask:
            openQuickCapture()
        case .quickCapture:
            openQuickCapture()
        case .voiceCapture:
            openVoiceCapture()
        case .inbox:
            openInbox()
        case .templates:
            openQuickAdd()
        case .availability:
            isShowingAvailability = true
        case .aiSuggestions:
            isShowingAISuggestions = true
        case .smartScheduling:
            isShowingSmartScheduling = true
        case .template(let id):
            selectedTemplate = TaskTemplate.common.first { $0.id == id }
            shouldAutoStartVoice = false
            isShowingTaskEditor = true
        case .paywall:
            isShowingPaywall = true
        }
    }

    private func openBlankTask() {
        selectedCaptureDraft = nil
        selectedTemplate = nil
        shouldAutoStartVoice = false
        isShowingTaskEditor = true
    }

    private func openQuickAdd() {
        selectedCaptureDraft = nil
        selectedTemplate = nil
        shouldAutoStartVoice = false
        isShowingQuickCapture = false
        isShowingVoiceCapture = false
        isShowingInbox = false
        isShowingTemplatePicker = true
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

    private func openVoiceTaskFromPicker() {
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            openVoiceCapture()
        }
    }

    private func openLogMoneyFromPicker() {
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingLogMoney = true
        }
    }

    private func openPendingNotificationTaskIfNeeded() {
        guard let task = LifeTrackNotificationActionHandler.consumePendingOpenTask(in: allTasks) else {
            return
        }

        selectedTab = .home
        selectedCaptureDraft = nil
        selectedTemplate = nil
        shouldAutoStartVoice = false
        isShowingTemplatePicker = false
        isShowingTaskEditor = false
        editingTask = task
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

    private func openQuickCapture() {
        selectedCaptureDraft = nil
        selectedTemplate = nil
        shouldAutoStartVoice = false
        isShowingInbox = false
        isShowingVoiceCapture = false
        isShowingTemplatePicker = false
        isShowingQuickCapture = true
    }

    private func openVoiceCapture() {
        selectedCaptureDraft = nil
        selectedTemplate = nil
        shouldAutoStartVoice = false
        isShowingInbox = false
        isShowingQuickCapture = false
        isShowingTemplatePicker = false
        isShowingVoiceCapture = true
    }

    private func openInbox() {
        selectedCaptureDraft = nil
        selectedTemplate = nil
        shouldAutoStartVoice = false
        isShowingQuickCapture = false
        isShowingVoiceCapture = false
        isShowingTemplatePicker = false
        refreshInboxItems()
        isShowingInbox = true
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

    private func toggleCompletion(_ task: LifeTask) {
        let pending = TaskLifecycleManager.beginToggleCompletion(for: task)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            TaskLifecycleManager.finishToggleCompletion(pending, in: modelContext, customCategories: customCategories)
        }
    }
}

// MARK: - BetaDashboardView (scroll content)

struct BetaDashboardView: View {
    enum Sheet {
        case streaks, planMyDay, review
        case newTask, quickCapture, voiceCapture, inbox, templates, availability, aiSuggestions, smartScheduling
        case template(id: String)
        case paywall
    }

    var onOpenStatistics: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil
    var inboxItems: [InboxItem] = []
    var onPresentSheet: ((Sheet) -> Void)? = nil
    fileprivate var onNavigate: ((BetaHomeRoute) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query private var tasks: [LifeTask]
    @Query(sort: \MoneyEntry.startDate, order: .reverse) private var moneyEntries: [MoneyEntry]
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]
    @AppStorage(LifeTrackSettings.Keys.nickname) private var nickname = ""
    @AppStorage(LifeTrackSettings.Keys.avatarVersion) private var avatarVersion = 0
    @AppStorage(LifeTrackSettings.Keys.themeID) private var themeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.colorStrength) private var colorStrength: Double = 1.0
    @AppStorage(LifeTrackSettings.Keys.moneyCurrencyCode) private var appMoneyCurrencyCode = MoneyCurrency.defaultCode
    @AppStorage("qa.planMyDay") private var showPlanMyDay = true
    @AppStorage("qa.habits") private var showHabits = true
    @AppStorage("qa.review") private var showReview = true
    @AppStorage("qa.focusTimer") private var showFocusTimer = true
    @AppStorage("qa.newTask") private var showNewTask = true
    @AppStorage("qa.voiceCapture") private var showVoiceCaptureAction = true
    @AppStorage("qa.inbox") private var showInboxAction = true
    @AppStorage("qa.templates") private var showTemplates = true
    @AppStorage("qa.availability") private var showAvailability = false
    @AppStorage("qa.calendar") private var showCalendar = true
    @AppStorage("qa.statistics") private var showStatistics = true
    @AppStorage("qa.documents") private var showDocuments = false
    @AppStorage("qa.import") private var showImport = false
    @AppStorage("qa.export") private var showExport = false
    @AppStorage("qa.email") private var showEmail = false
    @AppStorage("qa.bill") private var showBill = false
    @AppStorage("qa.medication") private var showMedication = false
    @AppStorage("qa.budget") private var showBudget = false
    @AppStorage("qa.checkup") private var showCheckup = false
    @AppStorage("qa.aiSuggestions") private var showAISuggestions = true
    @AppStorage("qa.smartSchedule") private var showSmartSchedule = true

    @State private var focusSortOrder: DashboardSortOrder = .today
    @State private var isShowingFocusSortSheet = false
    @State private var isShowingFocusTimer = false
    @State private var isShowingCustomize = false
    @State private var isShowingMoneyAIInsights = false
    @State private var isAlertBannerVisible = true
    @State private var selectedSummaryKind: BetaSummaryKind?
    @State private var editingTask: LifeTask?

    private var isEmbeddedAsHome: Bool {
        onOpenStatistics != nil || onOpenSettings != nil || onPresentSheet != nil
    }

    private var activeTasks: [LifeTask] {
        tasks.filter { $0.deletedAt == nil }
    }

    private var dueToday: Int {
        activeTasks.filter { !$0.isCompleted && Calendar.current.isDateInToday($0.dueDate) }.count
    }

    private var upcoming: Int {
        let now = Date()
        let cal = Calendar.current
        return activeTasks
            .filter { !$0.isCompleted && $0.dueDate > now && !cal.isDateInToday($0.dueDate) }
            .count
    }

    private var completed: Int {
        tasks.filter { $0.isCompleted }.count
    }

    private var overdue: Int {
        activeTasks.filter { $0.isOverdue }.count
    }

    private var metricTrends: BetaMetricTrends {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let pastDays: [Date] = (0..<7).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
        let futureDays: [Date] = (1...7).compactMap {
            cal.date(byAdding: .day, value: $0, to: today)
        }
        let pastEndOfDays: [Date] = pastDays.compactMap {
            cal.date(bySettingHour: 23, minute: 59, second: 59, of: $0)
        }

        var dueTodayCounts = Array(repeating: 0.0, count: pastDays.count)
        var upcomingCounts = Array(repeating: 0.0, count: futureDays.count)
        var completedCounts = Array(repeating: 0.0, count: pastDays.count)
        var overdueCounts = Array(repeating: 0.0, count: pastEndOfDays.count)

        for task in tasks {
            guard task.deletedAt == nil else { continue }

            let dueDay = cal.startOfDay(for: task.dueDate)
            for (i, day) in pastDays.enumerated() where dueDay == day {
                dueTodayCounts[i] += 1
            }
            if !task.isCompleted {
                for (i, day) in futureDays.enumerated() where dueDay == day {
                    upcomingCounts[i] += 1
                }
            }
            if let completedAt = task.completedAt {
                let completedDay = cal.startOfDay(for: completedAt)
                for (i, day) in pastDays.enumerated() where completedDay == day {
                    completedCounts[i] += 1
                }
            }
            for (i, endOfDay) in pastEndOfDays.enumerated() {
                guard task.dueDate < endOfDay else { continue }
                let wasIncomplete: Bool
                if task.isCompleted {
                    wasIncomplete = (task.completedAt ?? .distantPast) > endOfDay
                } else {
                    wasIncomplete = true
                }
                if wasIncomplete {
                    overdueCounts[i] += 1
                }
            }
        }

        return BetaMetricTrends(
            dueToday: dueTodayCounts,
            upcoming: upcomingCounts,
            completed: completedCounts,
            overdue: overdueCounts
        )
    }

    private var focusTasks: [LifeTask] {
        let base = activeTasks.filter { !$0.isCompleted }
        return sortedFocusTasks(base)
    }

    private var dailyFocusTasks: [LifeTask] {
        if focusSortOrder == .today {
            return todayFocusTasks
        }

        let completedToday = sortedCompletedTodayTasks
        var seenIDs = Set<UUID>()
        var combined: [LifeTask] = []

        for task in focusTasks.prefix(5) where seenIDs.insert(task.id).inserted {
            combined.append(task)
        }

        for task in completedToday.prefix(3) where seenIDs.insert(task.id).inserted {
            combined.append(task)
        }

        return combined
    }

    private var dailyFocusTaskCount: Int {
        focusSortOrder == .today ? todayFocusTasks.count : focusTasks.count
    }

    private var todayFocusCompletedCount: Int {
        todayFocusTasks.filter(\.isCompleted).count
    }

    private var todayFocusProgress: Double {
        guard !todayFocusTasks.isEmpty else { return 0 }
        return min(max(Double(todayFocusCompletedCount) / Double(todayFocusTasks.count), 0), 1)
    }

    private var dailyFocusCountLabel: String {
        if focusSortOrder == .today, !todayFocusTasks.isEmpty {
            return "\(todayFocusCompletedCount)/\(todayFocusTasks.count) tasks"
        }

        return "\(dailyFocusTaskCount) task\(dailyFocusTaskCount == 1 ? "" : "s")"
    }

    private var todayFocusTasks: [LifeTask] {
        let calendar = Calendar.current
        let openToday = activeTasks
            .filter { !$0.isCompleted && calendar.isDateInToday($0.dueDate) }
            .sorted { $0.dueDate < $1.dueDate }
        let completedToday = activeTasks
            .filter { $0.isCompleted && calendar.isDateInToday($0.dueDate) }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
        return openToday + completedToday
    }

    private var sortedCompletedTodayTasks: [LifeTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return activeTasks
            .filter { task in
                guard task.isCompleted else { return false }
                let completedAt = task.completedAt ?? task.updatedAt
                return calendar.startOfDay(for: completedAt) == today
            }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    private func sortedFocusTasks(_ base: [LifeTask]) -> [LifeTask] {
        switch focusSortOrder {
        case .today:
            return base
                .filter { Calendar.current.isDateInToday($0.dueDate) }
                .sorted { $0.dueDate < $1.dueDate }
        case .dueDate:
            return base.sorted { $0.dueDate < $1.dueDate }
        case .priority:
            return base.sorted { $0.priority.focusScore > $1.priority.focusScore }
        case .title:
            return base.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    private var dueTodayTaskList: [LifeTask] {
        activeTasks.filter { !$0.isCompleted && Calendar.current.isDateInToday($0.dueDate) }
    }

    private var upcomingTaskList: [LifeTask] {
        let now = Date(); let cal = Calendar.current
        return activeTasks.filter { !$0.isCompleted && $0.dueDate > now && !cal.isDateInToday($0.dueDate) }
    }

    private var completedTaskList: [LifeTask] {
        tasks.filter { $0.deletedAt == nil && $0.isCompleted }
    }

    private var overdueTaskList: [LifeTask] {
        activeTasks.filter { $0.isOverdue }
    }

    private var documentTasks: [LifeTask] {
        tasks
            .filter { $0.deletedAt == nil && $0.hasDocument }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var moneyCurrencyCode: String {
        MoneyCurrency.normalized(appMoneyCurrencyCode)
    }

    private var moneySummary: MoneyMonthlySummary {
        MoneyAnalytics.monthlySummary(for: Date(), entries: moneyEntries, tasks: tasks, currencyCode: moneyCurrencyCode)
    }

    private var moneyPreviousSummary: MoneyMonthlySummary {
        let previous = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return MoneyAnalytics.monthlySummary(for: previous, entries: moneyEntries, tasks: tasks, currencyCode: moneyCurrencyCode)
    }

    private var moneyCategoryTotals: [MoneyCategoryTotal] {
        MoneyAnalytics.categoryTotals(for: Date(), entries: moneyEntries, tasks: tasks, currencyCode: moneyCurrencyCode)
    }

    private var moneySpendingCategoryTotals: [MoneyCategoryTotal] {
        moneyCategoryTotals
            .filter { $0.kind == .expense || $0.kind == .debtPayment }
            .filter { $0.actual > 0 || $0.planned > 0 }
    }

    private var moneyPlannedBills: [MoneyBillSnapshot] {
        MoneyAnalytics.plannedBills(for: Date(), tasks: tasks, currencyCode: moneyCurrencyCode)
    }

    private var moneyProjectionPoints: [MoneyProjectionPoint] {
        MoneyAnalytics.projectionPoints(
            from: Date(),
            days: 30,
            entries: moneyEntries,
            tasks: tasks,
            currencyCode: moneyCurrencyCode
        )
    }

    private var moneyProjectedMonthEndBalance: Double {
        moneyProjectionPoints.last?.balance ?? moneySummary.actualRemaining
    }

    private var moneyOpeningBalance: Double {
        moneyProjectionPoints.first?.balance ?? moneyPreviousSummary.actualRemaining
    }

    private var moneyLowBalanceThreshold: Double {
        if moneySummary.plannedIncome > 0 {
            return moneySummary.plannedIncome * 0.38
        }
        if moneyProjectedMonthEndBalance < 0 || moneyOpeningBalance < 0 {
            return 0
        }
        return max(moneyProjectedMonthEndBalance * 0.65, moneyOpeningBalance * 0.45, 1)
    }

    private var moneyDaysLeftInMonth: Int {
        let calendar = Calendar.current
        let interval = MoneyAnalytics.monthInterval(containing: Date(), calendar: calendar)
        let today = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: interval.end)
        return max(0, calendar.dateComponents([.day], from: today, to: end).day ?? 0)
    }

    private func taskList(for kind: BetaSummaryKind) -> [LifeTask] {
        switch kind {
        case .dueToday: dueTodayTaskList
        case .upcoming: upcomingTaskList
        case .completed: completedTaskList
        case .overdue: overdueTaskList
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let phase: String
        switch hour {
        case 0..<12: phase = "Good morning"
        case 12..<17: phase = "Good afternoon"
        default: phase = "Good evening"
        }
        let name = nickname.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? phase : "\(phase), \(name)"
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: Date())
    }

    private var streakCurrent: Int {
        let cal = Calendar.current
        let days = Set(tasks.compactMap(\.completedAt).map { cal.startOfDay(for: $0) })
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private var streakBest: Int {
        let cal = Calendar.current
        let days = Set(tasks.compactMap(\.completedAt).map { cal.startOfDay(for: $0) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<days.count {
            if let next = cal.date(byAdding: .day, value: 1, to: days[i - 1]), next == days[i] {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    private var streakWeek: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekAgo = cal.date(byAdding: .day, value: -6, to: today) else { return 0 }
        let days = Set(tasks.compactMap(\.completedAt).map { cal.startOfDay(for: $0) })
        return days.filter { $0 >= weekAgo && $0 <= today }.count
    }

    private var streakSubtitle: String {
        switch streakCurrent {
        case 0: return "Complete a task today\nto start your streak."
        case 1: return "Great start! You've completed\na task 1 day in a row."
        default: return "You've completed a task\n\(streakCurrent) days in a row."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                greetingHeader
                BetaBrandBlock()
                if overdue > 0 && isAlertBannerVisible {
                    BetaAlertBanner(isVisible: $isAlertBannerVisible, onAIInsightsTap: openMoneyAIInsights)
                }
                streakHeroPager
                BetaDashboardStatsGrid(
                    dueToday: dueToday,
                    upcoming: upcoming,
                    completed: completed,
                    overdue: overdue,
                    trends: metricTrends,
                    onSelectKind: { selectedSummaryKind = $0 }
                )
                    .padding(.bottom, -4)
                BetaDashboardQuickActionsSection(
                    items: visibleQuickActions,
                    onCustomize: { isShowingCustomize = true }
                )
                BetaDashboardDailyFocusSection(
                    dailyFocusTasks: dailyFocusTasks,
                    dailyFocusCountLabel: dailyFocusCountLabel,
                    focusSortOrder: focusSortOrder,
                    todayFocusProgress: todayFocusProgress,
                    customCategories: customCategories,
                    onToggleCompletion: toggleFocusCompletion,
                    onEdit: { editingTask = $0 },
                    onDelete: deleteFocusTask,
                    onPresentSortSheet: { isShowingFocusSortSheet = true },
                    onResetMyDay: resetMyDay,
                    onRescheduleOverdue: rescheduleOverdue
                )
                BetaDashboardInboxSection(
                    inboxItems: inboxItems,
                    onQuickCapture: { onPresentSheet?(.quickCapture) },
                    onVoiceCapture: { onPresentSheet?(.voiceCapture) },
                    onOpenInbox: { onPresentSheet?(.inbox) }
                )
                BetaDashboardRecentDocsSection(
                    documentTasks: documentTasks,
                    customCategories: customCategories
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $selectedSummaryKind) { kind in
            BetaStatSummarySheet(kind: kind)
        }
        .sheet(item: $editingTask) { task in
            NewTaskView(task: task)
        }
        .sheet(isPresented: $isShowingFocusTimer) {
            FocusTimerSheet()
        }
        .sheet(isPresented: $isShowingFocusSortSheet) {
            DailyFocusSortSheet(selectedOrder: $focusSortOrder)
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingCustomize) {
            QuickActionsCustomizeSheet(
                showPlanMyDay: $showPlanMyDay,
                showHabits: $showHabits,
                showReview: $showReview,
                showFocusTimer: $showFocusTimer,
                showNewTask: $showNewTask,
                showVoiceCapture: $showVoiceCaptureAction,
                showInbox: $showInboxAction,
                showTemplates: $showTemplates,
                showAvailability: $showAvailability,
                showCalendar: $showCalendar,
                showStatistics: $showStatistics,
                showDocuments: $showDocuments,
                showImport: $showImport,
                showExport: $showExport,
                showEmail: $showEmail,
                showBill: $showBill,
                showMedication: $showMedication,
                showBudget: $showBudget,
                showCheckup: $showCheckup,
                showAISuggestions: $showAISuggestions,
                showSmartSchedule: $showSmartSchedule
            )
        }
        .sheet(isPresented: $isShowingMoneyAIInsights) {
            MoneyAIInsightsDetailView(
                summary: moneySummary,
                categoryTotals: moneyCategoryTotals,
                spendingCategoryTotals: moneySpendingCategoryTotals,
                plannedBills: moneyPlannedBills,
                projectionPoints: moneyProjectionPoints,
                projectedBalance: moneyProjectedMonthEndBalance,
                daysLeft: moneyDaysLeftInMonth,
                currencyCode: moneyCurrencyCode,
                lowBalanceThreshold: moneyLowBalanceThreshold,
                month: Date(),
                isPremium: subscriptionManager.tier >= .standard
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Greeting header

    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.betaGreeting)
                    .foregroundStyle(BetaPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(dateLabel)
                    .font(.betaCaption(13, weight: .medium))
                    .foregroundStyle(BetaPalette.secondaryText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                headerCircleButton(icon: "chart.line.uptrend.xyaxis", showsDot: false) {
                    onOpenStatistics?()
                }
                .accessibilityLabel("Open statistics")

                Button {
                    onOpenSettings?()
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatarView(size: 40, avatarVersion: avatarVersion)
                        Circle()
                            .fill(Color(hex: 0xEF4444))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .offset(x: 1, y: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
            }
        }
    }

    private func headerCircleButton(icon: String, showsDot: Bool, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(filled ? AnyShapeStyle(BetaPalette.accentSoft) : AnyShapeStyle(Color.white))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BetaPalette.accent)

                if showsDot {
                    Circle()
                        .fill(Color(hex: 0xEF4444))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 13, y: 13)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Brand block

    // MARK: Productivity hero pager

    private var weeklyCompletionCounts: [Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekAgo = cal.date(byAdding: .day, value: -6, to: today) else {
            return Array(repeating: 0, count: 7)
        }
        var counts = Array(repeating: 0, count: 7)
        for task in tasks {
            guard let completedAt = task.completedAt else { continue }
            let day = cal.startOfDay(for: completedAt)
            if day >= weekAgo && day <= today,
               let diff = cal.dateComponents([.day], from: weekAgo, to: day).day,
               diff >= 0 && diff < 7 {
                counts[diff] += 1
            }
        }
        return counts
    }

    private var streakHeroPager: some View {
        let canPresent = onPresentSheet != nil
        let isUltimate = subscriptionManager.tier >= .ultimate
        return HeroPager(
            pages: [
                AnyView(TodayPlanHeroCard(
                    dueToday: dueToday,
                    upcoming: upcoming,
                    overdue: overdue,
                    canPresentSheet: canPresent,
                    onPlanMyDay: { onPresentSheet?(.planMyDay) },
                    onOpenAI: openMoneyAIInsights
                )),
                AnyView(WeeklyRhythmCard(
                    counts: weeklyCompletionCounts,
                    streakWeek: streakWeek,
                    canOpenReview: canPresent,
                    onOpenReview: { onPresentSheet?(.review) }
                )),
                AnyView(NextMoveHeroCard(
                    focusCount: focusTasks.count,
                    activeCount: activeTasks.count,
                    completedCount: completedTaskList.count,
                    overdue: overdue,
                    upcoming: upcoming,
                    dueToday: dueToday,
                    canPresentSheet: canPresent,
                    onReview: { onPresentSheet?(.review) }
                )),
                AnyView(StreakHeroCard(
                    streakCurrent: streakCurrent,
                    streakBest: streakBest,
                    streakWeek: streakWeek,
                    streakSubtitle: streakSubtitle,
                    canPresentSheet: canPresent,
                    onViewStreaks: { onPresentSheet?(.streaks) }
                )),
                AnyView(UpgradeHeroCard(
                    isUltimate: isUltimate,
                    canPresentSheet: canPresent,
                    onSeePlans: { onPresentSheet?(.paywall) }
                ))
            ],
            isPremium: subscriptionManager.tier >= .standard
        )
    }

    private func openMoneyAIInsights() {
        guard subscriptionManager.tier >= .standard else {
            onPresentSheet?(.paywall)
            return
        }
        isShowingMoneyAIInsights = true
    }



    // MARK: Quick Actions

    private var visibleQuickActions: [BetaQuickAction] {
        let isStandard = subscriptionManager.tier >= .standard
        let isUltimate = subscriptionManager.tier >= .ultimate
        var items: [BetaQuickAction] = []

        if showPlanMyDay {
            let locked = !isStandard
            items.append(.init(id: "planMyDay", title: "Plan My Day", subtitle: "Daily ritual",
                               icon: "sun.max.fill", iconBg: BetaPalette.qaPlanBg, iconTint: BetaPalette.qaPlanTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.planMyDay)
            })
        }
        if showHabits {
            let locked = !isStandard
            items.append(.init(id: "habits", title: "Habits", subtitle: "Streaks",
                               icon: "flame.fill", iconBg: BetaPalette.qaHabitsBg, iconTint: BetaPalette.qaHabitsTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.streaks)
            })
        }
        if showReview {
            let locked = !isStandard
            items.append(.init(id: "review", title: "Review", subtitle: "Progress",
                               icon: "chart.bar.fill", iconBg: BetaPalette.qaReviewBg, iconTint: BetaPalette.qaReviewTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.review)
            })
        }
        if showFocusTimer {
            items.append(.init(id: "focusTimer", title: "Focus Timer", subtitle: "Deep work",
                               icon: "timer", iconBg: BetaPalette.qaFocusBg, iconTint: BetaPalette.qaFocusTint) {
                isShowingFocusTimer = true
            })
        }
        if showAISuggestions {
            let locked = !isUltimate
            items.append(.init(id: "aiSuggestions", title: "AI Suggestions", subtitle: "Smart focus",
                               icon: "sparkles", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.aiSuggestions)
            })
        }
        if showSmartSchedule {
            let locked = !isUltimate
            items.append(.init(id: "smartSchedule", title: "Schedule", subtitle: "Optimize day",
                               icon: "brain.head.profile", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.smartScheduling)
            })
        }
        if showNewTask {
            items.append(.init(id: "newTask", title: "Text Capture", subtitle: "Inbox first",
                               icon: "square.and.pencil", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint) {
                onPresentSheet?(.newTask)
            })
        }
        if showVoiceCaptureAction {
            items.append(.init(id: "voiceCapture", title: "Voice Capture", subtitle: "Start recording",
                               icon: "mic.fill", iconBg: BetaPalette.qaPlanBg, iconTint: BetaPalette.qaPlanTint) {
                onPresentSheet?(.voiceCapture)
            })
        }
        if showInboxAction {
            let subtitle = inboxItems.isEmpty ? "Capture first" : "\(inboxItems.count) waiting"
            items.append(.init(id: "inbox", title: "Inbox", subtitle: subtitle,
                               icon: "tray.full", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint) {
                onPresentSheet?(.inbox)
            })
        }
        if showTemplates {
            items.append(.init(id: "templates", title: "Templates", subtitle: "Smart shortcuts",
                               icon: "sparkles", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint) {
                onPresentSheet?(.templates)
            })
        }
        if showAvailability {
            items.append(.init(id: "availability", title: "Availability", subtitle: "Share times",
                               icon: "calendar.badge.clock", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint) {
                onPresentSheet?(.availability)
            })
        }
        if showCalendar {
            items.append(.init(id: "calendar", title: "Calendar", subtitle: "See dates",
                               icon: "calendar", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint) {
                onNavigate?(.calendar)
            })
        }
        if showStatistics {
            items.append(.init(id: "statistics", title: "Statistics", subtitle: "See trends",
                               icon: "chart.bar.xaxis", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint) {
                onOpenStatistics?()
            })
        }
        if showDocuments {
            items.append(.init(id: "documents", title: "Documents", subtitle: "Search files",
                               icon: "doc.text.magnifyingglass", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint) {
                onNavigate?(.documents)
            })
        }
        if showImport {
            items.append(.init(id: "import", title: "Import", subtitle: "From file",
                               icon: "tray.and.arrow.down", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint) {
                onNavigate?(.importTasks)
            })
        }
        if showExport {
            items.append(.init(id: "export", title: "Export", subtitle: "Share/AirDrop",
                               icon: "square.and.arrow.up", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint) {
                onNavigate?(.exportTasks)
            })
        }
        if showEmail {
            items.append(.init(id: "email", title: "Email follow-up", subtitle: "Use template",
                               icon: "envelope.badge", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint) {
                onPresentSheet?(.template(id: "email"))
            })
        }
        if showBill {
            items.append(.init(id: "bill", title: "Pay bill", subtitle: "Monthly",
                               icon: "creditcard", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint) {
                onPresentSheet?(.template(id: "bill"))
            })
        }
        if showMedication {
            items.append(.init(id: "medication", title: "Medication", subtitle: "Daily routine",
                               icon: "cross.case", iconBg: BetaPalette.qaDangerBg, iconTint: BetaPalette.qaDangerTint) {
                onPresentSheet?(.template(id: "medication"))
            })
        }
        if showBudget {
            items.append(.init(id: "budget", title: "Money", subtitle: "Budget & actuals",
                               icon: "chart.pie", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint) {
                onNavigate?(.money)
            })
        }
        if showCheckup {
            items.append(.init(id: "checkup", title: "Health check", subtitle: "Book visit",
                               icon: "heart.text.square", iconBg: BetaPalette.qaDangerBg, iconTint: BetaPalette.qaDangerTint) {
                onPresentSheet?(.template(id: "checkup"))
            })
        }
        return items
    }

    // MARK: Daily Focus


    private func toggleFocusCompletion(_ task: LifeTask) {
        let pending = withAnimation(.snappy(duration: 0.24)) {
            TaskLifecycleManager.beginToggleCompletion(for: task)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            TaskLifecycleManager.finishToggleCompletion(pending, in: modelContext, customCategories: customCategories)
            FocusActivityController.shared.update(for: task)
        }
    }

    private func deleteFocusTask(_ task: LifeTask) {
        FocusActivityController.shared.stop(matching: task.id)
        _ = TaskLifecycleManager.delete(task, in: modelContext)
    }

    private func resetMyDay() {
        let openTasks = activeTasks.filter { !$0.isCompleted }
        let focusIDs = Set(focusTasks.prefix(5).map(\.id))
        let plan = DailyFocusPlanner.resetSchedule(for: openTasks, focusIDs: focusIDs)
        TaskLifecycleManager.applySchedule(plan, in: modelContext, customCategories: customCategories)
    }

    private func rescheduleOverdue() {
        let openTasks = activeTasks.filter { !$0.isCompleted }
        let plan = DailyFocusPlanner.overdueReschedulePlan(for: openTasks)
        TaskLifecycleManager.applySchedule(plan, in: modelContext, customCategories: customCategories)
    }
}

