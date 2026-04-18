//
//  ProgressTrackerView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct ProgressTrackerView: View {
    let metrics: TaskProgressMetrics

    var body: some View {
        SectionCardView {
            HStack(alignment: .center, spacing: LifeTrackTheme.Spacing.medium) {
                ZStack {
                    Circle()
                        .fill(LifeTrackTheme.ColorPalette.accentSoft)
                        .frame(width: 54, height: 54)

                    Image(systemName: metrics.currentStreak > 0 ? "flame.fill" : "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(metrics.title)
                        .font(.lifeTrackHeadline)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(metrics.message)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)
            }

            HStack(spacing: LifeTrackTheme.Spacing.small) {
                ProgressMetricPill(title: "Current", value: "\(metrics.currentStreak)d")
                ProgressMetricPill(title: "Best", value: "\(metrics.bestStreak)d")
                ProgressMetricPill(title: "This Week", value: "\(metrics.completedDaysThisWeek)/7")
            }
        }
    }
}

private struct ProgressMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.88), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.85), lineWidth: 0.7)
        }
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
        if hasCompletedToday {
            return "You completed a task today. Keep the rhythm gentle and visible."
        }

        if currentStreak > 0 {
            return "Complete one task today to protect your streak."
        }

        return "Finish one task to start building a streak."
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
