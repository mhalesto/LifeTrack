//
//  ContentView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var isShowingLaunchSplash = true
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
        [
            appFontChoice,
            String(format: "%.2f", titleTextScale),
            String(format: "%.2f", bodyTextScale),
            String(format: "%.2f", captionTextScale)
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
        .task {
            await completeInitialSplash()
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

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            guard !isShowingLaunchSplash else { return }
            AppSnapshotCover.hide(animated: true)
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
