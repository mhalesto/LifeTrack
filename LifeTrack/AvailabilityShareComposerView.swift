//
//  AvailabilityShareComposerView.swift
//  LifeTrack
//

import SwiftUI
import UIKit

struct AvailabilityShareSnapshot {
    let range: AvailabilityShareRange
    let rangeTitle: String
    let dateSubtitle: String
    let availableDurationTitle: String
    let blockedDurationTitle: String
    let blockCount: Int
    let totalDayCount: Int
    let includesCalendarBusyTimes: Bool
    let days: [AvailabilityShareDaySnapshot]
}

struct AvailabilityShareDaySnapshot: Identifiable {
    let date: Date
    let title: String
    let availableDurationTitle: String
    let blockedDurationTitle: String
    let blockCount: Int
    let availableRanges: [String]
    let entries: [AvailabilityShareEntrySnapshot]
    let firstBlockedTitle: String?

    var id: TimeInterval { date.timeIntervalSince1970 }
}

struct AvailabilityShareEntrySnapshot: Identifiable {
    enum Kind {
        case available
        case task
        case calendar
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let subtitle: String
    let timeRangeTitle: String
}

enum AvailabilityShareTemplate: String, CaseIterable, Identifiable {
    case brief
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brief:
            return "Brief Card"
        case .detailed:
            return "Detailed Planner"
        }
    }

    var subtitle: String {
        switch self {
        case .brief:
            return "Compact summary for Messages and WhatsApp."
        case .detailed:
            return "More context with day-by-day availability."
        }
    }

    var symbolName: String {
        switch self {
        case .brief:
            return "rectangle.stack.fill"
        case .detailed:
            return "list.bullet.rectangle.portrait.fill"
        }
    }

    var canvasWidth: CGFloat {
        switch self {
        case .brief:
            return 380
        case .detailed:
            return 390
        }
    }
}

struct AvailabilityShareComposerView: View {
    @Environment(\.dismiss) private var dismiss

    let snapshot: AvailabilityShareSnapshot

    @State private var selectedTemplate: AvailabilityShareTemplate = .brief
    @State private var isPreparingShare = false
    @State private var sharePresentation: AvailabilitySharePresentation?
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        composerHeader
                        templatePicker
                        previewSection
                        shareNote
                        shareButton
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
        }
        .sheet(item: $sharePresentation) { presentation in
            ActivityShareSheet(activityItems: [presentation.url]) {
                try? FileManager.default.removeItem(at: presentation.url)
            }
        }
        .alert("Couldn’t prepare share", isPresented: exportErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "Something went wrong while preparing the share image.")
        }
    }

    private var composerHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Share Preview")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Choose a branded template, then send a high-quality image that looks good in chat apps and AirDrop previews.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var templatePicker: some View {
        HStack(spacing: LifeTrackTheme.Spacing.small) {
            ForEach(AvailabilityShareTemplate.allCases) { template in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        selectedTemplate = template
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: template.symbolName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isSelected(template) ? Color.white : LifeTrackTheme.ColorPalette.accent)

                            Text(template.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected(template) ? Color.white : LifeTrackTheme.ColorPalette.primaryText)
                        }

                        Text(template.subtitle)
                            .font(.footnote)
                            .foregroundStyle(isSelected(template) ? Color.white.opacity(0.88) : LifeTrackTheme.ColorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(LifeTrackTheme.Spacing.medium)
                    .background(templateBackground(for: template), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(templateStroke(for: template), lineWidth: 1)
                    }
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98, pressedOpacity: 0.92))
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Preview")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Spacer()

                Text("PNG export")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
            }

            AvailabilityShareExportCanvas(snapshot: snapshot, template: selectedTemplate)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(0.16), radius: 22, y: 14)
        }
    }

    private var shareNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: 34, height: 34)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("What gets shared")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text(snapshot.includesCalendarBusyTimes
                     ? "Apple Calendar busy windows are included, but event titles stay private. The exported image is a manual snapshot, not a live link."
                     : "The exported image is a manual snapshot of your current task availability, styled for sharing outside the app.")
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LifeTrackTheme.Spacing.medium)
        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.9)
        }
    }

    private var shareButton: some View {
        Button {
            Task { await prepareShare() }
        } label: {
            HStack(spacing: 8) {
                if isPreparingShare {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                }
                Text(isPreparingShare ? "Preparing PNG..." : "Share High-Quality PNG")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LifeTrackTheme.ColorPalette.accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.24), radius: 16, y: 10)
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98, pressedOpacity: 0.92))
        .disabled(isPreparingShare)
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    exportErrorMessage = nil
                }
            }
        )
    }

    @MainActor
    private func prepareShare() async {
        guard !isPreparingShare else {
            return
        }

        isPreparingShare = true
        defer { isPreparingShare = false }

        do {
            let url = try AvailabilityShareExporter.exportPNG(snapshot: snapshot, template: selectedTemplate)
            sharePresentation = AvailabilitySharePresentation(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func isSelected(_ template: AvailabilityShareTemplate) -> Bool {
        selectedTemplate == template
    }

    private func templateBackground(for template: AvailabilityShareTemplate) -> some ShapeStyle {
        if isSelected(template) {
            return AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient)
        }

        return AnyShapeStyle(LifeTrackTheme.ColorPalette.card)
    }

    private func templateStroke(for template: AvailabilityShareTemplate) -> Color {
        isSelected(template) ? Color.white.opacity(0.20) : LifeTrackTheme.ColorPalette.hairline.opacity(0.82)
    }
}

private struct AvailabilitySharePresentation: Identifiable {
    let id = UUID()
    let url: URL
}

private struct AvailabilityShareExportCanvas: View {
    let snapshot: AvailabilityShareSnapshot
    let template: AvailabilityShareTemplate

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground

            Group {
                switch template {
                case .brief:
                    AvailabilityBriefShareCard(snapshot: snapshot)
                case .detailed:
                    AvailabilityDetailedShareCard(snapshot: snapshot)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AvailabilityBriefShareCard: View {
    let snapshot: AvailabilityShareSnapshot

    private var availableHighlights: [AvailabilityShareWindowHighlight] {
        Array(snapshot.availableHighlights.prefix(4))
    }

    private var busyHighlights: [AvailabilityShareBusyHighlight] {
        Array(snapshot.busyHighlights.prefix(4))
    }

    private var hiddenDayCount: Int {
        max(snapshot.totalDayCount - snapshot.days.prefix(4).count, 0)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AvailabilityShareCardBackground(accentOpacity: 0.18)

            VStack(alignment: .leading, spacing: 18) {
                shareHeader
                shareMetrics

                if !availableHighlights.isEmpty {
                    shareSection(title: "Best windows", subtitle: "Easy times to book around your current plan.") {
                        VStack(spacing: 10) {
                            ForEach(availableHighlights) { highlight in
                                AvailabilityShareWindowRow(highlight: highlight)
                            }
                        }
                    }
                }

                shareSection(title: "Busy highlights", subtitle: "Current blocked items in this shared range.") {
                    VStack(spacing: 10) {
                        if busyHighlights.isEmpty {
                            AvailabilityShareEmptyStateRow(
                                title: "Nothing blocked",
                                subtitle: "This range is currently open."
                            )
                        } else {
                            ForEach(busyHighlights) { highlight in
                                AvailabilityShareBusyRow(highlight: highlight)
                            }
                        }
                    }
                }

                if hiddenDayCount > 0 {
                    Text("+\(hiddenDayCount) more \(hiddenDayCount == 1 ? "day" : "days") still available in LifeTrack.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                shareFooter
            }
            .padding(24)
        }
    }

    private var shareHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            LifeTrackLogoView(size: 54, showsShadow: false)

            VStack(alignment: .leading, spacing: 5) {
                Text("CREATED WITH LIFETRACK")
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                Text("Availability")
                    .font(.lifeTrack(size: 30, role: .title, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text("\(snapshot.rangeTitle) · \(snapshot.dateSubtitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var shareMetrics: some View {
        HStack(spacing: 10) {
            AvailabilityShareStatTile(
                title: "Available",
                value: snapshot.availableDurationTitle,
                symbolName: "checkmark.circle.fill",
                tint: LifeTrackTheme.ColorPalette.success
            )

            AvailabilityShareStatTile(
                title: "Blocked",
                value: snapshot.blockedDurationTitle,
                symbolName: "lock.fill",
                tint: LifeTrackTheme.ColorPalette.warning
            )

            AvailabilityShareStatTile(
                title: snapshot.range == .today ? "Items" : "Days",
                value: snapshot.range == .today ? snapshot.blockCount.formatted() : snapshot.totalDayCount.formatted(),
                symbolName: snapshot.range == .today ? "list.bullet" : "calendar",
                tint: LifeTrackTheme.ColorPalette.accent
            )
        }
    }

    private var shareFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .overlay(LifeTrackTheme.ColorPalette.hairline.opacity(0.75))

            HStack {
                Text("Created with LifeTrack")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                Spacer()

                Text("Manual share only")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            if snapshot.includesCalendarBusyTimes {
                Text("Apple Calendar titles stay private in this shared image.")
                    .font(.caption2)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }
        }
    }

    private func shareSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            content()
        }
    }
}

private struct AvailabilityDetailedShareCard: View {
    let snapshot: AvailabilityShareSnapshot

    private var displayedDays: [AvailabilityShareDaySnapshot] {
        switch snapshot.range {
        case .today:
            return Array(snapshot.days.prefix(1))
        case .week:
            return snapshot.days
        case .thirtyDays:
            return Array(snapshot.days.prefix(10))
        }
    }

    private var hiddenDayCount: Int {
        max(snapshot.days.count - displayedDays.count, 0)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AvailabilityShareCardBackground(accentOpacity: 0.14)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    LifeTrackLogoView(size: 52, showsShadow: false)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("LifeTrack Availability")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                        Text("\(snapshot.rangeTitle) · \(snapshot.dateSubtitle)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    AvailabilityShareSummaryChip(title: "Available", value: snapshot.availableDurationTitle, tint: LifeTrackTheme.ColorPalette.success)
                    AvailabilityShareSummaryChip(title: "Blocked", value: snapshot.blockedDurationTitle, tint: LifeTrackTheme.ColorPalette.warning)
                    AvailabilityShareSummaryChip(title: "Items", value: snapshot.blockCount.formatted(), tint: LifeTrackTheme.ColorPalette.accent)
                }

                ForEach(displayedDays) { day in
                    AvailabilityShareDayCard(day: day, range: snapshot.range)
                }

                if hiddenDayCount > 0 {
                    Text("+\(hiddenDayCount) more \(hiddenDayCount == 1 ? "day" : "days") are available in the full in-app view.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .padding(.top, 2)
                }

                HStack {
                    Text("Created with LifeTrack")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                    Spacer()

                    if snapshot.includesCalendarBusyTimes {
                        Text("Calendar titles hidden")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                }
                .padding(.top, 6)
            }
            .padding(24)
        }
    }
}

private struct AvailabilityShareDayCard: View {
    let day: AvailabilityShareDaySnapshot
    let range: AvailabilityShareRange

    private var displayedEntries: [AvailabilityShareEntrySnapshot] {
        switch range {
        case .today:
            return Array(day.entries.prefix(8))
        case .week:
            return Array(day.blockedEntries.prefix(3))
        case .thirtyDays:
            return Array(day.blockedEntries.prefix(2))
        }
    }

    private var hiddenEntryCount: Int {
        switch range {
        case .today:
            return max(day.entries.count - displayedEntries.count, 0)
        case .week, .thirtyDays:
            return max(day.blockedEntries.count - displayedEntries.count, 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(day.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Spacer(minLength: 0)

                Text("\(day.availableDurationTitle) free")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            HStack(spacing: 8) {
                AvailabilityShareSummaryChip(title: "Available", value: day.availableDurationTitle, tint: LifeTrackTheme.ColorPalette.success)
                AvailabilityShareSummaryChip(title: "Blocked", value: day.blockedDurationTitle, tint: LifeTrackTheme.ColorPalette.warning)
                AvailabilityShareSummaryChip(title: "Items", value: day.blockCount.formatted(), tint: LifeTrackTheme.ColorPalette.accent)
            }

            if !day.availableRanges.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Open windows")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                    ForEach(Array(day.availableRanges.prefix(range == .today ? 3 : 2).enumerated()), id: \.offset) { _, rangeTitle in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.success)

                            Text(rangeTitle)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        }
                    }
                }
            }

            if displayedEntries.isEmpty {
                Text("No blocked items in this period.")
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(displayedEntries) { entry in
                        AvailabilityShareDetailedEntryRow(entry: entry)
                    }
                }
            }

            if hiddenEntryCount > 0 {
                Text("+\(hiddenEntryCount) more blocked \(hiddenEntryCount == 1 ? "item" : "items")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
        }
        .padding(16)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.94), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.9)
        }
    }
}

private struct AvailabilityShareDetailedEntryRow: View {
    let entry: AvailabilityShareEntrySnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text(entry.timeRangeTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .monospacedDigit()
                }

                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(tint.opacity(entry.kind == .available ? 0.08 : 0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tint: Color {
        switch entry.kind {
        case .available:
            return LifeTrackTheme.ColorPalette.success
        case .task:
            return LifeTrackTheme.ColorPalette.accent
        case .calendar:
            return LifeTrackTheme.ColorPalette.warning
        }
    }

    private var symbolName: String {
        switch entry.kind {
        case .available:
            return "checkmark.circle.fill"
        case .task:
            return "lock.fill"
        case .calendar:
            return "calendar.badge.clock"
        }
    }
}

private struct AvailabilityShareStatTile: View {
    let title: String
    let value: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 0.9)
        }
    }
}

private struct AvailabilityShareSummaryChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AvailabilityShareWindowRow: View {
    let highlight: AvailabilityShareWindowHighlight

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                .frame(width: 28, height: 28)
                .background(LifeTrackTheme.ColorPalette.success.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.timeRangeTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(highlight.dayTitle)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Spacer()
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.success.opacity(0.18), lineWidth: 0.9)
        }
    }
}

private struct AvailabilityShareBusyRow: View {
    let highlight: AvailabilityShareBusyHighlight

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: highlight.kind == .calendar ? "calendar.badge.clock" : "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(highlight.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text(highlight.timeRangeTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .monospacedDigit()
                }

                Text("\(highlight.dayTitle) · \(highlight.subtitle)")
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 0.9)
        }
    }

    private var tint: Color {
        highlight.kind == .calendar ? LifeTrackTheme.ColorPalette.warning : LifeTrackTheme.ColorPalette.accent
    }
}

private struct AvailabilityShareEmptyStateRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AvailabilityShareCardBackground: View {
    let accentOpacity: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.96))

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)

            Circle()
                .fill(LifeTrackTheme.ColorPalette.accent.opacity(accentOpacity))
                .frame(width: 220, height: 220)
                .blur(radius: 28)
                .offset(x: 120, y: -100)

            Circle()
                .fill(LifeTrackTheme.ColorPalette.secondaryAccent.opacity(accentOpacity * 0.72))
                .frame(width: 180, height: 180)
                .blur(radius: 28)
                .offset(x: -130, y: 160)
        }
    }
}

private enum AvailabilityShareExporter {
    @MainActor
    static func exportPNG(snapshot: AvailabilityShareSnapshot, template: AvailabilityShareTemplate) throws -> URL {
        let content = AvailabilityShareExportCanvas(snapshot: snapshot, template: template)
            .frame(width: template.canvasWidth)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        renderer.proposedSize = .init(width: template.canvasWidth, height: nil)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw AvailabilityShareExportError.renderFailed
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LifeTrackShare", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let filename = "LifeTrack-Availability-\(snapshot.range.rawValue)-\(template.rawValue)-\(Int(Date().timeIntervalSince1970)).png"
        let url = directory.appendingPathComponent(filename)

        try data.write(to: url, options: .atomic)
        return url
    }
}

private enum AvailabilityShareExportError: LocalizedError {
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "LifeTrack couldn’t render the share image."
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct AvailabilityShareWindowHighlight: Identifiable {
    let id = UUID()
    let dayTitle: String
    let timeRangeTitle: String
}

private struct AvailabilityShareBusyHighlight: Identifiable {
    let id = UUID()
    let kind: AvailabilityShareEntrySnapshot.Kind
    let dayTitle: String
    let title: String
    let subtitle: String
    let timeRangeTitle: String
}

private extension AvailabilityShareSnapshot {
    var availableHighlights: [AvailabilityShareWindowHighlight] {
        days.flatMap { day in
            day.availableRanges.map { rangeTitle in
                AvailabilityShareWindowHighlight(
                    dayTitle: shortDayTitle(for: day.date),
                    timeRangeTitle: rangeTitle
                )
            }
        }
    }

    var busyHighlights: [AvailabilityShareBusyHighlight] {
        days.flatMap { day in
            day.blockedEntries.map { entry in
                AvailabilityShareBusyHighlight(
                    kind: entry.kind,
                    dayTitle: shortDayTitle(for: day.date),
                    title: entry.title,
                    subtitle: entry.subtitle,
                    timeRangeTitle: entry.timeRangeTitle
                )
            }
        }
    }

    private func shortDayTitle(for date: Date) -> String {
        date.formatted(Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day())
    }
}

private extension AvailabilityShareDaySnapshot {
    var blockedEntries: [AvailabilityShareEntrySnapshot] {
        entries.filter { $0.kind != .available }
    }
}
