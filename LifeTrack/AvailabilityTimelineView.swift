//
//  AvailabilityTimelineView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import EventKit
import SwiftUI
import UIKit

enum AvailabilityShareRange: String, CaseIterable, Identifiable {
    case today
    case week
    case thirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .week: "This Week"
        case .thirtyDays: "Next 30 Days"
        }
    }

    var compactTitle: String {
        switch self {
        case .today: "Today"
        case .week: "Week"
        case .thirtyDays: "30 Days"
        }
    }
}

struct AvailabilityTimelineView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var calendarManager = CalendarIntegrationManager.shared
    @State private var isShowingShareComposer = false

    let selectedDate: Date
    @Binding var selectedRange: AvailabilityShareRange
    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            header
            calendarStatusCard
            AvailabilityRangeSelector(selectedRange: $selectedRange)

            SectionCardView {
                rangeSummary
                metrics

                if selectedRange == .today {
                    dayTimeline(schedule: primarySchedule)
                } else {
                    rangeOverview
                }
            }
        }
        .task(id: availabilityLoadKey) {
            await calendarManager.loadBusyBlocks(in: selectedLoadInterval)
        }
        .sheet(isPresented: $isShowingShareComposer) {
            AvailabilityShareComposerView(snapshot: shareSnapshot)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: LifeTrackTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Availability")
                    .font(.lifeTrackHeadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(headerSubtitle)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.medium)

            Button {
                isShowingShareComposer = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.94, pressedOpacity: 0.9))
            .accessibilityLabel("Share \(selectedRange.title.lowercased()) availability")
        }
    }

    private var calendarStatusCard: some View {
        SectionCardView {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: calendarStatusSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(calendarStatusTint)
                    .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
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

                if let calendarActionTitle {
                    Button(calendarActionTitle, action: handleCalendarAction)
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

    private var rangeSummary: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: LifeTrackTheme.IconSize.largeCircle, height: LifeTrackTheme.IconSize.largeCircle)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Sharing \(selectedRange.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text("\(rangeDateSubtitle) · \(totalBlockCount) blocked \(totalBlockCount == 1 ? "item" : "items") · manual share only")
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.84), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.78), lineWidth: 0.8)
        }
    }

    private var metrics: some View {
        HStack(spacing: LifeTrackTheme.Spacing.small) {
            AvailabilityMetricPill(
                title: "Available",
                value: durationTitle(for: totalAvailableDuration),
                symbolName: "checkmark.circle",
                tint: LifeTrackTheme.ColorPalette.success
            )

            AvailabilityMetricPill(
                title: "Blocked",
                value: durationTitle(for: totalBlockedDuration),
                symbolName: "lock",
                tint: LifeTrackTheme.ColorPalette.warning
            )

            AvailabilityMetricPill(
                title: selectedRange == .today ? "Blocks" : "Days",
                value: selectedRange == .today ? totalBlockCount.formatted() : selectedDates.count.formatted(),
                symbolName: selectedRange == .today ? "list.bullet" : "calendar",
                tint: LifeTrackTheme.ColorPalette.accent
            )
        }
    }

    private func dayTimeline(schedule: AvailabilityDaySchedule) -> some View {
        VStack(spacing: 8) {
            ForEach(schedule.segments) { segment in
                AvailabilityTimelineRow(segment: segment)
            }
        }
    }

    private var rangeOverview: some View {
        VStack(spacing: 8) {
            ForEach(daySchedules) { schedule in
                AvailabilityDaySummaryRow(schedule: schedule)
            }
        }
    }

    private var selectedDates: [Date] {
        switch selectedRange {
        case .today:
            return [calendar.startOfDay(for: selectedDate)]
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
                return [calendar.startOfDay(for: selectedDate)]
            }

            return (0..<7).compactMap {
                calendar.date(byAdding: .day, value: $0, to: interval.start)
            }
        case .thirtyDays:
            let start = calendar.startOfDay(for: selectedDate)
            return (0..<30).compactMap {
                calendar.date(byAdding: .day, value: $0, to: start)
            }
        }
    }

    private var daySchedules: [AvailabilityDaySchedule] {
        selectedDates.map(schedule(for:))
    }

    private var primarySchedule: AvailabilityDaySchedule {
        daySchedules.first ?? schedule(for: selectedDate)
    }

    private var totalAvailableDuration: TimeInterval {
        daySchedules.reduce(0) { $0 + $1.availableDuration }
    }

    private var totalBlockedDuration: TimeInterval {
        daySchedules.reduce(0) { $0 + $1.blockedDuration }
    }

    private var totalBlockCount: Int {
        daySchedules.reduce(0) { $0 + $1.blocks.count }
    }

    private var selectedLoadInterval: DateInterval {
        let start = selectedDates.first ?? calendar.startOfDay(for: selectedDate)
        let lastDate = selectedDates.last ?? start
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDate)) ?? lastDate.addingTimeInterval(86_400)
        return DateInterval(start: calendar.startOfDay(for: start), end: end)
    }

    private var availabilityLoadKey: String {
        "\(selectedRange.rawValue)-\(calendar.startOfDay(for: selectedDate).timeIntervalSince1970)-\(calendarManager.authorizationStatus.rawValue)"
    }

    private var rangeDateSubtitle: String {
        guard let first = selectedDates.first, let last = selectedDates.last else {
            return selectedDate.weekdayDateString
        }

        if selectedRange == .today {
            return first.weekdayDateString
        }

        return "\(first.dayMonthString)-\(last.dayMonthString)"
    }

    private var shareSnapshot: AvailabilityShareSnapshot {
        AvailabilityShareSnapshot(
            range: selectedRange,
            rangeTitle: selectedRange.title,
            dateSubtitle: rangeDateSubtitle,
            availableDurationTitle: durationTitle(for: totalAvailableDuration),
            blockedDurationTitle: durationTitle(for: totalBlockedDuration),
            blockCount: totalBlockCount,
            totalDayCount: selectedDates.count,
            includesCalendarBusyTimes: calendarBusyBlockCount > 0,
            days: daySchedules.map(shareDaySnapshot(from:))
        )
    }

    private func shareDaySnapshot(from schedule: AvailabilityDaySchedule) -> AvailabilityShareDaySnapshot {
        let entries = schedule.segments.map { segment -> AvailabilityShareEntrySnapshot in
            switch segment.kind {
            case .available:
                return AvailabilityShareEntrySnapshot(
                    kind: .available,
                    title: "Available",
                    subtitle: "Open window between scheduled task blocks.",
                    timeRangeTitle: segment.timeRangeTitle
                )
            case .blocked(let block):
                return AvailabilityShareEntrySnapshot(
                    kind: block.isCalendarEvent ? .calendar : .task,
                    title: block.shareTitle,
                    subtitle: block.shareSubtitle,
                    timeRangeTitle: segment.timeRangeTitle
                )
            }
        }

        return AvailabilityShareDaySnapshot(
            date: schedule.date,
            title: schedule.date.formatted(Date.FormatStyle().weekday(.wide).month(.abbreviated).day()),
            availableDurationTitle: durationTitle(for: schedule.availableDuration),
            blockedDurationTitle: durationTitle(for: schedule.blockedDuration),
            blockCount: schedule.blocks.count,
            availableRanges: schedule.segments.filter(\.isAvailable).map(\.timeRangeTitle),
            entries: entries,
            firstBlockedTitle: entries.first(where: { $0.kind != .available })?.title
        )
    }

    private func schedule(for date: Date) -> AvailabilityDaySchedule {
        let blocks = blocks(on: date)
        let window = dayWindow(for: date, blocks: blocks)
        let segments = timelineSegments(for: blocks, in: window)

        return AvailabilityDaySchedule(
            date: calendar.startOfDay(for: date),
            blocks: blocks,
            segments: segments,
            window: window
        )
    }

    @MainActor
    private func blocks(on date: Date) -> [AvailabilityTimeBlock] {
        let taskBlocks = tasks
            .filter { task in
                !task.isDeleted &&
                    !task.isCompleted &&
                    calendar.isDate(task.dueDate, inSameDayAs: date)
            }
            .map { task in
                AvailabilityTimeBlock(
                    task: task,
                    categoryOption: task.categoryOption(customCategories: customCategories),
                    startDate: task.dueDate,
                    endDate: task.scheduledEndDate
                )
            }
        let dayInterval = DateInterval(
            start: calendar.startOfDay(for: date),
            end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86_400)
        )
        let calendarBlocks = calendarManager.busyBlocks(overlapping: dayInterval).map(AvailabilityTimeBlock.init(calendarBlock:))

        return (taskBlocks + calendarBlocks)
            .sorted { first, second in
                if first.startDate == second.startDate {
                    return first.endDate < second.endDate
                }

                return first.startDate < second.startDate
            }
    }

    private func dayWindow(for date: Date, blocks: [AvailabilityTimeBlock]) -> DateInterval {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let defaultStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? dayStart
        let defaultEnd = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: date) ?? dayEnd

        let earliestTaskDate = blocks.map(\.startDate).min()
        let latestTaskDate = blocks.map(\.endDate).max()
        let start = min(defaultStart, roundedDownToHour(earliestTaskDate ?? defaultStart))
        let end = max(defaultEnd, roundedUpToHour(latestTaskDate ?? defaultEnd))
        let clampedStart = max(dayStart, start)
        let clampedEnd = min(dayEnd, max(end, clampedStart.addingTimeInterval(60 * 60)))

        return DateInterval(start: clampedStart, end: clampedEnd)
    }

    private func timelineSegments(
        for blocks: [AvailabilityTimeBlock],
        in window: DateInterval
    ) -> [AvailabilityTimelineSegment] {
        guard !blocks.isEmpty else {
            return [.available(startDate: window.start, endDate: window.end)]
        }

        var segments: [AvailabilityTimelineSegment] = []
        var cursor = window.start

        for block in blocks {
            let visibleStart = max(block.startDate, window.start)
            let visibleEnd = min(max(block.endDate, visibleStart.addingTimeInterval(60 * 5)), window.end)
            guard visibleEnd > window.start, visibleStart < window.end else {
                continue
            }

            if visibleStart > cursor {
                segments.append(.available(startDate: cursor, endDate: visibleStart))
            }

            let blockedStart = max(visibleStart, cursor)
            if visibleEnd > blockedStart {
                segments.append(.blocked(block, startDate: blockedStart, endDate: visibleEnd))
            }

            cursor = max(cursor, visibleEnd)
        }

        if cursor < window.end {
            segments.append(.available(startDate: cursor, endDate: window.end))
        }

        return segments
    }

    private func roundedDownToHour(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: components) ?? date
    }

    private func roundedUpToHour(_ date: Date) -> Date {
        let startOfHour = roundedDownToHour(date)
        if startOfHour == date {
            return date
        }

        return calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? date
    }

    private func durationTitle(for duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration / 60))
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    private func timeRangeTitle(start: Date, end: Date) -> String {
        "\(start.timeString)-\(end.timeString)"
    }

    private var headerSubtitle: String {
        if calendarManager.hasReadAccess {
            return "Private blocked-time view using tasks plus live Apple Calendar busy events."
        }

        return "Private blocked-time view with optional Apple Calendar busy events."
    }

    private var calendarBusyBlockCount: Int {
        calendarManager.busyBlocks(overlapping: selectedLoadInterval).count
    }

    private var calendarStatusTitle: String {
        switch calendarManager.authorizationStatus {
        case .authorized, .fullAccess:
            return "Apple Calendar Connected"
        case .notDetermined, .writeOnly:
            return "Add Apple Calendar Busy Times"
        case .denied, .restricted:
            return "Apple Calendar Access Off"
        @unknown default:
            return "Apple Calendar Unavailable"
        }
    }

    private var calendarStatusMessage: String {
        switch calendarManager.authorizationStatus {
        case .authorized, .fullAccess:
            let count = calendarBusyBlockCount
            return "\(count) busy \(count == 1 ? "event" : "events") included in this range. Shared availability hides event titles."
        case .notDetermined:
            return "Connect Apple Calendar so shared availability and open windows respect your real meetings and appointments."
        case .writeOnly:
            return "LifeTrack needs full calendar access to read busy times. Event titles stay on-device."
        case .denied, .restricted:
            return "Enable Calendar access in Settings to include real busy times in availability."
        @unknown default:
            return "Calendar access is unavailable right now."
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
            return LifeTrackTheme.ColorPalette.accent
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
                await calendarManager.loadBusyBlocks(in: selectedLoadInterval, force: true)
            }
            return
        }

        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            openURL(settingsURL)
        }
    }
}

struct AvailabilityShareSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedRange: AvailabilityShareRange

    let tasks: [LifeTask]
    let customCategories: [CustomTaskCategory]
    let onOpenCalendar: () -> Void

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                    sheetHeader

                    AvailabilityTimelineView(
                        selectedDate: Date(),
                        selectedRange: $selectedRange,
                        tasks: tasks,
                        customCategories: customCategories
                    )
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.medium)
                .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Button("Done") {
                    dismiss()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.88), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.9))

                Spacer()

                Button(action: onOpenCalendar) {
                    HStack(spacing: 7) {
                        Image(systemName: "calendar")
                        Text("Open Calendar")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LifeTrackTheme.ColorPalette.accentGradient, in: Capsule())
                    .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.22), radius: 12, y: 7)
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Share Availability")
                    .font(.lifeTrackHero)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text("Choose a range, preview blocked time, then share a branded availability card.")
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AvailabilityRangeSelector: View {
    @Binding var selectedRange: AvailabilityShareRange
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AvailabilityShareRange.allCases) { range in
                Button {
                    select(range)
                } label: {
                    Text(range.compactTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selectedRange == range ? Color.white : LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedRange == range {
                                Capsule()
                                    .fill(LifeTrackTheme.ColorPalette.accentGradient)
                            }
                        }
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97, pressedOpacity: 0.92))
            }
        }
        .padding(4)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.88), in: Capsule())
        .overlay {
            Capsule()
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
        }
    }

    private func select(_ range: AvailabilityShareRange) {
        guard selectedRange != range else {
            return
        }

        guard animationsEnabled else {
            selectedRange = range
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            selectedRange = range
        }
    }
}

private struct AvailabilityDaySchedule: Identifiable {
    let date: Date
    let blocks: [AvailabilityTimeBlock]
    let segments: [AvailabilityTimelineSegment]
    let window: DateInterval

    var id: Date { date }

    var availableDuration: TimeInterval {
        segments
            .filter(\.isAvailable)
            .reduce(0) { $0 + $1.duration }
    }

    var blockedDuration: TimeInterval {
        segments
            .filter { !$0.isAvailable }
            .reduce(0) { $0 + $1.duration }
    }

    var firstBlockTitle: String? {
        blocks.first?.title
    }
}

private struct AvailabilityTimeBlock: Identifiable {
    enum Source {
        case task(task: LifeTask, categoryOption: TaskCategoryOption)
        case calendar(CalendarBusyBlock)
    }

    let source: Source
    let title: String
    let subtitle: String
    let shareTitle: String
    let shareSubtitle: String
    let tint: Color
    let startDate: Date
    let endDate: Date

    init(task: LifeTask, categoryOption: TaskCategoryOption, startDate: Date, endDate: Date) {
        source = .task(task: task, categoryOption: categoryOption)
        title = task.title
        subtitle = "\(categoryOption.title) · \(task.durationTitle)"
        shareTitle = task.title
        shareSubtitle = subtitle
        tint = categoryOption.tint
        self.startDate = startDate
        self.endDate = endDate
    }

    init(calendarBlock: CalendarBusyBlock) {
        let durationText = Self.durationTitle(for: calendarBlock.endDate.timeIntervalSince(calendarBlock.startDate))
        source = .calendar(calendarBlock)
        title = calendarBlock.displayTitle
        subtitle = "\(calendarBlock.detailLine) · \(durationText)"
        shareTitle = calendarBlock.shareLabel
        shareSubtitle = "Apple Calendar busy time · \(durationText)"
        tint = LifeTrackTheme.ColorPalette.warning
        startDate = calendarBlock.startDate
        endDate = calendarBlock.endDate
    }

    var id: String {
        switch source {
        case .task(let task, _):
            return task.id.uuidString
        case .calendar(let block):
            return block.id
        }
    }

    var isCalendarEvent: Bool {
        if case .calendar = source {
            return true
        }

        return false
    }

    private static func durationTitle(for duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration / 60))
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }
}

private struct AvailabilityTimelineSegment: Identifiable {
    enum Kind {
        case available
        case blocked(AvailabilityTimeBlock)
    }

    let id = UUID()
    let kind: Kind
    let startDate: Date
    let endDate: Date

    static func available(startDate: Date, endDate: Date) -> AvailabilityTimelineSegment {
        AvailabilityTimelineSegment(kind: .available, startDate: startDate, endDate: endDate)
    }

    static func blocked(_ block: AvailabilityTimeBlock, startDate: Date, endDate: Date) -> AvailabilityTimelineSegment {
        AvailabilityTimelineSegment(kind: .blocked(block), startDate: startDate, endDate: endDate)
    }

    var isAvailable: Bool {
        if case .available = kind {
            return true
        }

        return false
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var timeRangeTitle: String {
        "\(startDate.timeString)-\(endDate.timeString)"
    }
}

private struct AvailabilityMetricPill: View {
    let title: String
    let value: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.7)
        }
    }
}

private struct AvailabilityDaySummaryRow: View {
    let schedule: AvailabilityDaySchedule

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: schedule.blocks.isEmpty ? "checkmark.circle" : "lock")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(schedule.date.formatted(Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Spacer(minLength: 0)

                    Text("\(durationTitle(for: schedule.availableDuration)) free")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(11)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.8)
        }
    }

    private var subtitle: String {
        if schedule.blocks.isEmpty {
            return "No blocked task or calendar times."
        }

        let firstTitle = schedule.firstBlockTitle ?? "Task block"
        let remainingCount = max(schedule.blocks.count - 1, 0)
        if remainingCount == 0 {
            return "\(schedule.blocks.count) block · \(firstTitle)"
        }

        return "\(schedule.blocks.count) blocks · \(firstTitle) + \(remainingCount) more"
    }

    private var tint: Color {
        schedule.blocks.isEmpty ? LifeTrackTheme.ColorPalette.success : schedule.blocks.first?.tint ?? LifeTrackTheme.ColorPalette.accent
    }

    private func durationTitle(for duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration / 60))
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }
}

private struct AvailabilityTimelineRow: View {
    let segment: AvailabilityTimelineSegment

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            VStack(spacing: 5) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: Circle())

                Rectangle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 2, height: 22)
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text(segment.timeRangeTitle)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(1)
                }

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(11)
        .background(background, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(tint.opacity(segment.isAvailable ? 0.14 : 0.20), lineWidth: 0.8)
        }
    }

    private var title: String {
        switch segment.kind {
        case .available:
            "Available"
        case .blocked(let block):
            block.title
        }
    }

    private var subtitle: String {
        switch segment.kind {
        case .available:
            "Open window between scheduled task blocks."
        case .blocked(let block):
            block.subtitle
        }
    }

    private var symbolName: String {
        switch segment.kind {
        case .available:
            return "checkmark.circle"
        case .blocked(let block):
            return block.isCalendarEvent ? "calendar.badge.clock" : "lock.fill"
        }
    }

    private var tint: Color {
        switch segment.kind {
        case .available:
            LifeTrackTheme.ColorPalette.success
        case .blocked(let block):
            block.tint
        }
    }

    private var background: Color {
        if segment.isAvailable {
            return LifeTrackTheme.ColorPalette.success.opacity(0.07)
        }

        return tint.opacity(0.08)
    }
}
