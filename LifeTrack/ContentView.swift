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

    @State private var isShowingLaunchSplash = true

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            if !isShowingLaunchSplash {
                HomeView()
                    .transition(.opacity)
            }

            if isShowingLaunchSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .task {
            await completeInitialSplash()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            coverAppSnapshot()
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
        case .inactive, .background:
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
