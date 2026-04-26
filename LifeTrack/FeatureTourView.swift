//
//  FeatureTourView.swift
//  LifeTrack
//
//  First-run onboarding sheet that introduces the major features in a
//  paginated TabView. Gated by AppStorage so it only appears once.
//

import SwiftUI

struct FeatureTourView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LifeTrackSettings.Keys.featureTourCompleted) private var featureTourCompleted = false

    @State private var pageIndex = 0

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(
            symbol: "checklist",
            title: "Plan your day",
            body: "Capture tasks, set priorities, and let LifeTrack pick today's focus list automatically."
        ),
        Page(
            symbol: "mic.fill",
            title: "Voice & AI assist",
            body: "Hold the mic to dictate a task — AI cleans it up and slots it into the right category. Sensitive details like phone numbers are redacted before they leave your device."
        ),
        Page(
            symbol: "creditcard.fill",
            title: "Money on rails",
            body: "Plan a budget, log spending, scan receipts, or import a bank statement. Bills auto-match to imported transactions so reconciliation stays light."
        ),
        Page(
            symbol: "bell.badge.fill",
            title: "Smart reminders",
            body: "Bills due tomorrow and over-budget months trigger local notifications. Pin a focus task to the lock screen with a Live Activity."
        ),
        Page(
            symbol: "square.grid.2x2.fill",
            title: "Widgets everywhere",
            body: "Drop a money widget on the home screen for spent-today + monthly progress, or use the Control Center quick actions."
        )
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LifeTrackTheme.appBackground.ignoresSafeArea()

            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageView(page)
                        .tag(index)
                        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(pageIndex == pages.count - 1 ? "Done" : "Skip") {
                complete()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .padding(.top, LifeTrackTheme.Spacing.medium)
            .padding(.trailing, LifeTrackTheme.Spacing.large)
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(LifeTrackTheme.ColorPalette.accent.opacity(0.15))
                    .frame(width: 132, height: 132)
                Image(systemName: page.symbol)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
            }

            Text(page.title)
                .font(.lifeTrack(.title, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .multilineTextAlignment(.center)

            Text(page.body)
                .font(.body)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, LifeTrackTheme.Spacing.xLarge)
    }

    private func complete() {
        featureTourCompleted = true
        dismiss()
    }
}
