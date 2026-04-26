//
//  ContentView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import CoreSpotlight
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var recurringTemplates: [RecurringMoneyTransaction]
    @Query private var moneyEntries: [MoneyEntry]
    @Query private var allTasks: [LifeTask]

    @State private var isShowingLaunchSplash = true
    @State private var isShowingFeatureTour = false
    @AppStorage(LifeTrackSettings.Keys.featureTourCompleted) private var featureTourCompleted = false
    @AppStorage(LifeTrackSettings.Keys.dashboardExperience) private var dashboardExperienceRaw = DashboardExperience.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.appearanceMode) private var appearanceModeRaw = AppearanceMode.current.rawValue
    @AppStorage(LifeTrackSettings.Keys.hideStatusBar) private var hideStatusBar = false
    @AppStorage(LifeTrackSettings.Keys.appFontChoice) private var appFontChoice = LifeTrackFontChoice.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.titleTextScale) private var titleTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.bodyTextScale) private var bodyTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.captionTextScale) private var captionTextScale = LifeTrackTypography.defaultScale

    private var dashboardExperience: DashboardExperience {
        DashboardExperience(rawValue: dashboardExperienceRaw) ?? .default
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .auto
    }

    private func syncEffectiveDarkMode(system: ColorScheme) {
        let resolved = appearanceMode.resolve(system: system)
        UserDefaults.standard.set(resolved == .dark, forKey: LifeTrackSettings.Keys.darkModeEnabled)
    }

    private var typographyRefreshToken: String {
        let resolvedScheme = appearanceMode.resolve(system: systemColorScheme) == .dark ? "dark" : "light"
        return [
            appFontChoice,
            String(format: "%.2f", titleTextScale),
            String(format: "%.2f", bodyTextScale),
            String(format: "%.2f", captionTextScale),
            appearanceModeRaw,
            resolvedScheme
        ]
        .joined(separator: "-")
    }

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            if !isShowingLaunchSplash {
                Group {
                    if dashboardExperience == .beta {
                        BetaDashboardHomeView()
                    } else {
                        HomeView()
                    }
                }
                .id(typographyRefreshToken)
                .transition(.opacity)
            }

            if isShowingLaunchSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .statusBarHidden(hideStatusBar)
        .preferredColorScheme(appearanceMode.preferredColorScheme)
        .sheet(isPresented: $isShowingFeatureTour) {
            FeatureTourView()
                .interactiveDismissDisabled()
        }
        .task {
            await completeInitialSplash()
            runRecurringMoneyExpansion()
            runRecurringTaskCatchUp()
            runBillAutoMatch()
            publishMoneyWidgetSnapshot()
            syncMoneyReminders()
            reindexSpotlight()
            if !featureTourCompleted {
                isShowingFeatureTour = true
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            handleSpotlightContinuation(activity)
        }
        .onAppear {
            syncEffectiveDarkMode(system: systemColorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
        .onChange(of: systemColorScheme) { _, newValue in
            syncEffectiveDarkMode(system: newValue)
        }
        .onChange(of: appearanceModeRaw) { _, _ in
            syncEffectiveDarkMode(system: systemColorScheme)
        }
    }

    private func completeInitialSplash() async {
        try? await Task.sleep(nanoseconds: 950_000_000)

        guard !Task.isCancelled else {
            return
        }

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.18)) {
                isShowingLaunchSplash = false
            }
        }
    }

    private func runRecurringMoneyExpansion() {
        guard !recurringTemplates.isEmpty else { return }
        _ = RecurringMoneyExpander.runPendingExpansions(
            templates: recurringTemplates.filter(\.isActive),
            modelContext: modelContext
        )
    }

    private func runRecurringTaskCatchUp() {
        _ = RecurringTaskCatchUp.runCatchUp(tasks: allTasks, modelContext: modelContext)
    }

    private func reindexSpotlight() {
        TaskSpotlightIndexer.reindex(allTasks)
    }

    private func handleSpotlightContinuation(_ activity: NSUserActivity) {
        guard let taskID = TaskSpotlightIndexer.extractTaskID(from: activity) else { return }
        NotificationCenter.default.post(
            name: TaskSpotlightIndexer.openTaskNotification,
            object: nil,
            userInfo: [TaskSpotlightIndexer.openTaskUserInfoKey: taskID]
        )
    }

    private func runBillAutoMatch() {
        let matched = BillAutoMatcher.runMatch(entries: moneyEntries, tasks: allTasks)
        if !matched.isEmpty {
            try? modelContext.save()
        }
    }

    private func syncMoneyReminders() {
        let now = Date()
        let currency = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.moneyCurrencyCode)
            ?? MoneyCurrency.primaryCurrencyCode(entries: moneyEntries, tasks: allTasks)

        let bills = MoneyAnalytics.plannedBills(
            for: now,
            tasks: allTasks,
            currencyCode: currency
        )
        let summary = MoneyAnalytics.monthlySummary(
            for: now,
            entries: moneyEntries,
            tasks: allTasks,
            currencyCode: currency
        )
        let rollovers = BudgetRollover.carryOver(
            intoMonth: now,
            entries: moneyEntries,
            tasks: allTasks,
            currencyCode: currency
        )
        let rolloverTotal = rollovers.filter { $0.carryOver > 0 }.reduce(0) { $0 + $1.carryOver }
        let adjustedPlanned = max(summary.plannedSpending + rolloverTotal, 0)

        MoneyReminderScheduler.synchronize(
            bills: bills,
            monthlyActualSpending: summary.actualSpending,
            monthlyAdjustedPlannedSpending: adjustedPlanned,
            currencyCode: currency,
            now: now
        )
    }

    private func publishMoneyWidgetSnapshot() {
        let calendar = Calendar.current
        let now = Date()
        let currency = UserDefaults.standard.string(forKey: LifeTrackSettings.Keys.moneyCurrencyCode)
            ?? MoneyCurrency.primaryCurrencyCode(entries: moneyEntries, tasks: allTasks)

        let day = calendar.dateInterval(of: .day, for: now)
            ?? DateInterval(start: now, duration: 86_400)
        var spentToday: Double = 0
        for entry in moneyEntries {
            guard MoneyCurrency.normalized(entry.currencyCode) == MoneyCurrency.normalized(currency) else { continue }
            guard entry.includeInMonthlySpending else { continue }
            switch entry.type {
            case .expense, .debtPayment:
                spentToday += MoneyAnalytics.amount(for: entry, in: day, calendar: calendar)
            case .income, .savings, .transfer:
                continue
            }
        }

        let summary = MoneyAnalytics.monthlySummary(
            for: now,
            entries: moneyEntries,
            tasks: allTasks,
            currencyCode: currency
        )
        let categoryTotals = MoneyAnalytics.categoryTotals(
            for: now,
            entries: moneyEntries,
            tasks: allTasks,
            currencyCode: currency
        )
        let topExpense = categoryTotals
            .filter { $0.kind == .expense }
            .max(by: { $0.actual < $1.actual })

        MoneyWidgetSnapshotPublisher.publish(
            spentToday: spentToday,
            spentThisMonth: summary.actualSpending,
            plannedThisMonth: summary.plannedSpending,
            topCategoryName: topExpense?.category,
            topCategoryAmount: topExpense?.actual ?? 0,
            currencyCode: currency,
            referenceDate: now
        )
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            guard !isShowingLaunchSplash else { return }
            AppSnapshotCover.hide(animated: true)
            runRecurringMoneyExpansion()
            runRecurringTaskCatchUp()
            runBillAutoMatch()
            publishMoneyWidgetSnapshot()
            syncMoneyReminders()
            reindexSpotlight()
        case .inactive:
            break
        case .background:
            coverAppSnapshot()
        @unknown default:
            break
        }
    }

    private func coverAppSnapshot() {
        guard !isShowingLaunchSplash else { return }
        AppSnapshotCover.show()
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, CustomTaskCategory.self, configurations: configuration)
    let context = container.mainContext

    context.insert(
        LifeTask(
            title: "Review insurance documents",
            category: .finance,
            dueDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date(),
            notes: "Check uploaded policy files and renewal date.",
            documentStorageName: "sample.pdf",
            documentDisplayName: "Policy renewal.pdf"
        )
    )
    context.insert(
        LifeTask(
            title: "Book annual health check",
            category: .health,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )
    )
    context.insert(
        LifeTask(
            title: "Send follow-up email",
            category: .work,
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
            notes: "Subject: Follow up\n\nHi,\n\nI wanted to follow up on this task.",
            templateAction: .email
        )
    )

    return ContentView()
        .modelContainer(container)
}
