//
//  BetaFocusedDashboardFocusHistoryDetailView.swift
//  LifeTrack
//

import SwiftUI

struct BetaFocusedDashboardFocusHistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let records: [FocusSessionRecord]

    private var summary: FocusSessionSummary {
        FocusSessionSummary(records: records)
    }

    private var dayGroups: [FocusSessionHistoryDayGroup] {
        FocusSessionHistoryDayGroup.groups(from: records)
    }

    var body: some View {
        ZStack {
            BetaFocusedDashboardBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    summaryCard

                    if dayGroups.isEmpty {
                        emptyState
                    } else {
                        ForEach(dayGroups) { group in
                            FocusSessionHistoryDayCard(group: group)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BetaFocusedDashboardPalette.statsPillText)
                    .frame(width: 34, height: 34)
                    .background(BetaFocusedDashboardPalette.statsPillBackground, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text("Session History")
                    .font(BetaFocusedDashboardTypography.greeting)
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                Text("Focus blocks and partial sessions")
                    .font(BetaFocusedDashboardTypography.date)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var summaryCard: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Progress")
                    .font(BetaFocusedDashboardTypography.section)
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                HStack(spacing: 8) {
                    FocusSessionHistoryMetric(
                        value: "\(summary.todayMinutes)",
                        title: "Today",
                        systemImage: "timer",
                        tint: BetaFocusedDashboardPalette.heroAccent
                    )

                    FocusSessionHistoryMetric(
                        value: "\(summary.weekMinutes)",
                        title: "This Week",
                        systemImage: "calendar.badge.clock",
                        tint: BetaFocusedDashboardPalette.completedTint
                    )

                    FocusSessionHistoryMetric(
                        value: "\(summary.totalCompletedBlocks)",
                        title: "Blocks",
                        systemImage: "checkmark.seal",
                        tint: BetaFocusedDashboardPalette.captureTint
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.completedTint)
                    .frame(width: 42, height: 42)
                    .background(BetaFocusedDashboardPalette.completedTint.opacity(0.14), in: Circle())

                Text("No sessions yet")
                    .font(BetaFocusedDashboardTypography.section)
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                Text("Start a focus block, leave the screen, or complete a task. Completed blocks and meaningful partial sessions will appear here.")
                    .font(BetaFocusedDashboardTypography.body)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct FocusSessionHistoryDayGroup: Identifiable {
    let date: Date
    let records: [FocusSessionRecord]
    let calendar: Calendar

    var id: Date { date }

    var minutes: Int {
        records.reduce(0) { $0 + $1.durationMinutes }
    }

    var completedBlocks: Int {
        records.filter(\.completedBlock).count
    }

    var title: String {
        if calendar.isDateInToday(date) {
            return "Today"
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    static func groups(
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> [FocusSessionHistoryDayGroup] {
        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.endedAt)
        }

        return grouped
            .map { date, records in
                FocusSessionHistoryDayGroup(
                    date: date,
                    records: records.sorted { $0.endedAt > $1.endedAt },
                    calendar: calendar
                )
            }
            .sorted { $0.date > $1.date }
    }
}

private struct FocusSessionHistoryDayCard: View {
    let group: FocusSessionHistoryDayGroup

    var body: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(group.title)
                        .font(BetaFocusedDashboardTypography.section)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                    Spacer(minLength: 0)

                    Text("\(group.minutes)m • \(group.completedBlocks) block\(group.completedBlocks == 1 ? "" : "s")")
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                }

                VStack(spacing: 0) {
                    ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                        FocusSessionHistoryDetailRow(record: record)

                        if index < group.records.count - 1 {
                            Divider()
                                .overlay(BetaFocusedDashboardPalette.border)
                                .padding(.leading, 46)
                        }
                    }
                }
            }
        }
    }
}

private struct FocusSessionHistoryDetailRow: View {
    let record: FocusSessionRecord

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: record.category.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.taskTitle.isEmpty ? "Focus session" : record.taskTitle)
                    .font(BetaFocusedDashboardTypography.taskTitle.weight(.semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(timeRange)
                    Text("•")
                    Text(record.completedBlock ? "Completed block" : "Partial")
                }
                .font(BetaFocusedDashboardTypography.bodySmall)
                .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)

            Text("\(record.durationMinutes)m")
                .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tint.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 9)
    }

    private var timeRange: String {
        let start = BetaFocusedDashboardTimeFormatter.timeOnly.string(from: record.startedAt)
        let end = BetaFocusedDashboardTimeFormatter.timeOnly.string(from: record.endedAt)
        return "\(start)-\(end)"
    }

    private var tint: Color {
        switch record.category {
        case .finance: BetaFocusedDashboardPalette.financeTint
        case .health: BetaFocusedDashboardPalette.healthTint
        case .work: BetaFocusedDashboardPalette.workTint
        case .home: BetaFocusedDashboardPalette.homeTint
        case .personal: BetaFocusedDashboardPalette.personalTint
        case .other: BetaFocusedDashboardPalette.otherTint
        }
    }
}

private struct FocusSessionHistoryMetric: View {
    let value: String
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(BetaFocusedDashboardTypography.body.weight(.semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                    .monospacedDigit()

                Text(title)
                    .font(BetaFocusedDashboardTypography.bodySmall)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
        }
    }
}
