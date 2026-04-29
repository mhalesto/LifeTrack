//
//  BetaFocusedDashboardFocusHistoryView.swift
//  LifeTrack
//

import SwiftUI

struct BetaFocusedDashboardFocusHistoryView: View {
    let records: [FocusSessionRecord]

    private var todayRecords: [FocusSessionRecord] {
        records.filter { Calendar.current.isDateInToday($0.endedAt) }
    }

    private var weekRecords: [FocusSessionRecord] {
        let calendar = Calendar.current
        return records.filter { calendar.isDate($0.endedAt, equalTo: Date(), toGranularity: .weekOfYear) }
    }

    private var todayMinutes: Int {
        todayRecords.reduce(0) { $0 + $1.durationMinutes }
    }

    private var weekMinutes: Int {
        weekRecords.reduce(0) { $0 + $1.durationMinutes }
    }

    private var todayCompletedBlocks: Int {
        todayRecords.filter(\.completedBlock).count
    }

    var body: some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Session History")
                        .font(BetaFocusedDashboardTypography.section)
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                    Spacer(minLength: 0)

                    Text(records.isEmpty ? "No sessions" : "\(BetaFocusedDashboardFormat.count(records.count)) total")
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                }

                HStack(spacing: 8) {
                    FocusHistoryMetric(
                        value: "\(todayMinutes)",
                        title: "Min Today",
                        systemImage: "timer",
                        tint: BetaFocusedDashboardPalette.heroAccent
                    )

                    FocusHistoryMetric(
                        value: "\(weekMinutes)",
                        title: "Min Week",
                        systemImage: "calendar.badge.clock",
                        tint: BetaFocusedDashboardPalette.completedTint
                    )

                    FocusHistoryMetric(
                        value: "\(todayCompletedBlocks)",
                        title: "Blocks",
                        systemImage: "checkmark.seal",
                        tint: BetaFocusedDashboardPalette.captureTint
                    )
                }

                if records.isEmpty {
                    Text("Completed focus blocks and meaningful partial sessions will appear here.")
                        .font(BetaFocusedDashboardTypography.body)
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(records.prefix(3).enumerated()), id: \.element.id) { index, record in
                            FocusHistoryRow(record: record)

                            if index < min(records.count, 3) - 1 {
                                Divider()
                                    .overlay(BetaFocusedDashboardPalette.border)
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FocusHistoryMetric: View {
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

private struct FocusHistoryRow: View {
    let record: FocusSessionRecord

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: record.category.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(record.taskTitle.isEmpty ? "Focus session" : record.taskTitle)
                    .font(BetaFocusedDashboardTypography.body.weight(.semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                    .lineLimit(1)

                Text(detail)
                    .font(BetaFocusedDashboardTypography.bodySmall)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("\(record.durationMinutes)m")
                .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tint.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 8)
    }

    private var detail: String {
        let time = BetaFocusedDashboardTimeFormatter.timeOnly.string(from: record.endedAt)
        return record.completedBlock ? "Completed at \(time)" : "Ended at \(time)"
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
