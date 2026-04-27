//
//  BetaDashboardView.swift
//  LifeTrack
//

import Combine
import SwiftData
import SwiftUI

// MARK: - Animated background

/// Floating water-like circles drifting behind the beta dashboard.
/// Uses plain `Circle` views driven by a single looping animation so
/// Core Animation handles the motion off the main thread — much cheaper
/// than a `TimelineView` + `Canvas` redraw every frame.
struct BetaAnimatedShapesBackground: View {
    var opacity: Double

    @State private var animate = false

    var body: some View {
        ZStack {
            BetaPalette.appBackground

            if opacity > 0.01 {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height

                    ZStack {
                        shape(color: BetaPalette.heroTop, size: 360)
                            .offset(
                                x: animate ? w * 0.10 : -w * 0.05,
                                y: animate ? h * 0.20 : h * 0.05
                            )

                        shape(color: BetaPalette.peach.opacity(0.55), size: 280)
                            .offset(
                                x: animate ? w * 0.72 : w * 0.88,
                                y: animate ? h * 0.18 : h * 0.32
                            )

                        shape(color: BetaPalette.peachDeep.opacity(0.5), size: 300)
                            .offset(
                                x: animate ? w * 0.65 : w * 0.80,
                                y: animate ? h * 0.82 : h * 0.70
                            )

                        shape(color: BetaPalette.heroMid, size: 240)
                            .offset(
                                x: animate ? w * 0.15 : w * 0.05,
                                y: animate ? h * 0.70 : h * 0.85
                            )
                    }
                    .frame(width: w, height: h)
                    .blur(radius: 55)
                    .opacity(opacity)
                }
                .allowsHitTesting(false)
                .onAppear {
                    guard !animate else { return }
                    withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                }
            }
        }
    }

    private func shape(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}


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

// MARK: - LifeTrack Logo Mark

private struct BetaLogoMark: View {
    var body: some View {
        ZStack {
            // Back leaf — pink/peach, smaller, peeks from bottom-right
            BetaLeafShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFFC5B5), Color(hex: 0xF88AA8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22, height: 26)
                .rotationEffect(.degrees(35))
                .offset(x: 10, y: 7)
                .shadow(color: Color(hex: 0xE06988).opacity(0.25), radius: 3, y: 1)

            // Front leaf — purple, main body
            BetaLeafShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xA78BFA),
                            Color(hex: 0x7C6BEE),
                            Color(hex: 0x4F3FCB)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Inner highlight vein
                    BetaLeafShape()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                        .blur(radius: 0.4)
                )
                .frame(width: 30, height: 36)
                .rotationEffect(.degrees(-18))
                .offset(x: -2, y: -1)
                .shadow(color: BetaPalette.accentDeep.opacity(0.35), radius: 5, y: 2)
        }
        .frame(width: 42, height: 42)
    }
}


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
                brandBlock
                if overdue > 0 && isAlertBannerVisible {
                    alertBanner
                }
                streakHeroPager
                statsGrid
                    .padding(.bottom, -4)
                quickActionsSection
                dailyFocusSection
                inboxSection
                recentDocumentsSection
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

    private var brandBlock: some View {
        HStack(spacing: 8) {
            BetaLogoMark()
            Text("LifeTrack")
                .font(.betaBrand)
                .foregroundStyle(BetaPalette.primaryText)
        }
    }

    // MARK: Alert banner

    private var alertBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BetaPalette.alertIconBg)
                    .frame(width: 30, height: 30)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BetaPalette.alertIcon)
            }

            Text("You can still make this dashboard useful today.")
                .font(.betaCaption(13, weight: .medium))
                .foregroundStyle(BetaPalette.alertText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Button {
                openMoneyAIInsights()
            } label: {
                Label("AI", systemImage: "brain.head.profile")
                    .font(.betaCaption(11, weight: .bold))
                    .foregroundStyle(BetaPalette.alertText)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(BetaPalette.heroGlassFill, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open AI money insights")

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isAlertBannerVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BetaPalette.alertText.opacity(0.75))
                    .frame(width: 24, height: 24)
                    .background(BetaPalette.heroGlassFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss dashboard alert")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            BetaPalette.alertBg,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

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
        HeroPager(
            pages: [
                AnyView(todayPlanHeroCard),
                AnyView(weeklyRhythmCard),
                AnyView(nextMoveHeroCard),
                AnyView(streakHeroCard),
                AnyView(upgradeHeroCard)
            ],
            isPremium: subscriptionManager.tier >= .standard
        )
    }

    private var upgradeHeroCard: some View {
        let isUltimate = subscriptionManager.tier >= .ultimate
        let features: [(String, String)] = [
            ("brain.head.profile", "AI Suggestions"),
            ("calendar.badge.clock", "Smart Schedule"),
            ("icloud.fill", "Auto Backups"),
            ("timer", "Focus Timer"),
            ("flame.fill", "Habit Streaks"),
            ("doc.badge.plus", "Templates"),
        ]
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BetaPalette.heroShellStroke, lineWidth: 1)
                }
                .shadow(color: BetaPalette.heroShadow, radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 0) {
                // — top row: title + crown
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isUltimate ? "You're Ultimate" : "Unlock Ultimate")
                            .font(.betaHeroTitle)
                            .foregroundStyle(BetaPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(isUltimate
                             ? "Every premium feature unlocked."
                             : "AI, scheduling, backups & more.")
                            .font(.betaBody(13))
                            .foregroundStyle(BetaPalette.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [BetaPalette.accent.opacity(0.18), BetaPalette.accentDeep.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: isUltimate ? "crown.fill" : "sparkles")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [BetaPalette.accent, BetaPalette.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }

                Spacer(minLength: 12)

                // — feature chips grid
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(features, id: \.0) { icon, label in
                        HStack(spacing: 5) {
                            Image(systemName: icon)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(BetaPalette.accent)
                            Text(label)
                                .font(.betaCaption(10, weight: .semibold))
                                .foregroundStyle(BetaPalette.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BetaPalette.heroGlassFill.opacity(isUltimate ? 1 : 0.9), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(BetaPalette.heroGlassStroke, lineWidth: 0.7)
                        }
                    }
                }

                Spacer(minLength: 14)

                // — CTA button
                Button {
                    if !isUltimate { onPresentSheet?(.paywall) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isUltimate ? "checkmark.seal.fill" : "crown.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isUltimate ? "Your Plan" : "See Plans")
                            .font(.betaBody(14, weight: .semibold))
                        if !isUltimate {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isUltimate || onPresentSheet == nil)
                .opacity(isUltimate ? 0.8 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var weeklyRhythmCard: some View {
        let counts = weeklyCompletionCounts
        let maxV = max(counts.max() ?? 0, 1)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekAgo = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let symbols = cal.veryShortWeekdaySymbols

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BetaPalette.heroShellStroke, lineWidth: 1)
                }
                .shadow(color: BetaPalette.heroShadow, radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 9) {
                Text("This Week's Rhythm")
                    .font(.betaHeroTitle)
                    .foregroundStyle(BetaPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(streakWeek > 0
                     ? "You finished a task on \(streakWeek) of 7 days."
                     : "No completions yet.\nFinish one to start the rhythm.")
                    .font(.betaBody(13))
                    .foregroundStyle(BetaPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        let day = cal.date(byAdding: .day, value: i, to: weekAgo) ?? today
                        let isToday = cal.isDate(day, inSameDayAs: today)
                        let heightValue = max(6, CGFloat(counts[i]) / CGFloat(maxV) * 58)
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: isToday
                                            ? [BetaPalette.accent, BetaPalette.accentDeep]
                                            : [BetaPalette.accent.opacity(0.55), BetaPalette.accent.opacity(0.28)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: heightValue)
                            Text(symbols[cal.component(.weekday, from: day) - 1])
                                .font(.system(size: 10, weight: isToday ? .bold : .medium))
                                .foregroundStyle(isToday ? BetaPalette.primaryText : BetaPalette.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 78)

                Button {
                    onPresentSheet?(.review)
                } label: {
                    HStack(spacing: 6) {
                        Text("Open Review")
                            .font(.betaBody(14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(onPresentSheet == nil)
                .opacity(onPresentSheet == nil ? 0.65 : 1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var todayPlanHeroCard: some View {
        let subtitle: String
        if overdue > 0 {
            subtitle = "\(overdue) overdue task\(overdue == 1 ? "" : "s") need a decision before new work."
        } else if dueToday > 0 {
            subtitle = "\(dueToday) task\(dueToday == 1 ? "" : "s") due today. Start with the clearest next step."
        } else {
            subtitle = "No tasks due today. Pull one upcoming item forward if you want momentum."
        }

        return productivityHeroShell {
            VStack(alignment: .leading, spacing: 9) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Plan")
                        .font(.betaHeroTitle)
                        .foregroundStyle(BetaPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(subtitle)
                        .font(.betaBody(13))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    heroMetricPill(
                        title: "Due",
                        value: dueToday.formatted(),
                        subtitle: "today",
                        tint: BetaPalette.statDueToday,
                        symbolName: "sun.max.fill"
                    )
                    heroMetricPill(
                        title: "Next",
                        value: upcoming.formatted(),
                        subtitle: "upcoming",
                        tint: BetaPalette.statUpcoming,
                        symbolName: "calendar"
                    )
                    heroMetricPill(
                        title: "Risk",
                        value: overdue.formatted(),
                        subtitle: "overdue",
                        tint: BetaPalette.statOverdue,
                        symbolName: "exclamationmark.triangle.fill"
                    )
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    heroActionButton(title: "Plan My Day", systemImage: "wand.and.stars") {
                        onPresentSheet?(.planMyDay)
                    }
                    .disabled(onPresentSheet == nil)
                    .opacity(onPresentSheet == nil ? 0.65 : 1)

                    Spacer(minLength: 0)

                    heroInlineActionButton(title: "AI", systemImage: "brain.head.profile") {
                        openMoneyAIInsights()
                    }
                }
            }
        }
    }

    private var nextMoveHeroCard: some View {
        let completionShare = activeTasks.isEmpty ? 0 : Int((Double(completedTaskList.count) / Double(activeTasks.count)) * 100)
        let subtitle: String
        if overdue > 0 {
            subtitle = "Clear or reschedule the backlog so today feels honest."
        } else if upcoming > dueToday {
            subtitle = "Your next seven days are loaded. Decide what deserves attention now."
        } else {
            subtitle = "Your queue is light. Review progress and keep priorities tidy."
        }

        return productivityHeroShell {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 9) {
                    heroProgressRow(
                        title: "Open queue",
                        value: "\(focusTasks.count)",
                        progress: activeTasks.isEmpty ? 0 : Double(focusTasks.count) / Double(max(activeTasks.count, 1)),
                        tint: BetaPalette.accent
                    )
                    heroProgressRow(
                        title: "Completed share",
                        value: "\(completionShare)%",
                        progress: Double(completionShare) / 100,
                        tint: BetaPalette.statCompleted
                    )
                    heroProgressRow(
                        title: "Overdue pressure",
                        value: "\(overdue)",
                        progress: min(Double(overdue) / Double(max(focusTasks.count, 1)), 1),
                        tint: BetaPalette.statOverdue
                    )
                }
                .padding(10)
                .background(BetaPalette.heroGlassFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Next Best Move")
                            .font(.betaHeroTitle)
                            .foregroundStyle(BetaPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)

                        Spacer(minLength: 6)

                        heroInlineActionButton(title: "Review", systemImage: "chart.bar.fill") {
                            onPresentSheet?(.review)
                        }
                        .disabled(onPresentSheet == nil)
                        .opacity(onPresentSheet == nil ? 0.65 : 1)
                    }

                    Text(subtitle)
                        .font(.betaCaption(12, weight: .medium))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func openMoneyAIInsights() {
        guard subscriptionManager.tier >= .standard else {
            onPresentSheet?(.paywall)
            return
        }
        isShowingMoneyAIInsights = true
    }


    // MARK: Streak hero card

    private var streakHeroCard: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BetaPalette.heroShellStroke, lineWidth: 1)
                }
                .shadow(color: BetaPalette.heroShadow, radius: 18, y: 8)

            // Illustration on right — extends down so the stone reads above the stats row
            HStack {
                Spacer(minLength: 110)
                StreakHeroIllustration()
                    .scaleEffect(0.82)
                    .frame(width: 180, height: 180)
                    .padding(.trailing, -12)
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Left text + docked stats
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(streakCurrent)-day streak")
                        .font(.betaHeroTitle)
                        .foregroundStyle(BetaPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(streakSubtitle)
                        .font(.betaBody(14))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        onPresentSheet?(.streaks)
                    } label: {
                        HStack(spacing: 6) {
                            Text("View Streaks")
                                .font(.betaBody(14, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: Capsule()
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(onPresentSheet == nil)
                    .opacity(onPresentSheet == nil ? 0.65 : 1)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                Spacer(minLength: 6)

                // Docked stats row
                streakStatsRow
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var streakStatsRow: some View {
        HStack(spacing: 0) {
            streakStatCell(icon: "flame.fill", iconTint: BetaPalette.accent, value: "\(streakCurrent)", unit: "Day", label: "Current")
            Divider().frame(height: 44).overlay(BetaPalette.faintBorder)
            streakStatCell(icon: "star.fill", iconTint: BetaPalette.accent, value: "\(streakBest)", unit: "Days", label: "Best")
            Divider().frame(height: 44).overlay(BetaPalette.faintBorder)
            streakStatCell(icon: "calendar", iconTint: BetaPalette.accent, value: "\(streakWeek)/7", unit: "Days", label: "This Week")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BetaPalette.heroGlassFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BetaPalette.heroGlassStroke, lineWidth: 1)
        }
    }


    // MARK: Stats grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            let trends = metricTrends
            statCard(
                icon: "sun.max.fill", iconTint: BetaPalette.statDueToday, iconBg: BetaPalette.statDueTodayBg,
                title: "Due Today", value: dueToday, subtitle: "7-day due",
                waveColor: BetaPalette.waveDueToday, series: trends.dueToday,
                action: { selectedSummaryKind = .dueToday }
            )
            statCard(
                icon: "calendar", iconTint: BetaPalette.statUpcoming, iconBg: BetaPalette.statUpcomingBg,
                title: "Upcoming", value: upcoming, subtitle: "Next week",
                waveColor: BetaPalette.waveUpcoming, series: trends.upcoming,
                action: { selectedSummaryKind = .upcoming }
            )
            statCard(
                icon: "checkmark.seal.fill", iconTint: BetaPalette.statCompleted, iconBg: BetaPalette.statCompletedBg,
                title: "Completed", value: completed, subtitle: "7-day done",
                waveColor: BetaPalette.waveCompleted, series: trends.completed,
                action: { selectedSummaryKind = .completed }
            )
            statCard(
                icon: "exclamationmark.triangle.fill", iconTint: BetaPalette.statOverdue, iconBg: BetaPalette.statOverdueBg,
                title: "Overdue", value: overdue, subtitle: "Backlog",
                waveColor: BetaPalette.waveOverdue, series: trends.overdue,
                action: { selectedSummaryKind = .overdue }
            )
        }
    }

    private func statCard(icon: String, iconTint: Color, iconBg: Color, title: String, value: Int, subtitle: String, waveColor: Color, series: [Double], action: (() -> Void)? = nil) -> some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconTint)
            }

            Text(title)
                .font(.betaCaption(11, weight: .semibold))
                .foregroundStyle(BetaPalette.lightCardSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(formattedValue(value))
                .font(.betaMetric)
                .foregroundStyle(BetaPalette.lightCardPrimaryText)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            Text(subtitle)
                .font(.betaCaption(10, weight: .medium))
                .foregroundStyle(BetaPalette.lightCardTertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            ZStack(alignment: .bottom) {
                StatSparkline(values: series, closed: true)
                    .fill(
                        LinearGradient(
                            colors: [
                                waveColor.opacity(0.55),
                                waveColor.opacity(0.22),
                                waveColor.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                StatSparkline(values: series, closed: false)
                    .stroke(waveColor, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 32)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BetaPalette.lightCardFill)
                .shadow(color: BetaPalette.lightCardShadow, radius: 10, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            LifeTrackHaptics.lightImpact()
            action?()
        }
    }

    private func formattedValue(_ n: Int) -> String {
        if n < 1000 {
            return "\(n)"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Quick Actions")
                    .font(.betaSection)
                    .foregroundStyle(BetaPalette.primaryText)
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BetaPalette.accentDeep)

                Spacer(minLength: 0)

                Button { isShowingCustomize = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("Customize")
                            .font(.betaCaption(12, weight: .semibold))
                    }
                    .foregroundStyle(BetaPalette.lightChromeText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(BetaPalette.lightCardFill)
                            .shadow(color: BetaPalette.lightCardShadow, radius: 4, y: 2)
                    )
                    .overlay {
                        Capsule().stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
            }

            quickActionsLayout
        }
    }

    @ViewBuilder
    private var quickActionsLayout: some View {
        let items = visibleQuickActions
        if items.count > 4 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        quickActionTile(item: item)
                            .frame(width: 128)
                    }
                }
                .padding(.vertical, 2)
            }
        } else {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    quickActionTile(item: item)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

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

    private func quickActionTile(item: BetaQuickAction) -> some View {
        Button(action: item.action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Circle()
                        .fill(item.iconBg)
                        .frame(width: 30, height: 30)
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(item.iconTint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.betaBody(13, weight: .bold))
                        .foregroundStyle(BetaPalette.lightCardPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.subtitle)
                        .font(.betaCaption(11, weight: .medium))
                        .foregroundStyle(BetaPalette.lightCardSecondaryText)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BetaPalette.lightCardFill)
                    .shadow(color: BetaPalette.lightCardShadow, radius: 8, y: 3)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
            }
            .overlay(alignment: .topTrailing) {
                if item.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(BetaPalette.accentDeep, in: Circle())
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Daily Focus

    private var dailyFocusSection: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clear)
                .background(
                    DailyFocusBackdrop()
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BetaPalette.lightCardBorder, lineWidth: 1)
                }
                .shadow(color: BetaPalette.lightCardShadow, radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Daily Focus")
                        .font(.betaSection)
                        .foregroundStyle(BetaPalette.lightCardPrimaryText)

                    Text(dailyFocusCountLabel)
                        .font(.betaCaption(12, weight: .medium))
                        .foregroundStyle(BetaPalette.lightCardSecondaryText)

                    Spacer(minLength: 0)

                    dailyFocusSortButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                focusList
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
            }
        }
    }

    private var dailyFocusSortButton: some View {
        Button {
            isShowingFocusSortSheet = true
        } label: {
            HStack(spacing: 6) {
                Text(focusSortOrder.rawValue)
                    .font(.betaCaption(13, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightCardPrimaryText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BetaPalette.lightCardSecondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                ZStack(alignment: .leading) {
                    Capsule().fill(BetaPalette.lightCardFill)
                    if focusSortOrder == .today {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(BetaPalette.accent.opacity(0.24))
                                .frame(width: proxy.size.width * CGFloat(todayFocusProgress))
                        }
                    }
                }
            }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        focusSortOrder == .today ? BetaPalette.accent.opacity(0.24) : Color.clear,
                        lineWidth: 1
                    )
            }
            .shadow(color: BetaPalette.lightCardShadow, radius: 4, y: 2)
            .animation(.easeInOut(duration: 0.22), value: todayFocusProgress)
            .animation(.easeInOut(duration: 0.18), value: focusSortOrder)
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
    }

    private var focusList: some View {
        Group {
            if dailyFocusTasks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(BetaPalette.lightCardSecondaryText)
                    Text("Nothing in focus — you're all caught up.")
                        .font(.betaBody(14, weight: .medium))
                        .foregroundStyle(BetaPalette.lightCardSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(dailyFocusTasks) { task in
                        TaskRowView(
                            task: task,
                            onToggleCompletion: { toggleFocusCompletion(task) },
                            onEdit: { editingTask = task },
                            onDelete: { deleteFocusTask(task) },
                            categoryOption: task.categoryOption(customCategories: customCategories),
                            showsBorder: false
                        )
                        .contextMenu {
                            if FocusActivityController.shared.isPinned(task) {
                                Button(role: .destructive) {
                                    FocusActivityController.shared.stop()
                                } label: {
                                    Label("Unpin from Lock Screen", systemImage: "pin.slash")
                                }
                            } else if !task.isCompleted {
                                Button {
                                    FocusActivityController.shared.start(
                                        for: task,
                                        customCategories: customCategories
                                    )
                                } label: {
                                    Label("Pin to Lock Screen", systemImage: "pin")
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        betaFocusPlanningButton(
                            title: "Reset My Day",
                            symbol: "arrow.clockwise",
                            tint: BetaPalette.accent
                        ) { resetMyDay() }

                        betaFocusPlanningButton(
                            title: "Reschedule Overdue",
                            symbol: "calendar.badge.clock",
                            tint: BetaPalette.overdue
                        ) { rescheduleOverdue() }
                    }
                }
            }
        }
    }

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("Inbox")
                    .font(.betaSection)
                    .foregroundStyle(BetaPalette.primaryText)

                Image(systemName: "tray.full")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BetaPalette.accent)

                Spacer(minLength: 0)

                Text(inboxItems.isEmpty ? "Clear" : "\(inboxItems.count) open")
                    .font(.betaCaption(12, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightChromeText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(BetaPalette.lightCardFill, in: Capsule())
            }

            if inboxItems.isEmpty {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(BetaPalette.accent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "tray.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BetaPalette.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nothing waiting in inbox")
                            .font(.lifeTrack(.subheadline, weight: .semibold))
                            .foregroundStyle(BetaPalette.lightCardPrimaryText)
                        Text("Capture rough notes first, then turn them into structured tasks when you are ready.")
                            .font(.lifeTrack(.footnote, weight: .regular))
                            .foregroundStyle(BetaPalette.lightCardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
                }

                HStack(spacing: 10) {
                    inboxActionButton(
                        title: "Text Capture",
                        icon: "square.and.pencil",
                        iconBg: BetaPalette.qaAccentBg,
                        iconTint: BetaPalette.qaAccentTint
                    ) {
                        onPresentSheet?(.quickCapture)
                    }

                    inboxActionButton(
                        title: "Voice Capture",
                        icon: "mic.fill",
                        iconBg: BetaPalette.qaPlanBg,
                        iconTint: BetaPalette.qaPlanTint
                    ) {
                        onPresentSheet?(.voiceCapture)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(inboxItems.prefix(3))) { item in
                        Button {
                            onPresentSheet?(.inbox)
                        } label: {
                            BetaInboxPreviewRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if inboxItems.count > 3 {
                    Text("\(inboxItems.count - 3) more item\(inboxItems.count - 3 == 1 ? "" : "s") waiting in inbox.")
                        .font(.betaCaption(12, weight: .medium))
                        .foregroundStyle(BetaPalette.secondaryText)
                }

                HStack(spacing: 10) {
                    inboxActionButton(
                        title: "Open Inbox",
                        icon: "tray.full",
                        iconBg: BetaPalette.qaInfoBg,
                        iconTint: BetaPalette.qaInfoTint
                    ) {
                        onPresentSheet?(.inbox)
                    }

                    inboxActionButton(
                        title: "Capture More",
                        icon: "plus",
                        iconBg: BetaPalette.qaAccentBg,
                        iconTint: BetaPalette.qaAccentTint
                    ) {
                        onPresentSheet?(.quickCapture)
                    }
                }
            }
        }
    }

    private func inboxActionButton(
        title: String,
        icon: String,
        iconBg: Color,
        iconTint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(iconBg)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(iconTint)
                }

                Text(title)
                    .font(.betaBody(13, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightCardPrimaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("Recent Documents")
                    .font(.betaSection)
                    .foregroundStyle(BetaPalette.primaryText)

                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BetaPalette.tertiaryText)

                Spacer(minLength: 0)

                if !documentTasks.isEmpty {
                Text("\(documentTasks.count)")
                    .font(.betaCaption(12, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightChromeText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(BetaPalette.lightCardFill, in: Capsule())
                }
            }

            if documentTasks.isEmpty {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(BetaPalette.accent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BetaPalette.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("No documents yet")
                            .font(.lifeTrack(.subheadline, weight: .semibold))
                            .foregroundStyle(BetaPalette.lightCardPrimaryText)
                        Text("Attach a file from any task to keep supporting context nearby.")
                            .font(.lifeTrack(.footnote, weight: .regular))
                            .foregroundStyle(BetaPalette.lightCardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(documentTasks.prefix(3))) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            BetaRecentDocumentRow(
                                task: task,
                                categoryOption: task.categoryOption(customCategories: customCategories)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }


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

private struct BetaInboxPreviewRow: View {
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
                    .font(.lifeTrack(.subheadline, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightCardPrimaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(draft.resolvedDueDate.dayMonthString)
                    Text("•")
                    Text(item.source.title)
                }
                .font(.lifeTrack(.caption, weight: .medium))
                .foregroundStyle(BetaPalette.lightCardSecondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(BetaPalette.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
        }
    }

    private var sourceTint: Color {
        switch item.source {
        case .typed:
            BetaPalette.qaAccentTint
        case .voice:
            BetaPalette.qaPlanTint
        case .shared:
            BetaPalette.qaSuccessTint
        }
    }
}
