//
//  ContentView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            HomeView()

            if isShowingSplash {
                SplashScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_650_000_000)
            withAnimation(.easeInOut(duration: 0.42)) {
                isShowingSplash = false
            }
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LifeTask.self, configurations: configuration)
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
