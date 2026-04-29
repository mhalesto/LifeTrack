//
//  BetaFocusedDashboardToolsView.swift
//  LifeTrack
//

import SwiftData
import SwiftUI

struct BetaFocusedDashboardToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var aiAdvisor = AITaskAdvisor.shared
    @Query(sort: \FocusSessionRecord.endedAt, order: .reverse) private var focusSessionRecords: [FocusSessionRecord]
    @AppStorage(LifeTrackSettings.Keys.lastBackupDate) private var lastBackupTimestamp: Double = 0
    @AppStorage(LifeTrackSettings.Keys.lastWeeklyReviewDate) private var lastWeeklyReviewTimestamp: Double = 0

    let dueTodayCount: Int
    let overdueCount: Int
    let inboxCount: Int
    let planPreview: BetaFocusedDashboardPlanPreviewModel
    let staleInboxCount: Int
    let oldestInboxLine: String?
    let totalCompletedCount: Int
    let focusQueueCount: Int
    let documentCount: Int
    let moneyMonthlySubtitle: String
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
                subtitle: focusSubtitle,
                systemImage: "scope",
                tint: BetaFocusedDashboardPalette.completedTint,
                action: { onNavigate(.focus) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Calendar",
                subtitle: dueTodayCount == 0 ? "Clear today" : "\(BetaFocusedDashboardFormat.count(dueTodayCount)) due today",
                systemImage: "calendar",
                tint: BetaFocusedDashboardPalette.captureTint,
                action: { onNavigate(.calendar) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Inbox",
                subtitle: inboxCount == 0 ? "Inbox clear" : "\(BetaFocusedDashboardFormat.count(inboxCount)) waiting",
                systemImage: "tray.full",
                tint: BetaFocusedDashboardPalette.captureTint,
                action: onOpenInbox
            ),
            BetaFocusedDashboardToolsItem(
                title: "Stats",
                subtitle: "\(BetaFocusedDashboardFormat.count(totalCompletedCount)) done",
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
                subtitle: documentCount == 0 ? "No files yet" : "\(BetaFocusedDashboardFormat.count(documentCount)) files",
                systemImage: "doc.text",
                tint: BetaFocusedDashboardPalette.workTint,
                action: { onNavigate(.documents) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Money",
                subtitle: moneyMonthlySubtitle,
                systemImage: "dollarsign.circle",
                tint: BetaFocusedDashboardPalette.homeTint,
                action: { onNavigate(.money) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "Categories",
                subtitle: "\(BetaFocusedDashboardFormat.count(categoryCount)) categories",
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
                subtitle: overdueCount == 0 ? "Nothing overdue" : "\(BetaFocusedDashboardFormat.count(overdueCount)) overdue",
                systemImage: "lifepreserver",
                tint: BetaFocusedDashboardPalette.overdueTint,
                action: onOpenOverdueRescue
            ),
            BetaFocusedDashboardToolsItem(
                title: "Weekly Review",
                subtitle: weeklyReviewSubtitle,
                systemImage: "calendar.badge.clock",
                tint: BetaFocusedDashboardPalette.completedTint,
                action: { onNavigate(.weeklyReview) }
            ),
            BetaFocusedDashboardToolsItem(
                title: "AI Suggestions",
                subtitle: aiSuggestionSubtitle,
                systemImage: "sparkles",
                tint: BetaFocusedDashboardPalette.warningTint,
                isLoading: aiAdvisor.isLoading,
                action: aiAdvisor.isConfigured ? { onNavigate(.aiSuggestions) } : onOpenSettings
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
                subtitle: deletedCount == 0 ? "0 deleted" : "\(BetaFocusedDashboardFormat.count(deletedCount)) deleted",
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
                    detail: "\(BetaFocusedDashboardFormat.count(overdueCount)) tasks need cleanup",
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
                    detail: oldestInboxLine ?? "\(BetaFocusedDashboardFormat.count(staleInboxCount)) older than a day",
                    systemImage: "tray.and.arrow.down",
                    tint: BetaFocusedDashboardPalette.warningTint,
                    action: onOpenInbox
                )
            )
        } else if inboxCount > 0 {
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: "Review inbox",
                    detail: "\(BetaFocusedDashboardFormat.count(inboxCount)) waiting to become tasks",
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

        if focusQueueCount > 0 && focusSummary.todayMinutes == 0 {
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: "Start focus block",
                    detail: "\(BetaFocusedDashboardFormat.count(focusQueueCount)) queued • 0 min today",
                    systemImage: "scope",
                    tint: BetaFocusedDashboardPalette.completedTint,
                    action: { onNavigate(.focus) }
                )
            )
        }

        if lastBackupTimestamp == 0 {
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: "Create backup",
                    detail: "No backup has been made yet",
                    systemImage: "icloud.and.arrow.up",
                    tint: BetaFocusedDashboardPalette.financeTint,
                    action: { onNavigate(.backup) }
                )
            )
        }

        let pendingAISuggestions = aiAdvisor.focusSuggestions.count + aiAdvisor.rescheduleSuggestions.count
        if !aiAdvisor.isConfigured {
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: "Set up AI",
                    detail: "API key needed for suggestions",
                    systemImage: "sparkles",
                    tint: BetaFocusedDashboardPalette.warningTint,
                    action: onOpenSettings
                )
            )
        } else if pendingAISuggestions > 0 || aiAdvisor.isLoading {
            items.append(
                BetaFocusedDashboardToolsSuggestion(
                    title: aiAdvisor.isLoading ? "AI is scanning" : "Review AI suggestions",
                    detail: aiAdvisor.isLoading ? "Suggestions are being prepared" : "\(BetaFocusedDashboardFormat.count(pendingAISuggestions)) pending",
                    systemImage: "sparkles",
                    tint: BetaFocusedDashboardPalette.warningTint,
                    action: { onNavigate(.aiSuggestions) }
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

    private var focusSummary: FocusSessionSummary {
        FocusSessionSummary(records: focusSessionRecords)
    }

    private var focusSubtitle: String {
        if focusSummary.todayMinutes > 0 {
            if focusSummary.todayCompletedBlocks > 0 {
                return "\(focusMinutesLabel(focusSummary.todayMinutes)) today • \(BetaFocusedDashboardFormat.count(focusSummary.todayCompletedBlocks)) blocks"
            }
            return "\(focusMinutesLabel(focusSummary.todayMinutes)) today"
        }

        if focusSummary.activeDayStreak > 1 {
            return "\(BetaFocusedDashboardFormat.count(focusSummary.activeDayStreak)) day streak"
        }

        return focusQueueCount == 0 ? "Queue clear" : "\(BetaFocusedDashboardFormat.count(focusQueueCount)) queued"
    }

    private func focusMinutesLabel(_ minutes: Int) -> String {
        minutes > 999 ? "999+ min" : "\(minutes)m"
    }

    private var backupSubtitle: String {
        guard lastBackupTimestamp > 0 else { return "Never backed up" }
        let backupDate = Date(timeIntervalSince1970: lastBackupTimestamp)
        return "Backed up \(backupDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var weeklyReviewSubtitle: String {
        guard lastWeeklyReviewTimestamp > 0 else { return "Not reviewed" }
        let date = Date(timeIntervalSince1970: lastWeeklyReviewTimestamp)
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return "Reviewed this week"
        }
        return "Last \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var aiSuggestionSubtitle: String {
        guard aiAdvisor.isConfigured else { return "Needs API key" }
        let pending = aiAdvisor.focusSuggestions.count + aiAdvisor.rescheduleSuggestions.count
        if pending > 0 {
            return "\(BetaFocusedDashboardFormat.count(pending)) pending"
        }
        if aiAdvisor.isLoading {
            return "Scanning"
        }
        return "Ready to scan"
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
    var isLoading = false
    let action: () -> Void

    var id: String { title }
}

private struct BetaFocusedDashboardToolsTile: View {
    let item: BetaFocusedDashboardToolsItem

    var body: some View {
        Button {
            LifeTrackHaptics.lightImpact()
            item.action()
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(item.tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if item.isLoading {
                            ProgressView()
                                .tint(item.tint)
                        } else {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(item.tint)
                        }
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
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
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
        Button {
            LifeTrackHaptics.lightImpact()
            item.action()
        } label: {
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
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97, pressedOpacity: 0.92))
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
                Text(BetaFocusedDashboardFormat.count(value))
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
