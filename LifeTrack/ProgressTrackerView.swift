//
//  ProgressTrackerView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct ProgressTrackerView: View {
    let metrics: TaskProgressMetrics
    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.colorStrength) private var colorStrength = 1.0
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true
    @State private var isIntroPulsing = false
    @State private var revealedMetricCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
            HStack(alignment: .center, spacing: LifeTrackTheme.Spacing.large) {
                StreakHeroIcon(metrics: metrics, isPulsing: isIntroPulsing)

                VStack(alignment: .leading, spacing: 7) {
                    Text(metrics.title)
                        .font(.lifeTrack(.title2, weight: .bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)

                    Text(metrics.message)
                        .font(.callout.weight(.medium))
                        .lineSpacing(2)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)
            }

            ProgressMetricPanel(metrics: metrics, revealedSegmentCount: revealedMetricCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeTrackCard(padding: LifeTrackTheme.Spacing.large, backgroundColor: LifeTrackTheme.ColorPalette.cardElevated)
        .id("\(selectedThemeID)-\(colorStrength)")
        .task(id: introAnimationID) {
            await runIntroAnimation()
        }
    }

    private var introAnimationID: String {
        [
            selectedThemeID,
            colorStrength.formatted(),
            metrics.currentStreak.formatted(),
            metrics.bestStreak.formatted(),
            metrics.completedDaysThisWeek.formatted(),
            metrics.hasCompletedToday.description
        ]
        .joined(separator: "-")
    }

    private func runIntroAnimation() async {
        guard animationsEnabled else {
            await MainActor.run {
                isIntroPulsing = false
                revealedMetricCount = 3
            }
            return
        }

        await MainActor.run {
            isIntroPulsing = false
            revealedMetricCount = 0
        }

        try? await Task.sleep(nanoseconds: 110_000_000)

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.22)) {
                isIntroPulsing = true
            }
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            withAnimation(.smooth(duration: 0.42)) {
                revealedMetricCount = 1
            }
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            withAnimation(.smooth(duration: 0.42)) {
                revealedMetricCount = 2
            }
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            withAnimation(.smooth(duration: 0.42)) {
                revealedMetricCount = 3
            }
        }

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.28)) {
                isIntroPulsing = false
            }
        }
    }
}

private struct StreakHeroIcon: View {
    let metrics: TaskProgressMetrics
    let isPulsing: Bool

    var body: some View {
        ZStack {
            if isPulsing {
                StreakPulseRings(tint: LifeTrackTheme.ColorPalette.accent)
                    .transition(.opacity)
            }

            Circle()
                .fill(LifeTrackTheme.ColorPalette.accentSoft)
                .frame(width: 74, height: 74)
                .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.10), radius: 14, x: 0, y: 8)

            Circle()
                .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.09), lineWidth: 12)
                .frame(width: 74, height: 74)

            Image(systemName: metrics.currentStreak > 0 ? "flame.fill" : "sparkles")
                .font(.system(size: 31, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .symbolEffect(.pulse, value: metrics.currentStreak)
                .scaleEffect(isPulsing ? 1.06 : 1)
                .animation(.easeInOut(duration: 1.2).repeatCount(isPulsing ? 2 : 0, autoreverses: true), value: isPulsing)
        }
        .frame(width: 82, height: 82)
        .accessibilityHidden(true)
    }
}

private struct StreakPulseRings: View {
    let tint: Color
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        tint.opacity(0.18 - (Double(index) * 0.035)),
                        lineWidth: 2.2
                    )
                    .frame(width: 74, height: 74)
                    .scaleEffect(isExpanded ? 1.42 + CGFloat(index) * 0.08 : 0.82)
                    .opacity(isExpanded ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.35)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.24),
                        value: isExpanded
                    )
            }
        }
        .onAppear {
            isExpanded = false
            DispatchQueue.main.async {
                isExpanded = true
            }
        }
    }
}

private struct ProgressMetricPanel: View {
    let metrics: TaskProgressMetrics
    let revealedSegmentCount: Int

    var body: some View {
        HStack(spacing: 0) {
            ProgressMetricSegment(
                title: "Current",
                value: metrics.currentStreak.formatted(),
                unit: metrics.currentStreak == 1 ? "Day" : "Days",
                symbolName: "flame.fill",
                tint: LifeTrackTheme.ColorPalette.accent,
                isRevealed: revealedSegmentCount >= 1
            )

            ProgressMetricDivider()

            ProgressMetricSegment(
                title: "Best",
                value: metrics.bestStreak.formatted(),
                unit: metrics.bestStreak == 1 ? "Day" : "Days",
                symbolName: "star.fill",
                tint: LifeTrackTheme.ColorPalette.accentDeep,
                isRevealed: revealedSegmentCount >= 2
            )

            ProgressMetricDivider()

            ProgressMetricSegment(
                title: "This Week",
                value: "\(metrics.completedDaysThisWeek)/7",
                unit: "Days",
                symbolName: "calendar",
                tint: LifeTrackTheme.ColorPalette.accent,
                isRevealed: revealedSegmentCount >= 3
            )
        }
        .padding(.vertical, 11)
        .background(
            LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.82),
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.78), lineWidth: 0.8)
        }
        .animation(.smooth(duration: 0.42), value: revealedSegmentCount)
    }
}

private struct ProgressMetricSegment: View {
    let title: String
    let value: String
    let unit: String
    let symbolName: String
    let tint: Color
    let isRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.lifeTrack(.title3, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(unit)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            HStack(spacing: 7) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 17, alignment: .center)
                    .symbolEffect(.bounce, value: isRevealed)

                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
    }
}

private struct ProgressMetricDivider: View {
    var body: some View {
        Rectangle()
            .fill(LifeTrackTheme.ColorPalette.hairline.opacity(0.70))
            .frame(width: 0.8)
            .padding(.vertical, -11)
    }
}

private extension TaskProgressMetrics {
    var referenceMessage: String {
        if hasCompletedToday {
            if currentStreak == 1 {
                return "Great start! You've completed a task 1 day in a row."
            }

            return "Great pace! You've completed tasks for \(currentStreak) days in a row."
        }

        if currentStreak > 0 {
            return "Complete one task today to keep your \(currentStreak)-day rhythm alive."
        }

        return "Finish one task today and start a streak you can build on."
    }
}

struct TaskProgressMetrics {
    let currentStreak: Int
    let bestStreak: Int
    let completedDaysThisWeek: Int
    let hasCompletedToday: Bool

    var title: String {
        if currentStreak == 0 {
            return "Start today"
        }

        return "\(currentStreak)-day streak"
    }

    var message: String {
        referenceMessage
    }

    static func build(from tasks: [LifeTask], calendar: Calendar = .current, referenceDate: Date = Date()) -> TaskProgressMetrics {
        let completedDays = Set(
            tasks
                .filter(\.isCompleted)
                .map { calendar.startOfDay(for: $0.updatedAt) }
        )

        let today = calendar.startOfDay(for: referenceDate)
        let hasCompletedToday = completedDays.contains(today)
        let currentAnchor = hasCompletedToday ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        let currentStreak = streakEnding(on: currentAnchor, completedDays: completedDays, calendar: calendar)
        let bestStreak = bestStreak(in: completedDays, calendar: calendar)
        let completedDaysThisWeek = completedDays.filter { date in
            calendar.isDate(date, equalTo: today, toGranularity: .weekOfYear)
        }.count

        return TaskProgressMetrics(
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            completedDaysThisWeek: completedDaysThisWeek,
            hasCompletedToday: hasCompletedToday
        )
    }

    private static func streakEnding(on date: Date, completedDays: Set<Date>, calendar: Calendar) -> Int {
        var count = 0
        var cursor = date

        while completedDays.contains(cursor) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return count
    }

    private static func bestStreak(in completedDays: Set<Date>, calendar: Calendar) -> Int {
        let days = completedDays.sorted()
        guard !days.isEmpty else {
            return 0
        }

        var best = 1
        var current = 1

        for index in days.indices.dropFirst() {
            let previous = days[days.index(before: index)]
            let expected = calendar.date(byAdding: .day, value: 1, to: previous)

            if expected == days[index] {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }

        return best
    }
}
