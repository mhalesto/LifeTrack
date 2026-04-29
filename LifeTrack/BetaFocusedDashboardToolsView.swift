//
//  BetaFocusedDashboardToolsView.swift
//  LifeTrack
//

import SwiftUI

struct BetaFocusedDashboardToolsView: View {
    @Environment(\.dismiss) private var dismiss

    let dueTodayCount: Int
    let overdueCount: Int
    let inboxCount: Int
    let planPreview: BetaFocusedDashboardPlanPreviewModel
    let staleInboxCount: Int
    let oldestInboxLine: String?
    let onNavigate: (BetaFocusedDashboardRoute) -> Void
    let onOpenPlanMyDay: () -> Void
    let onOpenOverdueRescue: () -> Void
    let onOpenSettings: () -> Void
    let onOpenCategories: () -> Void
    let onOpenInbox: () -> Void

    var body: some View {
        ZStack {
            BetaFocusedDashboardBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    statusStrip
                    suggestedNextSection
                    toolSection(title: "Daily", items: dailyTools)
                    toolSection(title: "Organize", items: organizationTools)
                    toolSection(title: "Review", items: reviewTools)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 92)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
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
                Text("Tools")
                    .font(BetaFocusedDashboardTypography.greeting)
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                Text("Quick access to essentials")
                    .font(BetaFocusedDashboardTypography.date)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            BetaFocusedDashboardToolsMetric(
                title: "Due Today",
                value: dueTodayCount,
                systemImage: "calendar",
                tint: BetaFocusedDashboardPalette.dueTodayTint
            )

            BetaFocusedDashboardToolsMetric(
                title: "Overdue",
                value: overdueCount,
                systemImage: "exclamationmark.circle",
                tint: BetaFocusedDashboardPalette.overdueTint
            )

            BetaFocusedDashboardToolsMetric(
                title: "Inbox",
                value: inboxCount,
                systemImage: "tray.full",
                tint: BetaFocusedDashboardPalette.captureTint
            )
        }
    }

    private var dailyTools: [BetaFocusedDashboardToolsItem] {
        [
            BetaFocusedDashboardToolsItem(
                title: "Plan My Day",
                systemImage: "wand.and.stars",
                tint: BetaFocusedDashboardPalette.heroAccent,
                action: onOpenPlanMyDay
            ),
            BetaFocusedDashboardToolsItem(
                title: "Calendar",
                systemImage: "calendar",
                tint: BetaFocusedDashboardPalette.captureTint,
                action: { onNavigate(.calendar) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Inbox",
                systemImage: "tray.full",
                tint: BetaFocusedDashboardPalette.captureTint,
                action: onOpenInbox
            ),
            BetaFocusedDashboardToolsItem(
                title: "Stats",
                systemImage: "chart.bar.fill",
                tint: BetaFocusedDashboardPalette.statsPillText,
                action: { onNavigate(.statistics) }
            )
        ]
    }

    private var organizationTools: [BetaFocusedDashboardToolsItem] {
        [
            BetaFocusedDashboardToolsItem(
                title: "Documents",
                systemImage: "doc.text",
                tint: BetaFocusedDashboardPalette.workTint,
                action: { onNavigate(.documents) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Money",
                systemImage: "dollarsign.circle",
                tint: BetaFocusedDashboardPalette.homeTint,
                action: { onNavigate(.money) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Categories",
                systemImage: "tag",
                tint: BetaFocusedDashboardPalette.personalTint,
                action: onOpenCategories
            ),
            BetaFocusedDashboardToolsItem(
                title: "Settings",
                systemImage: "gearshape",
                tint: BetaFocusedDashboardPalette.statsPillText,
                action: onOpenSettings
            )
        ]
    }

    private var reviewTools: [BetaFocusedDashboardToolsItem] {
        [
            BetaFocusedDashboardToolsItem(
                title: "Rescue",
                systemImage: "lifepreserver",
                tint: BetaFocusedDashboardPalette.overdueTint,
                action: onOpenOverdueRescue
            ),
            BetaFocusedDashboardToolsItem(
                title: "Weekly Review",
                systemImage: "calendar.badge.clock",
                tint: BetaFocusedDashboardPalette.completedTint,
                action: { onNavigate(.weeklyReview) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "AI Suggestions",
                systemImage: "sparkles",
                tint: BetaFocusedDashboardPalette.warningTint,
                action: { onNavigate(.aiSuggestions) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Backup",
                systemImage: "icloud",
                tint: BetaFocusedDashboardPalette.financeTint,
                action: { onNavigate(.backup) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Import / Export",
                systemImage: "arrow.up.arrow.down",
                tint: BetaFocusedDashboardPalette.importExportTint,
                action: { onNavigate(.taskData) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Bin",
                systemImage: "trash",
                tint: BetaFocusedDashboardPalette.overdueTint,
                action: { onNavigate(.bin) }
            )
        ]
    }

    private var suggestedItems: [BetaFocusedDashboardToolsSuggestion] {
        var items: [BetaFocusedDashboardToolsSuggestion] = []

        if overdueCount > 0 {
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: "Rescue overdue",
                    detail: "\(overdueCount.formatted()) tasks need cleanup",
                    systemImage: "lifepreserver",
                    tint: BetaFocusedDashboardPalette.overdueTint,
                    action: onOpenOverdueRescue
                )
            )
        }

        if staleInboxCount > 0 {
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: "Process old captures",
                    detail: oldestInboxLine ?? "\(staleInboxCount.formatted()) older than a day",
                    systemImage: "tray.and.arrow.down",
                    tint: BetaFocusedDashboardPalette.warningTint,
                    action: onOpenInbox
                )
            )
        } else if inboxCount > 0 {
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: "Review inbox",
                    detail: "\(inboxCount.formatted()) waiting to become tasks",
                    systemImage: "tray.full",
                    tint: BetaFocusedDashboardPalette.captureTint,
                    action: onOpenInbox
                )
            )
        }

        if dueTodayCount > 0 || planPreview.rescueCount > 0 {
            let detail = planPreview.detail.isEmpty ? "Calendar-aware planning is ready" : planPreview.detail
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: planPreview.summary,
                    detail: detail,
                    systemImage: "wand.and.stars",
                    tint: BetaFocusedDashboardPalette.heroAccent,
                    action: onOpenPlanMyDay
                )
            )
        }

        if items.isEmpty {
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: "Weekly Review",
                    detail: "Check progress and reset priorities",
                    systemImage: "calendar.badge.clock",
                    tint: BetaFocusedDashboardPalette.completedTint,
                    action: { onNavigate(.weeklyReview) }
                )
            )
        }

        return items
    }

    private var suggestedNextSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Suggested Next")
                    .font(BetaFocusedDashboardTypography.section)
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                Spacer(minLength: 0)

                Text("Smart shortcuts")
                    .font(BetaFocusedDashboardTypography.bodySmall)
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
            }

            GeometryReader { proxy in
                let cardWidth = min(max(proxy.size.width - 4, 250), 320)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(suggestedItems) { item in
                            BetaFocusedDashboardToolsSuggestionCard(item: item, width: cardWidth)
                        }
                    }
                    .padding(.vertical, 1)
                    .padding(.trailing, 8)
                }
                .scrollIndicators(.hidden)
            }
            .frame(height: 84)
        }
    }

    private func toolSection(title: String, items: [BetaFocusedDashboardToolsItem]) -> some View {
        BetaFocusedDashboardCard(background: BetaFocusedDashboardPalette.cardSecondary) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(BetaFocusedDashboardTypography.section)
                    .foregroundStyle(BetaFocusedDashboardPalette.headerText)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(items) { item in
                            BetaFocusedDashboardToolTile(
                                title: item.title,
                                systemImage: item.systemImage,
                                tint: item.tint,
                                action: item.action
                            )
                        }
                    }
                    .padding(.vertical, 1)
                    .padding(.trailing, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

private struct BetaFocusedDashboardToolsItem: Identifiable {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var id: String { title }
}

private struct BetaFocusedDashboardToolsSuggestion: Identifiable {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var id: String { title }
}

private struct BetaFocusedDashboardToolsSuggestionCard: View {
    let item: BetaFocusedDashboardToolsSuggestion
    let width: CGFloat

    var body: some View {
        Button(action: item.action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(item.tint.opacity(0.14))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(item.tint)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(BetaFocusedDashboardTypography.taskTitle.weight(.semibold))
                        .foregroundStyle(BetaFocusedDashboardPalette.headerText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(item.detail)
                        .font(BetaFocusedDashboardTypography.bodySmall.weight(.medium))
                        .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(item.tint)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .frame(width: width)
            .frame(minHeight: 74)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(item.tint.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct BetaFocusedDashboardToolsMetric: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value.formatted())
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
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
        }
    }
}
