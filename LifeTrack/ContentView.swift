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
    @AppStorage(LifeTrackSettings.Keys.appearanceMode) private var appearanceModeRaw = AppearanceMode.current.rawValue
    @AppStorage(LifeTrackSettings.Keys.hideStatusBar) private var hideStatusBar = false
    @AppStorage(LifeTrackSettings.Keys.appFontChoice) private var appFontChoice = LifeTrackFontChoice.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.titleTextScale) private var titleTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.bodyTextScale) private var bodyTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.captionTextScale) private var captionTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.dashboardStyle) private var dashboardStyleRaw = DashboardStyle.fallback.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .auto
    }

    private var dashboardStyle: DashboardStyle {
        DashboardStyle(rawValue: dashboardStyleRaw) ?? .fallback
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
                activeDashboardView
                    .id("\(dashboardStyle.rawValue)-\(typographyRefreshToken)")
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
            runAppMaintenance(trigger: .initialLaunch)
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

    @ViewBuilder
    private var activeDashboardView: some View {
        switch dashboardStyle {
        case .current:
            CurrentDashboardHomeView()
        case .beta:
            BetaFocusedDashboardHomeView()
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

    private func handleSpotlightContinuation(_ activity: NSUserActivity) {
        guard let taskID = TaskSpotlightIndexer.extractTaskID(from: activity) else { return }
        NotificationCenter.default.post(
            name: TaskSpotlightIndexer.openTaskNotification,
            object: nil,
            userInfo: [TaskSpotlightIndexer.openTaskUserInfoKey: taskID]
        )
    }

    private func runAppMaintenance(trigger: AppMaintenanceTrigger) {
        AppMaintenanceCoordinator.shared.run(
            trigger: trigger,
            modelContext: modelContext,
            recurringTemplates: recurringTemplates,
            moneyEntries: moneyEntries,
            tasks: allTasks
        )
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            guard !isShowingLaunchSplash else { return }
            AppSnapshotCover.hide(animated: true)
            runAppMaintenance(trigger: .sceneBecameActive)
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
