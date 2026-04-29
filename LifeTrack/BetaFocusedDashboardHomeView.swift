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

private enum BetaFocusedDashboardRoute: Hashable {
    case statistics
    case calendar
    case documents
    case taskData
    case money
}

private enum BetaFocusedDashboardTab: Hashable {
    case home
    case capture
    case focus
    case tools
}

private enum BetaFocusedDashboardScrollTarget: Hashable {
    case tools
}

private enum BetaFocusedDashboardTypography {
    static let greeting = Font.system(size: 22, weight: .regular, design: .serif)
    static let date = Font.system(size: 13, weight: .regular, design: .default)
    static let section = Font.system(size: 17, weight: .medium, design: .serif)
    static let heroTitle = Font.system(size: 29, weight: .semibold, design: .serif)
    static let statValue = Font.system(size: 25, weight: .regular, design: .serif)
    static let button = Font.system(size: 14.5, weight: .semibold, design: .default)
    static let body = Font.system(size: 12, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 10.5, weight: .regular, design: .default)
    static let chip = Font.system(size: 10.5, weight: .semibold, design: .default)
    static let nav = Font.system(size: 10.5, weight: .medium, design: .default)
    static let taskTitle = Font.system(size: 14.5, weight: .medium, design: .default)
}

private enum BetaFocusedDashboardPalette {
    static let backgroundTop = Color(hex: 0xFFF9F2)
    static let backgroundBottom = Color(hex: 0xF6EBDD)
    static let headerText = Color(hex: 0x2B231F)
    static let secondaryText = Color(hex: 0x8D847A)
    static let tertiaryText = Color(hex: 0xA89E94)
    static let cardBackground = Color.white.opacity(0.88)
    static let cardSecondary = Color(hex: 0xFFFDF9).opacity(0.96)
    static let softSurface = Color(hex: 0xFBF4EC)
    static let border = Color(hex: 0xE7DACB)
    static let softShadow = Color.black.opacity(0.06)

    static let heroAccent = Color(hex: 0xE56C4D)
    static let heroAccentDeep = Color(hex: 0xF48764)
    static let dueTodayTint = Color(hex: 0xD09A45)
    static let overdueTint = Color(hex: 0xDF7A66)
    static let completedTint = Color(hex: 0x8AA37D)
    static let progressTint = Color(hex: 0x7D966A)

    static let statsPillText = Color(hex: 0x6C4E35)
    static let statsPillBackground = Color(hex: 0xFFF5EA)
    static let navAccent = Color(hex: 0xE66A4C)

    static let captureTint = Color(hex: 0x2B7BC6)
    static let importExportTint = Color(hex: 0x7573B6)

    static let financeTint = Color(hex: 0x4D78AE)
    static let financeBackground = Color(hex: 0xEAF1FB)
    static let healthTint = Color(hex: 0xC06D58)
    static let healthBackground = Color(hex: 0xF8E8E1)
    static let workTint = Color(hex: 0x748C69)
    static let workBackground = Color(hex: 0xEDF4E7)
    static let homeTint = Color(hex: 0xC49A3E)
    static let homeBackground = Color(hex: 0xFBF0DA)
    static let personalTint = Color(hex: 0x8A74C6)
    static let personalBackground = Color(hex: 0xF0EBFA)
    static let otherTint = Color(hex: 0x80766F)
    static let otherBackground = Color(hex: 0xF2ECE6)

    static let warningTint = Color(hex: 0xBF7A2F)
    static let warningBackground = Color(hex: 0xFBF0DA)
    static let dangerBackground = Color(hex: 0xFAE6DF)
}

private struct BetaFocusedDashboardCategoryVisuals {
    let tint: Color
    let background: Color
}

private struct BetaFocusedDashboardPlanPreviewModel {
    let summary: String
    let detail: String
    let rescueCount: Int
    let busyBlockCount: Int
}

private enum BetaFocusedDashboardTaskHealthState {
    case recurringMissed
    case blocked
    case stale
    case needsDate

    var title: String {
        switch self {
        case .recurringMissed: "Recurring missed"
        case .blocked: "Blocked"
        case .stale: "Stale"
        case .needsDate: "Needs date"
        }
    }

    var symbolName: String {
        switch self {
        case .recurringMissed: "repeat.circle"
        case .blocked: "hand.raised.fill"
        case .stale: "clock.badge.exclamationmark"
        case .needsDate: "calendar.badge.exclamationmark"
        }
    }

    var tint: Color {
        switch self {
        case .recurringMissed:
            BetaFocusedDashboardPalette.overdueTint
        case .blocked:
            BetaFocusedDashboardPalette.warningTint
        case .stale:
            BetaFocusedDashboardPalette.secondaryText
        case .needsDate:
            BetaFocusedDashboardPalette.captureTint
        }
    }

    var background: Color {
        switch self {
        case .recurringMissed:
            BetaFocusedDashboardPalette.dangerBackground
        case .blocked:
            BetaFocusedDashboardPalette.warningBackground
        case .stale:
            BetaFocusedDashboardPalette.otherBackground
        case .needsDate:
            BetaFocusedDashboardPalette.financeBackground
        }
    }
}

private extension LifeTask {
    func betaFocusedHealthState(referenceDate: Date = Date(), calendar: Calendar = .current) -> BetaFocusedDashboardTaskHealthState? {
        guard !isDeleted, !isCompleted else { return nil }

        if isOverdue, recurrence != .none {
            return .recurringMissed
        }

        let blockerText = ([notes] + Array(advancedFields.values))
            .joined(separator: " ")
            .lowercased()

        if blockerText.contains("blocked") ||
            blockerText.contains("waiting") ||
            blockerText.contains("on hold") ||
            blockerText.contains("stuck") ||
            blockerText.contains("depends") {
            return .blocked
        }

        let staleCutoff = calendar.date(byAdding: .day, value: -14, to: referenceDate) ?? referenceDate
        if updatedAt < staleCutoff || dueDate < staleCutoff {
            return .stale
        }

        let dueComponents = calendar.dateComponents([.hour, .minute], from: dueDate)
        let daysFromCreateToDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: createdAt),
            to: calendar.startOfDay(for: dueDate)
        ).day

        if daysFromCreateToDue == 1,
           dueComponents.hour == 9,
           dueComponents.minute == 0,
           priority == .normal,
           recurrence == .none {
            return .needsDate
        }

        return nil
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
    @State private var toolsScrollRequest = 0
    @State private var isShowingSettings = false
    @State private var isShowingQuickCapture = false
    @State private var isShowingVoiceCapture = false
    @State private var isShowingInbox = false
    @State private var isShowingDailyRitual = false
    @State private var isShowingOverdueRescue = false
    @State private var isShowingTaskEditor = false
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

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 13) {
                            header
                            todaySummaryCard
                            dailyFocusSection
                            inboxSection
                            toolsSection
                                .id(BetaFocusedDashboardScrollTarget.tools)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 4)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: toolsScrollRequest) { _, _ in
                        withAnimation(.snappy(duration: 0.34)) {
                            proxy.scrollTo(BetaFocusedDashboardScrollTarget.tools, anchor: .bottom)
                        }
                    }
                }
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
                }
            }
            .onChange(of: selectedTab) { _, tab in
                handleTabSelection(tab)
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
                    navigationPath.append(.statistics)
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

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    BetaFocusedDashboardToolTile(
                        title: "Calendar",
                        systemImage: "calendar",
                        tint: BetaFocusedDashboardPalette.captureTint
                    ) {
                        navigationPath.append(.calendar)
                    }

                    BetaFocusedDashboardToolTile(
                        title: "Documents",
                        systemImage: "doc.text",
                        tint: BetaFocusedDashboardPalette.workTint
                    ) {
                        navigationPath.append(.documents)
                    }

                    BetaFocusedDashboardToolTile(
                        title: "Money",
                        systemImage: "dollarsign.circle",
                        tint: BetaFocusedDashboardPalette.homeTint
                    ) {
                        navigationPath.append(.money)
                    }

                    BetaFocusedDashboardToolTile(
                        title: "Import / Export",
                        systemImage: "arrow.up.arrow.down",
                        tint: BetaFocusedDashboardPalette.importExportTint
                    ) {
                        navigationPath.append(.taskData)
                    }
                }
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
            toolsScrollRequest += 1
        }
    }

    private func resetTabSelection() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            selectedTab = .home
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

private struct BetaFocusedDashboardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BetaFocusedDashboardPalette.backgroundTop,
                    BetaFocusedDashboardPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.65), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 240
            )
            .offset(x: -70, y: -40)

            RadialGradient(
                colors: [Color(hex: 0xFFD78C).opacity(0.22), Color.clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 260
            )
            .offset(x: 110, y: -30)
        }
    }
}

private struct BetaFocusedDashboardCard<Content: View>: View {
    let background: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
        }
        .shadow(color: BetaFocusedDashboardPalette.softShadow, radius: 18, x: 0, y: 8)
    }
}

private struct BetaFocusedDashboardPlanPreview: View {
    let preview: BetaFocusedDashboardPlanPreviewModel
    let onRescue: (() -> Void)?

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BetaFocusedDashboardPalette.heroAccent)
                .frame(width: 28, height: 28)
                .background(BetaFocusedDashboardPalette.dangerBackground.opacity(0.9), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(preview.summary)
                    .font(BetaFocusedDashboardTypography.body.weight(.semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(preview.detail)
                    .font(BetaFocusedDashboardTypography.bodySmall)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            if let onRescue {
                Button(action: onRescue) {
                    Text("Rescue")
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                        .foregroundStyle(BetaFocusedDashboardPalette.overdueTint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(BetaFocusedDashboardPalette.dangerBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border.opacity(0.85), lineWidth: 0.8)
        }
    }
}

private struct BetaFocusedDashboardMetricColumn: View {
    let symbolName: String
    let tint: Color
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.16), in: Circle())

            Text(value.formatted())
                .font(BetaFocusedDashboardTypography.statValue)
                .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text(label)
                .font(BetaFocusedDashboardTypography.body)
                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BetaFocusedDashboardVerticalRule: View {
    var body: some View {
        Rectangle()
            .fill(BetaFocusedDashboardPalette.border)
            .frame(width: 1, height: 68)
            .padding(.horizontal, 4)
    }
}

private struct BetaFocusedDashboardSunBackdrop: View {
    private var phase: TimeOfDayPhase {
        TimeOfDayPhase.current
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(phase.glowColor.opacity(0.22))
                .frame(width: 64, height: 64)
                .blur(radius: 8)
                .offset(x: 6, y: -6)

            Image(systemName: phase.symbolName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: phase.symbolGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(x: -2, y: 0)
        }
        .frame(width: 80, height: 44, alignment: .topTrailing)
        .accessibilityHidden(true)
    }
}

private enum TimeOfDayPhase {
    case morning
    case day
    case evening
    case night

    static var current: TimeOfDayPhase {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10: return .morning
        case 10..<17: return .day
        case 17..<21: return .evening
        default: return .night
        }
    }

    var symbolName: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .day: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var symbolGradient: [Color] {
        switch self {
        case .morning: return [Color(hex: 0xF7C26B), Color(hex: 0xF4A45C)]
        case .day: return [Color(hex: 0xFFD27A), Color(hex: 0xF6A148)]
        case .evening: return [Color(hex: 0xE5896A), Color(hex: 0xCB6E78)]
        case .night: return [Color(hex: 0x9DA4D8), Color(hex: 0x6F77B6)]
        }
    }

    var glowColor: Color {
        switch self {
        case .morning: return Color(hex: 0xFFD78C)
        case .day: return Color(hex: 0xFFC76A)
        case .evening: return Color(hex: 0xE5896A)
        case .night: return Color(hex: 0xB6BDE7)
        }
    }
}

private struct BetaFocusedDashboardStartHereBand: View {
    let recommendation: DailyFocusRecommendation
    let categoryOption: TaskCategoryOption
    let visuals: BetaFocusedDashboardCategoryVisuals
    let scheduledBlock: ScheduledBlock?
    let healthState: BetaFocusedDashboardTaskHealthState?
    let onOpen: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label("Start here", systemImage: "sparkles")
                    .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.heroAccent)

                Spacer(minLength: 0)

                Text(scheduleHint)
                    .font(BetaFocusedDashboardTypography.bodySmall)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 10) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(visuals.background)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: categoryOption.symbolName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(visuals.tint)
                    }

                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.task.title)
                            .font(BetaFocusedDashboardTypography.taskTitle.weight(.semibold))
                            .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        HStack(spacing: 6) {
                            Text(recommendation.reason.title)
                                .font(BetaFocusedDashboardTypography.bodySmall)
                                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)

                            BetaFocusedDashboardCategoryChip(
                                title: categoryOption.title,
                                tint: visuals.tint,
                                background: visuals.background
                            )

                            if let healthState {
                                BetaFocusedDashboardHealthChip(state: healthState)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button(action: onComplete) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(BetaFocusedDashboardPalette.completedTint, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Complete start here task")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    BetaFocusedDashboardPalette.dangerBackground.opacity(0.78),
                    Color.white.opacity(0.74)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.heroAccent.opacity(0.18), lineWidth: 0.8)
        }
    }

    private var scheduleHint: String {
        if let scheduledBlock {
            return "Fits \(BetaFocusedDashboardTimeFormatter.timeOnly.string(from: scheduledBlock.startDate))"
        }

        if recommendation.task.isOverdue {
            return "Rescue candidate"
        }

        return "Next best action"
    }
}

private struct BetaFocusedDashboardTaskRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let visuals: BetaFocusedDashboardCategoryVisuals
    let healthState: BetaFocusedDashboardTaskHealthState?
    let onOpen: () -> Void
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(visuals.background)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: categoryOption.symbolName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(visuals.tint)
                }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(BetaFocusedDashboardTypography.taskTitle)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)

                        Text(scheduleLabel)
                            .font(BetaFocusedDashboardTypography.body)
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if let healthState {
                            BetaFocusedDashboardHealthChip(state: healthState)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            BetaFocusedDashboardCategoryChip(
                title: categoryOption.title,
                tint: visuals.tint,
                background: visuals.background
            )

            Button(action: onToggleCompletion) {
                ZStack {
                    Circle()
                        .stroke(
                            task.isCompleted ? BetaFocusedDashboardPalette.completedTint : BetaFocusedDashboardPalette.border,
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if task.isCompleted {
                        Circle()
                            .fill(BetaFocusedDashboardPalette.completedTint)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
        }
        .padding(.vertical, 7)
        .padding(.trailing, 3)
    }

    private var scheduleLabel: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(task.dueDate) {
            return "Today, \(BetaFocusedDashboardTimeFormatter.timeOnly.string(from: task.dueDate))"
        }

        if calendar.isDateInTomorrow(task.dueDate) {
            return "Tomorrow, \(BetaFocusedDashboardTimeFormatter.timeOnly.string(from: task.dueDate))"
        }

        return BetaFocusedDashboardTimeFormatter.dateAndTime.string(from: task.dueDate)
    }
}

private enum BetaFocusedDashboardTimeFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter
    }()

    static let dateAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM, h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter
    }()
}

private struct BetaFocusedDashboardCategoryChip: View {
    let title: String
    let tint: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(BetaFocusedDashboardTypography.chip)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 0.8)
            }
    }
}

private struct BetaFocusedDashboardHealthChip: View {
    let state: BetaFocusedDashboardTaskHealthState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.symbolName)
                .font(.system(size: 8.5, weight: .bold))
            Text(state.title)
                .lineLimit(1)
        }
        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
        .foregroundStyle(state.tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(state.background, in: Capsule())
        .overlay {
            Capsule()
                .stroke(state.tint.opacity(0.16), lineWidth: 0.7)
        }
    }
}

private struct BetaFocusedDashboardTinyBadge: View {
    let title: String
    let tint: Color
    let background: Color

    var body: some View {
        Text(title)
            .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.16), lineWidth: 0.7)
            }
    }
}

private struct BetaFocusedDashboardActionChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isCompact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                Text(title)
                    .font((isCompact ? BetaFocusedDashboardTypography.bodySmall : BetaFocusedDashboardTypography.body).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, isCompact ? 7 : 11)
            .padding(.vertical, isCompact ? 8 : 10)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct BetaFocusedDashboardToolTile: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(tint)
                    }

                Text(title)
                    .font(BetaFocusedDashboardTypography.bodySmall)
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum BetaFocusedDashboardOverdueBucket: CaseIterable {
    case reschedule
    case snooze
    case someday
    case markDone
    case delete

    var title: String {
        switch self {
        case .reschedule: "Reschedule"
        case .snooze: "Snooze"
        case .someday: "Someday"
        case .markDone: "Mark Done"
        case .delete: "Delete"
        }
    }

    var subtitle: String {
        switch self {
        case .reschedule: "Recent or important tasks worth putting back on the calendar."
        case .snooze: "Tasks that can wait a few days without being forgotten."
        case .someday: "Older tasks that still matter, but do not belong in today."
        case .markDone: "Recurring items that were probably handled outside LifeTrack."
        case .delete: "Very old, low-priority tasks likely safe to move to the bin."
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .reschedule: "Tomorrow"
        case .snooze: "Snooze"
        case .someday: "Someday"
        case .markDone: "Done"
        case .delete: "Delete"
        }
    }

    var symbolName: String {
        switch self {
        case .reschedule: "calendar.badge.clock"
        case .snooze: "moon.zzz.fill"
        case .someday: "tray"
        case .markDone: "checkmark.circle.fill"
        case .delete: "trash"
        }
    }

    var tint: Color {
        switch self {
        case .reschedule:
            BetaFocusedDashboardPalette.captureTint
        case .snooze:
            BetaFocusedDashboardPalette.warningTint
        case .someday:
            BetaFocusedDashboardPalette.importExportTint
        case .markDone:
            BetaFocusedDashboardPalette.completedTint
        case .delete:
            BetaFocusedDashboardPalette.overdueTint
        }
    }

    var background: Color {
        switch self {
        case .reschedule:
            BetaFocusedDashboardPalette.financeBackground
        case .snooze:
            BetaFocusedDashboardPalette.warningBackground
        case .someday:
            BetaFocusedDashboardPalette.personalBackground
        case .markDone:
            BetaFocusedDashboardPalette.workBackground
        case .delete:
            BetaFocusedDashboardPalette.dangerBackground
        }
    }

    static func recommended(for task: LifeTask, referenceDate: Date = Date(), calendar: Calendar = .current) -> BetaFocusedDashboardOverdueBucket {
        let overdueDays = max(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: task.dueDate),
                to: calendar.startOfDay(for: referenceDate)
            ).day ?? 0,
            0
        )

        if task.recurrence != .none && overdueDays <= 7 {
            return .markDone
        }

        if overdueDays >= 45 && task.priority == .low {
            return .delete
        }

        if overdueDays >= 14 {
            return .someday
        }

        if overdueDays >= 3 {
            return .snooze
        }

        return .reschedule
    }
}

private struct BetaFocusedDashboardOverdueRescueSheet: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
    let onOpenTask: (LifeTask) -> Void
    let onReschedule: (LifeTask) -> Void
    let onSnooze: (LifeTask) -> Void
    let onSomeday: (LifeTask) -> Void
    let onComplete: (LifeTask) -> Void
    let onDelete: (LifeTask) -> Void

    private var sortedTasks: [LifeTask] {
        tasks
            .filter { !$0.isDeleted && !$0.isCompleted }
            .sorted { first, second in
                if first.priority.focusScore != second.priority.focusScore {
                    return first.priority.focusScore > second.priority.focusScore
                }

                return first.dueDate < second.dueDate
            }
    }

    private var groupedTasks: [(bucket: BetaFocusedDashboardOverdueBucket, tasks: [LifeTask])] {
        BetaFocusedDashboardOverdueBucket.allCases.compactMap { bucket in
            let matches = sortedTasks.filter { BetaFocusedDashboardOverdueBucket.recommended(for: $0) == bucket }
            guard !matches.isEmpty else { return nil }
            return (bucket, matches)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BetaFocusedDashboardBackground()
                    .ignoresSafeArea()

                if sortedTasks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            header

                            ForEach(groupedTasks, id: \.bucket) { group in
                                rescueSection(bucket: group.bucket, tasks: group.tasks)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Overdue Rescue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(sortedTasks.count) overdue task\(sortedTasks.count == 1 ? "" : "s")")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(BetaFocusedDashboardPalette.headerText)

            Text("LifeTrack grouped the backlog by the fastest useful action. Clear a section at a time or triage one task.")
                .font(BetaFocusedDashboardTypography.body)
                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(BetaFocusedDashboardPalette.completedTint)

            Text("Backlog rescued")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(BetaFocusedDashboardPalette.headerText)

            Text("No overdue tasks need cleanup right now.")
                .font(BetaFocusedDashboardTypography.body)
                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
    }

    private func rescueSection(bucket: BetaFocusedDashboardOverdueBucket, tasks: [LifeTask]) -> some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: bucket.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(bucket.tint)
                        .frame(width: 30, height: 30)
                        .background(bucket.background, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(bucket.title) · \(tasks.count)")
                            .font(BetaFocusedDashboardTypography.section)
                            .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                        Text(bucket.subtitle)
                            .font(BetaFocusedDashboardTypography.bodySmall)
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            tasks.forEach { apply(bucket, to: $0) }
                        }
                    } label: {
                        Text("Apply")
                            .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                            .foregroundStyle(bucket.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(bucket.background, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        BetaFocusedDashboardRescueTaskRow(
                            task: task,
                            categoryOption: task.categoryOption(customCategories: customCategories),
                            bucket: bucket,
                            onOpen: { onOpenTask(task) },
                            onPrimaryAction: { apply(bucket, to: task) },
                            onReschedule: { onReschedule(task) },
                            onSnooze: { onSnooze(task) },
                            onSomeday: { onSomeday(task) },
                            onComplete: { onComplete(task) },
                            onDelete: { onDelete(task) }
                        )

                        if index < tasks.count - 1 {
                            Divider()
                                .overlay(BetaFocusedDashboardPalette.border)
                                .padding(.leading, 48)
                        }
                    }
                }
            }
        }
    }

    private func apply(_ bucket: BetaFocusedDashboardOverdueBucket, to task: LifeTask) {
        switch bucket {
        case .reschedule:
            onReschedule(task)
        case .snooze:
            onSnooze(task)
        case .someday:
            onSomeday(task)
        case .markDone:
            onComplete(task)
        case .delete:
            onDelete(task)
        }
    }
}

private struct BetaFocusedDashboardRescueTaskRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let bucket: BetaFocusedDashboardOverdueBucket
    let onOpen: () -> Void
    let onPrimaryAction: () -> Void
    let onReschedule: () -> Void
    let onSnooze: () -> Void
    let onSomeday: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(categoryOption.background)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: categoryOption.symbolName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(categoryOption.tint)
                }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(BetaFocusedDashboardTypography.taskTitle)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 6) {
                        Text(overdueLabel)
                            .font(BetaFocusedDashboardTypography.bodySmall)
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)

                        BetaFocusedDashboardCategoryChip(
                            title: categoryOption.title,
                            tint: categoryOption.tint,
                            background: categoryOption.background
                        )

                        if let healthState = task.betaFocusedHealthState() {
                            BetaFocusedDashboardHealthChip(state: healthState)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onPrimaryAction) {
                Text(bucket.primaryActionTitle)
                    .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                    .foregroundStyle(bucket.tint)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(bucket.background, in: Capsule())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Reschedule tomorrow", systemImage: "calendar.badge.clock", action: onReschedule)
                Button("Snooze 3 days", systemImage: "moon.zzz.fill", action: onSnooze)
                Button("Move to someday", systemImage: "tray", action: onSomeday)
                Button("Mark done", systemImage: "checkmark.circle.fill", action: onComplete)
                Button("Move to bin", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var overdueLabel: String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: task.dueDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0

        if days <= 0 {
            return "Overdue today"
        }

        return days == 1 ? "1 day overdue" : "\(days) days overdue"
    }
}

private struct BetaFocusedDashboardTabBar: View {
    @Binding var selectedTab: BetaFocusedDashboardTab

    var body: some View {
        HStack(spacing: 6) {
            tabButton(tab: .home, title: "Home", systemImage: "house.fill")
            tabButton(tab: .capture, title: "Capture", systemImage: "plus.circle")
            tabButton(tab: .focus, title: "Focus", systemImage: "scope")
            tabButton(tab: .tools, title: "Tools", systemImage: "square.grid.2x2")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
        }
        .shadow(color: BetaFocusedDashboardPalette.softShadow, radius: 18, x: 0, y: 8)
    }

    private func tabButton(tab: BetaFocusedDashboardTab, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .medium))

                Text(title)
                    .font(BetaFocusedDashboardTypography.nav.weight(isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? BetaFocusedDashboardPalette.navAccent : BetaFocusedDashboardPalette.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .overlay(alignment: .top) {
                if isSelected {
                    Capsule()
                        .fill(BetaFocusedDashboardPalette.navAccent)
                        .frame(width: 24, height: 3)
                        .offset(y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
