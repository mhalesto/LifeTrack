//
//  BetaDashboardStatsGrid.swift
//  LifeTrack
//
//  4-up metric grid extracted from BetaDashboardView. Takes counts plus
//  trend series and a selection callback - the parent stays responsible
//  for computing trends and presenting summary sheets.
//

import SwiftUI

struct BetaDashboardStatsGrid: View {
    let dueToday: Int
    let upcoming: Int
    let completed: Int
    let overdue: Int
    let trends: BetaMetricTrends
    let onSelectKind: (BetaSummaryKind) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            BetaStatCard(
                icon: "sun.max.fill", iconTint: BetaPalette.statDueToday, iconBg: BetaPalette.statDueTodayBg,
                title: "Due Today", value: dueToday, subtitle: "7-day due",
                waveColor: BetaPalette.waveDueToday, series: trends.dueToday,
                action: { onSelectKind(.dueToday) }
            )
            BetaStatCard(
                icon: "calendar", iconTint: BetaPalette.statUpcoming, iconBg: BetaPalette.statUpcomingBg,
                title: "Upcoming", value: upcoming, subtitle: "Next week",
                waveColor: BetaPalette.waveUpcoming, series: trends.upcoming,
                action: { onSelectKind(.upcoming) }
            )
            BetaStatCard(
                icon: "checkmark.seal.fill", iconTint: BetaPalette.statCompleted, iconBg: BetaPalette.statCompletedBg,
                title: "Completed", value: completed, subtitle: "7-day done",
                waveColor: BetaPalette.waveCompleted, series: trends.completed,
                action: { onSelectKind(.completed) }
            )
            BetaStatCard(
                icon: "exclamationmark.triangle.fill", iconTint: BetaPalette.statOverdue, iconBg: BetaPalette.statOverdueBg,
                title: "Overdue", value: overdue, subtitle: "Backlog",
                waveColor: BetaPalette.waveOverdue, series: trends.overdue,
                action: { onSelectKind(.overdue) }
            )
        }
    }
}

private struct BetaStatCard: View {
    let icon: String
    let iconTint: Color
    let iconBg: Color
    let title: String
    let value: Int
    let subtitle: String
    let waveColor: Color
    let series: [Double]
    let action: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconTint)
            }

            Text(title)
                .font(.betaCaption(11, weight: .semibold))
                .foregroundStyle(BetaPalette.lightCardSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(formattedStatValue(value))
                .font(.betaMetric)
                .foregroundStyle(BetaPalette.lightCardPrimaryText)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            Text(subtitle)
                .font(.betaCaption(10, weight: .medium))
                .foregroundStyle(BetaPalette.lightCardTertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            ZStack(alignment: .bottom) {
                StatSparkline(values: series, closed: true)
                    .fill(
                        LinearGradient(
                            colors: [
                                waveColor.opacity(0.55),
                                waveColor.opacity(0.22),
                                waveColor.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                StatSparkline(values: series, closed: false)
                    .stroke(waveColor, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 32)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BetaPalette.lightCardFill)
                .shadow(color: BetaPalette.lightCardShadow, radius: 10, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            LifeTrackHaptics.lightImpact()
            action()
        }
    }
}

private func formattedStatValue(_ n: Int) -> String {
    if n < 1000 {
        return "\(n)"
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
}
