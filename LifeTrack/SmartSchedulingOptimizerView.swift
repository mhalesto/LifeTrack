//
//  SmartSchedulingOptimizerView.swift
//  LifeTrack
//

import EventKit
import SwiftData
import SwiftUI
import UIKit

struct SmartSchedulingOptimizerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]
    @ObservedObject private var advisor = SmartSchedulingAdvisor.shared
    @ObservedObject private var energyReader = HealthKitEnergyReader.shared
    @ObservedObject private var calendarManager = CalendarIntegrationManager.shared

    let tasks: [LifeTask]

    @State private var isApplyingSchedule = false
    @State private var applyFeedback: ScheduleApplyFeedback?

    private let gold = Color(red: 0.95, green: 0.72, blue: 0.1)

    var body: some View {
        ZStack(alignment: .top) {
            LifeTrackTheme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    content
                        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                        .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText.opacity(0.7))
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(LifeTrackTheme.Spacing.xLarge)
        }
        .task(id: scheduleRefreshKey) {
            await refreshSchedule(forceCalendarReload: false)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.06, blue: 0.28), Color(red: 0.07, green: 0.04, blue: 0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 14) {
                Spacer().frame(height: 48)
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 72, height: 72)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(gold)
                }
                VStack(spacing: 6) {
                    Text("Smart Scheduling")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Image(systemName: energyReader.energyLevel.sfSymbol)
                            .font(.caption)
                            .foregroundStyle(energyReader.energyLevel.color)
                        Text(headerSubtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                Spacer().frame(height: 24)
            }
        }
        .frame(height: 210)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if advisor.isLoading {
            loadingView
        } else if let error = advisor.error {
            errorView(error)
        } else {
            scheduleContent
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            ProgressView()
                .scaleEffect(1.4)
                .tint(gold)
            Text("Building your optimal schedule…")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 32)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await refreshSchedule(forceCalendarReload: true)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(gold)
        }
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
    }

    private var scheduleContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            calendarStatusCard

            if let applyFeedback {
                applyFeedbackCard(applyFeedback)
            }

            if !advisor.dayStrategy.isEmpty {
                strategyCard
            }

            if !advisor.scheduledBlocks.isEmpty {
                timelineSection
                applySection
            }

            if !advisor.unscheduledTitles.isEmpty {
                unscheduledSection
            }

            refreshButton
        }
        .padding(.top, LifeTrackTheme.Spacing.xLarge)
    }

    // MARK: - Status

    private var calendarStatusCard: some View {
        SectionCardView {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: calendarStatusSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(calendarStatusTint)
                    .frame(width: 32, height: 32)
                    .background(calendarStatusTint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(calendarStatusTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(calendarStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if let actionTitle = calendarActionTitle {
                    Button(actionTitle, action: handleCalendarAction)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(calendarStatusTint)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(calendarStatusTint.opacity(0.1), in: Capsule())
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
                        .disabled(calendarManager.isRequestingAccess || calendarManager.isLoadingBusyBlocks)
                } else if calendarManager.isLoadingBusyBlocks {
                    ProgressView()
                        .tint(calendarStatusTint)
                }
            }
        }
    }

    private var strategyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.3))
                .frame(width: 32, height: 32)
                .background(Color(red: 0.95, green: 0.82, blue: 0.3).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Today's Strategy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.3))
                Text(advisor.dayStrategy)
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LifeTrackTheme.Spacing.medium)
        .background(Color(red: 0.95, green: 0.82, blue: 0.3).opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.95, green: 0.82, blue: 0.3).opacity(0.2), lineWidth: 1)
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(gold)
                Text("Optimized Schedule")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }

            VStack(spacing: 0) {
                ForEach(Array(advisor.scheduledBlocks.enumerated()), id: \.element.id) { index, block in
                    blockRow(block, isLast: index == advisor.scheduledBlocks.count - 1)
                }
            }
            .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func blockRow(_ block: ScheduledBlock, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 2) {
                    Text(block.start)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(gold)
                        .monospacedDigit()
                    Text(block.end)
                        .font(.caption2)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        .monospacedDigit()
                }
                .frame(width: 44)

                Rectangle()
                    .fill(gold.opacity(0.3))
                    .frame(width: 2)
                    .frame(height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(block.taskTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)
                    Text(block.reasoning)
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                Text(block.energyTag)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(gold.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(gold.opacity(0.3), lineWidth: 1))
            }
            .padding(LifeTrackTheme.Spacing.medium)

            if !isLast {
                Divider()
                    .padding(.horizontal, LifeTrackTheme.Spacing.medium)
            }
        }
    }

    private var applySection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await applySchedule(syncToCalendar: false) }
            } label: {
                HStack(spacing: 8) {
                    if isApplyingSchedule {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text("Apply to Tasks")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
            .disabled(isApplyingSchedule)

            if calendarManager.hasReadAccess {
                Button {
                    Task { await applySchedule(syncToCalendar: true) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                        Text("Apply + Sync Calendar")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
                .disabled(isApplyingSchedule)
            }
        }
    }

    // MARK: - Unscheduled

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(spacing: 6) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                Text("Carry Over")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
                ForEach(Array(advisor.unscheduledTitles.enumerated()), id: \.offset) { _, title in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.medium)
                    .padding(.vertical, 10)
                    .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    // MARK: - Refresh

    private var refreshButton: some View {
        VStack(spacing: 6) {
            Button {
                Task {
                    await refreshSchedule(forceCalendarReload: true)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Schedule")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if let date = advisor.lastRefreshed {
                Text("Last updated \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }
        }
    }

    // MARK: - Actions

    private var scheduleDayInterval: DateInterval {
        CalendarAwareScheduleEngine.dayLoadInterval(for: Date())
    }

    private var scheduleRefreshKey: String {
        "\(calendarManager.authorizationStatus.rawValue)-\(tasks.count)-\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
    }

    private var loadedBusyBlocks: [CalendarBusyBlock] {
        calendarManager.busyBlocks(overlapping: scheduleDayInterval)
    }

    private var headerSubtitle: String {
        let source = advisor.scheduleSourceLabel.isEmpty ? "Calendar-aware planning" : advisor.scheduleSourceLabel
        return "\(energyReader.energyLevel.label) · \(source) · Ultimate"
    }

    private var calendarStatusTitle: String {
        switch calendarManager.authorizationStatus {
        case .authorized, .fullAccess:
            return "Apple Calendar Connected"
        case .notDetermined, .writeOnly:
            return "Connect Apple Calendar"
        case .denied, .restricted:
            return "Apple Calendar Access Off"
        @unknown default:
            return "Apple Calendar Unavailable"
        }
    }

    private var calendarStatusMessage: String {
        switch calendarManager.authorizationStatus {
        case .authorized, .fullAccess:
            let count = loadedBusyBlocks.count
            return "\(count) busy \(count == 1 ? "event" : "events") reserved today. Only busy windows, not event titles, are used for AI scheduling."
        case .notDetermined:
            return "Connect Apple Calendar so Smart Scheduling avoids meetings, appointments, and other real busy time."
        case .writeOnly:
            return "LifeTrack needs full calendar access to read busy times before it can build a calendar-aware plan."
        case .denied, .restricted:
            return "Enable Calendar access in Settings to make Smart Scheduling respect your real day."
        @unknown default:
            return "Calendar status is unavailable right now."
        }
    }

    private var calendarStatusSymbol: String {
        switch calendarManager.authorizationStatus {
        case .authorized, .fullAccess:
            return "calendar.badge.checkmark"
        case .denied, .restricted:
            return "calendar.badge.exclamationmark"
        default:
            return "calendar.badge.plus"
        }
    }

    private var calendarStatusTint: Color {
        switch calendarManager.authorizationStatus {
        case .authorized, .fullAccess:
            return LifeTrackTheme.ColorPalette.success
        case .denied, .restricted:
            return LifeTrackTheme.ColorPalette.warning
        default:
            return gold
        }
    }

    private var calendarActionTitle: String? {
        if calendarManager.needsPermissionPrompt {
            return "Connect"
        }

        switch calendarManager.authorizationStatus {
        case .denied, .restricted:
            return "Settings"
        default:
            return nil
        }
    }

    private func handleCalendarAction() {
        if calendarManager.needsPermissionPrompt {
            Task {
                let granted = await calendarManager.requestAccessIfNeeded()
                guard granted else { return }
                await refreshSchedule(forceCalendarReload: true)
            }
            return
        }

        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            openURL(settingsURL)
        }
    }

    private func refreshSchedule(forceCalendarReload: Bool) async {
        await calendarManager.loadBusyBlocks(in: scheduleDayInterval, force: forceCalendarReload)
        await energyReader.refresh()
        await advisor.optimize(
            tasks: tasks,
            energyLevel: energyReader.energyLevel,
            busyBlocks: loadedBusyBlocks,
            referenceDate: Date()
        )
    }

    @MainActor
    private func applySchedule(syncToCalendar: Bool) async {
        guard !advisor.scheduledBlocks.isEmpty else {
            return
        }

        isApplyingSchedule = true
        defer { isApplyingSchedule = false }

        let scheduledBlocksByTaskID = Dictionary(uniqueKeysWithValues: advisor.scheduledBlocks.map { ($0.taskID, $0) })
        let now = Date()

        for task in tasks {
            guard let block = scheduledBlocksByTaskID[task.id] else {
                continue
            }

            task.dueDate = block.startDate
            task.estimatedDurationMinutes = block.durationMinutes
            task.updatedAt = now
        }

        do {
            try modelContext.save()
        } catch {
            applyFeedback = ScheduleApplyFeedback(
                title: "Couldn’t apply schedule",
                message: error.localizedDescription,
                tint: LifeTrackTheme.ColorPalette.danger,
                symbolName: "exclamationmark.circle.fill"
            )
            return
        }

        for task in tasks where scheduledBlocksByTaskID[task.id] != nil {
            TaskLifecycleManager.synchronizeReminder(for: task, customCategories: customCategories)
        }

        if syncToCalendar {
            var syncedCount = 0
            var removedCount = 0
            var failedCount = 0

            for task in tasks {
                if let block = scheduledBlocksByTaskID[task.id] {
                    do {
                        try calendarManager.upsertSyncedEvent(for: task, startDate: block.startDate, endDate: block.endDate)
                        syncedCount += 1
                    } catch {
                        failedCount += 1
                    }
                } else {
                    do {
                        try calendarManager.removeSyncedEvent(for: task.id)
                        removedCount += 1
                    } catch {
                        failedCount += 1
                    }
                }
            }

            if failedCount == 0 {
                applyFeedback = ScheduleApplyFeedback(
                    title: "Schedule applied",
                    message: calendarFeedbackMessage(syncedCount: syncedCount, removedCount: removedCount),
                    tint: LifeTrackTheme.ColorPalette.success,
                    symbolName: "checkmark.circle.fill"
                )
            } else {
                applyFeedback = ScheduleApplyFeedback(
                    title: "Tasks updated, calendar partial",
                    message: "LifeTrack updated the task schedule, but couldn’t sync \(failedCount) \(failedCount == 1 ? "event" : "events").",
                    tint: LifeTrackTheme.ColorPalette.warning,
                    symbolName: "exclamationmark.circle.fill"
                )
            }
        } else {
            applyFeedback = ScheduleApplyFeedback(
                title: "Schedule applied",
                message: "\(scheduledBlocksByTaskID.count) \(scheduledBlocksByTaskID.count == 1 ? "task" : "tasks") moved onto the new timeline.",
                tint: LifeTrackTheme.ColorPalette.success,
                symbolName: "checkmark.circle.fill"
            )
        }
    }

    private func applyFeedbackCard(_ feedback: ScheduleApplyFeedback) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feedback.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(feedback.tint)
                .frame(width: 32, height: 32)
                .background(feedback.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text(feedback.message)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LifeTrackTheme.Spacing.medium)
        .background(feedback.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(feedback.tint.opacity(0.18), lineWidth: 1)
        }
    }

    private func calendarFeedbackMessage(syncedCount: Int, removedCount: Int) -> String {
        if removedCount > 0 {
            return "\(syncedCount) \(syncedCount == 1 ? "task was" : "tasks were") synced and \(removedCount) stale \(removedCount == 1 ? "calendar block was" : "calendar blocks were") removed."
        }

        return "\(syncedCount) \(syncedCount == 1 ? "task was" : "tasks were") updated and synced to Apple Calendar."
    }
}

private struct ScheduleApplyFeedback {
    let title: String
    let message: String
    let tint: Color
    let symbolName: String
}
