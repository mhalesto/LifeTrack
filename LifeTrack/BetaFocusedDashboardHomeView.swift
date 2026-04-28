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
    case more
}

private enum BetaFocusedDashboardTypography {
    static let greeting = Font.system(size: 22, weight: .semibold, design: .serif)
    static let date = Font.system(size: 12, weight: .medium, design: .default)
    static let section = Font.system(size: 17, weight: .semibold, design: .serif)
    static let heroTitle = Font.system(size: 26, weight: .bold, design: .serif)
    static let statValue = Font.system(size: 26, weight: .medium, design: .serif)
    static let button = Font.system(size: 15, weight: .semibold, design: .default)
    static let body = Font.system(size: 12.5, weight: .medium, design: .default)
    static let bodySmall = Font.system(size: 11, weight: .medium, design: .default)
    static let chip = Font.system(size: 11, weight: .semibold, design: .default)
    static let nav = Font.system(size: 11, weight: .medium, design: .default)
    static let taskTitle = Font.system(size: 15, weight: .semibold, design: .default)
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
}

private struct BetaFocusedDashboardCategoryVisuals {
    let tint: Color
    let background: Color
}

struct BetaFocusedDashboardHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

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

                VStack(alignment: .leading, spacing: 10) {
                    header
                    todaySummaryCard
                    dailyFocusSection
                        .frame(maxHeight: .infinity)
                    inboxSection
                    toolsSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 2)
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
            openPendingNotificationTaskIfNeeded()
            drainSharedInbox()
        }
        .onChange(of: openTasks) { _, _ in
            recomputeDerivedTasks()
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
                    HStack(spacing: 7) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Stats")
                            .font(BetaFocusedDashboardTypography.button)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(BetaFocusedDashboardPalette.statsPillText)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .frame(minWidth: 96)
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
                        ProfileAvatarView(size: 50, avatarVersion: avatarVersion)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(BetaFocusedDashboardPalette.statsPillText)
                            .frame(width: 20, height: 20)
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

                VStack(alignment: .leading, spacing: 12) {
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

                        BetaFocusedDashboardMetricColumn(
                            symbolName: "exclamationmark.circle",
                            tint: BetaFocusedDashboardPalette.overdueTint,
                            value: overdueTasks.count,
                            label: "Overdue"
                        )

                        BetaFocusedDashboardVerticalRule()

                        BetaFocusedDashboardMetricColumn(
                            symbolName: "checkmark.circle",
                            tint: BetaFocusedDashboardPalette.completedTint,
                            value: totalCompletedCount,
                            label: "Completed"
                        )
                    }

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
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [
                                    BetaFocusedDashboardPalette.heroAccent,
                                    BetaFocusedDashboardPalette.heroAccentDeep
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .shadow(color: BetaFocusedDashboardPalette.heroAccent.opacity(0.16), radius: 14, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dailyFocusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                            .font(.system(size: 19, weight: .semibold, design: .default))
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
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(focusTasks.enumerated()), id: \.element.id) { index, task in
                                let option = task.categoryOption(customCategories: customCategories)
                                BetaFocusedDashboardTaskRow(
                                    task: task,
                                    categoryOption: option,
                                    visuals: categoryVisuals(for: option),
                                    onOpen: { editingTask = task },
                                    onToggleCompletion: { toggleCompletion(task) }
                                )

                                if index < focusTasks.count - 1 {
                                    Divider()
                                        .overlay(BetaFocusedDashboardPalette.border)
                                        .padding(.leading, 56)
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: .infinity)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.88),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var inboxSection: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            HStack(alignment: .center, spacing: 8) {
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
                            Text("Inbox")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                            Text(inboxItems.isEmpty ? "Nothing waiting" : "\(inboxItems.count) waiting")
                                .font(BetaFocusedDashboardTypography.body)
                                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    BetaFocusedDashboardActionChip(
                        title: "Text",
                        systemImage: "bubble.left.and.text.bubble.right",
                        tint: BetaFocusedDashboardPalette.captureTint,
                        isCompact: true
                    ) {
                        openQuickCapture()
                    }

                    BetaFocusedDashboardActionChip(
                        title: "Voice",
                        systemImage: "waveform",
                        tint: BetaFocusedDashboardPalette.captureTint,
                        isCompact: true
                    ) {
                        openVoiceCapture()
                    }
                }
                .fixedSize()
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
        case .more:
            isShowingSettings = true
            resetTabSelection()
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
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
        }
        .shadow(color: BetaFocusedDashboardPalette.softShadow, radius: 18, x: 0, y: 8)
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
                .frame(width: 38, height: 38)
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

private struct BetaFocusedDashboardTaskRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let visuals: BetaFocusedDashboardCategoryVisuals
    let onOpen: () -> Void
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(visuals.background)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: categoryOption.symbolName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(visuals.tint)
                }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(BetaFocusedDashboardTypography.taskTitle)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)

                        Text(scheduleLabel)
                            .font(BetaFocusedDashboardTypography.body)
                            .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            BetaFocusedDashboardCategoryChip(
                title: categoryOption.title,
                symbolName: categoryOption.symbolName,
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
                        .frame(width: 26, height: 26)

                    if task.isCompleted {
                        Circle()
                            .fill(BetaFocusedDashboardPalette.completedTint)
                            .frame(width: 26, height: 26)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
        }
        .padding(.vertical, 6)
        .padding(.trailing, 4)
    }

    private var scheduleLabel: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(task.dueDate) {
            return "Today, \(task.dueDate.formatted(date: .omitted, time: .shortened))"
        }

        if calendar.isDateInTomorrow(task.dueDate) {
            return "Tomorrow, \(task.dueDate.formatted(date: .omitted, time: .shortened))"
        }

        return task.dueDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }
}

private struct BetaFocusedDashboardCategoryChip: View {
    let title: String
    let symbolName: String
    let tint: Color
    let background: Color

    var body: some View {
        Label(title, systemImage: symbolName)
            .font(BetaFocusedDashboardTypography.chip)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 0.8)
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
            }
            .foregroundStyle(tint)
            .padding(.horizontal, isCompact ? 9 : 11)
            .padding(.vertical, isCompact ? 9 : 10)
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
            VStack(spacing: 8) {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 38, height: 38)
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
            .frame(maxWidth: .infinity, minHeight: 86)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct BetaFocusedDashboardTabBar: View {
    @Binding var selectedTab: BetaFocusedDashboardTab

    var body: some View {
        HStack(spacing: 6) {
            tabButton(tab: .home, title: "Home", systemImage: "house.fill")
            tabButton(tab: .capture, title: "Capture", systemImage: "plus.circle")
            tabButton(tab: .focus, title: "Focus", systemImage: "scope")
            tabButton(tab: .more, title: "More", systemImage: "ellipsis")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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
                    .font(.system(size: 18, weight: isSelected ? .semibold : .medium))

                Text(title)
                    .font(BetaFocusedDashboardTypography.nav.weight(isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? BetaFocusedDashboardPalette.navAccent : BetaFocusedDashboardPalette.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
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
