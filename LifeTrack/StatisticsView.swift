//
//  StatisticsView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Charts
import SwiftUI

struct StatisticsView: View {
    let tasks: [LifeTask]

    @State private var selectedRange: StatisticsTimeRange = .days

    private var points: [ProductivityStatPoint] {
        ProductivityStatsBuilder.points(for: tasks, range: selectedRange)
    }

    private var totalCompleted: Int {
        points.reduce(0) { $0 + $1.completedCount }
    }

    private var totalOverdue: Int {
        points.reduce(0) { $0 + $1.overdueCount }
    }

    private var bestPoint: ProductivityStatPoint? {
        points.max { $0.completedCount < $1.completedCount }
    }

    private var completionRate: Int {
        let total = totalCompleted + totalOverdue
        guard total > 0 else {
            return 0
        }

        return Int((Double(totalCompleted) / Double(total) * 100).rounded())
    }

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                    header
                    rangeSelector
                    summarySection
                    completedChart
                    overdueChart
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.large)
                .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Track your completion rhythm and overdue trends over time.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rangeSelector: some View {
        Picker("Time range", selection: $selectedRange) {
            ForEach(StatisticsTimeRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .tint(LifeTrackTheme.ColorPalette.accent)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(title: "Summary", subtitle: selectedRange.summarySubtitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LifeTrackTheme.Spacing.medium) {
                StatisticsSummaryCard(
                    title: "Completed",
                    value: totalCompleted.formatted(),
                    subtitle: "Finished in range",
                    symbolName: "checkmark.seal.fill",
                    tint: LifeTrackTheme.ColorPalette.success
                )

                StatisticsSummaryCard(
                    title: "Overdue",
                    value: totalOverdue.formatted(),
                    subtitle: "Past due in range",
                    symbolName: "exclamationmark.triangle.fill",
                    tint: LifeTrackTheme.ColorPalette.danger
                )

                StatisticsSummaryCard(
                    title: "Completion",
                    value: "\(completionRate)%",
                    subtitle: "Completed vs overdue",
                    symbolName: "chart.pie.fill",
                    tint: LifeTrackTheme.ColorPalette.accent
                )

                StatisticsSummaryCard(
                    title: "Best \(selectedRange.unitTitle)",
                    value: bestPoint?.completedCount.formatted() ?? "0",
                    subtitle: bestPoint?.label ?? "No activity yet",
                    symbolName: "sparkles",
                    tint: LifeTrackTheme.ColorPalette.warning
                )
            }
        }
    }

    private var completedChart: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Completed Tasks",
                subtitle: "Tasks finished per \(selectedRange.unitTitle.lowercased()).",
                trailing: totalCompleted.formatted()
            )

            Chart(points) { point in
                BarMark(
                    x: .value(selectedRange.unitTitle, point.date),
                    y: .value("Completed", point.completedCount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            LifeTrackTheme.ColorPalette.accent,
                            LifeTrackTheme.ColorPalette.accent.opacity(0.58)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: selectedRange.axisComponent)) { value in
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.55))
                    AxisTick()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline)
                    AxisValueLabel(format: selectedRange.axisFormat)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.7))
                    AxisValueLabel()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .chartYScale(domain: 0...max(1, points.map(\.completedCount).max() ?? 1))
            .frame(height: 230)

            chartFootnote(
                symbolName: "checkmark.circle",
                text: totalCompleted == 0 ? "Completed tasks will appear here once you finish them." : completionInsight
            )
        }
    }

    private var overdueChart: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Overdue Trend",
                subtitle: "Past-due tasks by \(selectedRange.unitTitle.lowercased()).",
                trailing: totalOverdue.formatted()
            )

            Chart(points) { point in
                AreaMark(
                    x: .value(selectedRange.unitTitle, point.date),
                    y: .value("Overdue", point.overdueCount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            LifeTrackTheme.ColorPalette.danger.opacity(0.22),
                            LifeTrackTheme.ColorPalette.danger.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value(selectedRange.unitTitle, point.date),
                    y: .value("Overdue", point.overdueCount)
                )
                .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value(selectedRange.unitTitle, point.date),
                    y: .value("Overdue", point.overdueCount)
                )
                .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                .symbolSize(point.overdueCount == 0 ? 0 : 38)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: selectedRange.axisComponent)) { value in
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.55))
                    AxisTick()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline)
                    AxisValueLabel(format: selectedRange.axisFormat)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.hairline.opacity(0.7))
                    AxisValueLabel()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .chartYScale(domain: 0...max(1, points.map(\.overdueCount).max() ?? 1))
            .frame(height: 230)

            chartFootnote(
                symbolName: totalOverdue == 0 ? "checkmark.circle" : "exclamationmark.circle",
                text: overdueInsight
            )
        }
    }

    private var completionInsight: String {
        guard let bestPoint, bestPoint.completedCount > 0 else {
            return "No completed tasks in this range yet."
        }

        return "\(bestPoint.label) had the strongest completion count with \(bestPoint.completedCount) finished."
    }

    private var overdueInsight: String {
        if totalOverdue == 0 {
            return "No overdue tasks in this range. The schedule is holding steady."
        }

        let peak = points.max { $0.overdueCount < $1.overdueCount }
        guard let peak else {
            return "Overdue tasks will appear here as trends develop."
        }

        return "The highest overdue count was \(peak.overdueCount) around \(peak.label)."
    }

    private func chartFootnote(symbolName: String, text: String) -> some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .frame(width: 26, height: 26)
                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())

            Text(text)
                .font(.footnote)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum StatisticsTimeRange: String, CaseIterable, Identifiable {
    case days
    case weeks
    case months

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days: "Days"
        case .weeks: "Weeks"
        case .months: "Months"
        }
    }

    var unitTitle: String {
        switch self {
        case .days: "Day"
        case .weeks: "Week"
        case .months: "Month"
        }
    }

    var summarySubtitle: String {
        switch self {
        case .days: "Past 14 days"
        case .weeks: "Past 8 weeks"
        case .months: "Past 6 months"
        }
    }

    var bucketCount: Int {
        switch self {
        case .days: 14
        case .weeks: 8
        case .months: 6
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        }
    }

    var axisComponent: Calendar.Component {
        switch self {
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        }
    }

    var axisFormat: Date.FormatStyle {
        switch self {
        case .days:
            return Date.FormatStyle().month(.abbreviated).day()
        case .weeks:
            return Date.FormatStyle().month(.abbreviated).day()
        case .months:
            return Date.FormatStyle().month(.abbreviated)
        }
    }
}

private struct ProductivityStatPoint: Identifiable {
    let id = UUID()
    let date: Date
    let endDate: Date
    let label: String
    let completedCount: Int
    let overdueCount: Int
}

private enum ProductivityStatsBuilder {
    static func points(for tasks: [LifeTask], range: StatisticsTimeRange, calendar: Calendar = .current) -> [ProductivityStatPoint] {
        let now = Date()
        let currentBucketStart = bucketStart(for: now, range: range, calendar: calendar)
        let firstBucketStart = calendar.date(
            byAdding: range.calendarComponent,
            value: -(range.bucketCount - 1),
            to: currentBucketStart
        ) ?? currentBucketStart

        return (0..<range.bucketCount).compactMap { offset in
            guard
                let bucketStart = calendar.date(byAdding: range.calendarComponent, value: offset, to: firstBucketStart),
                let bucketEnd = calendar.date(byAdding: range.calendarComponent, value: 1, to: bucketStart)
            else {
                return nil
            }

            let completedCount = tasks.filter { task in
                task.isCompleted && task.updatedAt >= bucketStart && task.updatedAt < bucketEnd
            }.count

            let overdueCount = tasks.filter { task in
                task.isOverdue && task.dueDate >= bucketStart && task.dueDate < bucketEnd
            }.count

            return ProductivityStatPoint(
                date: bucketStart,
                endDate: bucketEnd,
                label: label(for: bucketStart, range: range),
                completedCount: completedCount,
                overdueCount: overdueCount
            )
        }
    }

    private static func bucketStart(for date: Date, range: StatisticsTimeRange, calendar: Calendar) -> Date {
        switch range {
        case .days:
            return calendar.startOfDay(for: date)
        case .weeks:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .months:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private static func label(for date: Date, range: StatisticsTimeRange) -> String {
        switch range {
        case .days, .weeks:
            return date.formatted(Date.FormatStyle().month(.abbreviated).day())
        case .months:
            return date.formatted(Date.FormatStyle().month(.abbreviated))
        }
    }
}

private struct StatisticsSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(alignment: .top) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.12), in: Circle())

                Spacer()

                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .lifeTrackCard(padding: LifeTrackTheme.Spacing.medium, backgroundColor: LifeTrackTheme.ColorPalette.cardElevated)
    }
}

#Preview {
    NavigationStack {
        StatisticsView(
            tasks: [
                LifeTask(title: "Send report", category: .work, dueDate: Date(), isCompleted: true, updatedAt: Date()),
                LifeTask(title: "Book appointment", category: .health, dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            ]
        )
    }
}
