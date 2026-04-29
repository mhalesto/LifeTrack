//
//  BetaFocusedDashboardToolsView.swift
//  LifeTrack
//

import SwiftUI

struct BetaFocusedDashboardToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LifeTrackSettings.Keys.lastBackupDate) private var lastBackupTimestamp: Double = 0
    @State private var isAIConfigured = !ClaudeAPIKeyStore.current.isEmpty

    let dueTodayCount: Int
    let overdueCount: Int
    let inboxCount: Int
    let planPreview: BetaFocusedDashboardPlanPreviewModel
    let staleInboxCount: Int
    let oldestInboxLine: String?
    let totalCompletedCount: Int
    let focusQueueCount: Int
    let categoryCount: Int
    let deletedCount: Int
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
        .onAppear {
            isAIConfigured = !ClaudeAPIKeyStore.current.isEmpty
        }
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
                subtitle: planPreview.summary,
                systemImage: "wand.and.stars",
                tint: BetaFocusedDashboardPalette.heroAccent,
                action: onOpenPlanMyDay
            ),
            BetaFocusedDashboardToolsItem(
                title: "Focus",
                subtitle: focusQueueCount == 0 ? "Queue clear" : "\(focusQueueCount.formatted()) queued",
                systemImage: "scope",
                tint: BetaFocusedDashboardPalette.completedTint,
                action: { onNavigate(.focus) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Calendar",
                subtitle: dueTodayCount == 0 ? "Clear today" : "\(dueTodayCount.formatted()) due today",
                systemImage: "calendar",
                tint: BetaFocusedDashboardPalette.captureTint,
                action: { onNavigate(.calendar) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Inbox",
                subtitle: inboxCount == 0 ? "Inbox clear" : "\(inboxCount.formatted()) waiting",
                systemImage: "tray.full",
                tint: BetaFocusedDashboardPalette.captureTint,
                action: onOpenInbox
            ),
            BetaFocusedDashboardToolsItem(
                title: "Stats",
                subtitle: "\(totalCompletedCount.formatted()) done",
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
                subtitle: "Search files",
                systemImage: "doc.text",
                tint: BetaFocusedDashboardPalette.workTint,
                action: { onNavigate(.documents) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Money",
                subtitle: "Budget & spend",
                systemImage: "dollarsign.circle",
                tint: BetaFocusedDashboardPalette.homeTint,
                action: { onNavigate(.money) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Categories",
                subtitle: "\(categoryCount.formatted()) categories",
                systemImage: "tag",
                tint: BetaFocusedDashboardPalette.personalTint,
                action: onOpenCategories
            ),
            BetaFocusedDashboardToolsItem(
                title: "Settings",
                subtitle: "Profile & app",
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
                subtitle: overdueCount == 0 ? "Nothing overdue" : "\(overdueCount.formatted()) overdue",
                systemImage: "lifepreserver",
                tint: BetaFocusedDashboardPalette.overdueTint,
                action: onOpenOverdueRescue
            ),
            BetaFocusedDashboardToolsItem(
                title: "Weekly Review",
                subtitle: "This week",
                systemImage: "calendar.badge.clock",
                tint: BetaFocusedDashboardPalette.completedTint,
                action: { onNavigate(.weeklyReview) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "AI Suggestions",
                subtitle: isAIConfigured ? "Ready" : "Needs API key",
                systemImage: "sparkles",
                tint: BetaFocusedDashboardPalette.warningTint,
                action: { onNavigate(.aiSuggestions) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Backup",
                subtitle: backupSubtitle,
                systemImage: "icloud",
                tint: BetaFocusedDashboardPalette.financeTint,
                action: { onNavigate(.backup) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Import / Export",
                subtitle: "CSV & backup",
                systemImage: "arrow.up.arrow.down",
                tint: BetaFocusedDashboardPalette.importExportTint,
                action: { onNavigate(.taskData) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Bin",
                subtitle: deletedCount == 0 ? "0 deleted" : "\(deletedCount.formatted()) deleted",
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

    private var backupSubtitle: String {
        guard lastBackupTimestamp > 0 else { return "Never backed up" }
        let backupDate = Date(timeIntervalSince1970: lastBackupTimestamp)
        return "Backed up \(backupDate.formatted(.dateTime.month(.abbreviated).day()))"
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
                            BetaFocusedDashboardToolsTile(item: item)
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
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var id: String { title }
}

private struct BetaFocusedDashboardToolsTile: View {
    let item: BetaFocusedDashboardToolsItem

    var body: some View {
        Button(action: item.action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(item.tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(item.tint)
                    }

                Text(item.title)
                    .font(BetaFocusedDashboardTypography.bodySmall.weight(.semibold))
                    .foregroundStyle(item.tint)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(item.subtitle)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(BetaFocusedDashboardPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
            }
            .frame(width: 104)
            .frame(minHeight: 112)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaFocusedDashboardPalette.border, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
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
