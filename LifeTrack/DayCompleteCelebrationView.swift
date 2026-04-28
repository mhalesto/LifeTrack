//
//  DayCompleteCelebrationView.swift
//  LifeTrack
//

import Charts
import SwiftUI

struct DayCompleteSummary: Identifiable {
    let id = UUID()

    struct Entry: Identifiable {
        let id: UUID
        let title: String
        let completedAt: Date
        let category: TaskCategoryOption
    }

    let date: Date
    let entries: [Entry]

    var totalCompleted: Int { entries.count }

    var firstCompletion: Date? { entries.map(\.completedAt).min() }
    var lastCompletion: Date? { entries.map(\.completedAt).max() }

    var activeDuration: TimeInterval? {
        guard let first = firstCompletion, let last = lastCompletion, last > first else { return nil }
        return last.timeIntervalSince(first)
    }

    struct CategoryShare: Identifiable {
        var id: String { category.id }
        let category: TaskCategoryOption
        let count: Int
    }

    var categoryBreakdown: [CategoryShare] {
        var counts: [String: (TaskCategoryOption, Int)] = [:]
        for entry in entries {
            let key = entry.category.id
            if let existing = counts[key] {
                counts[key] = (existing.0, existing.1 + 1)
            } else {
                counts[key] = (entry.category, 1)
            }
        }
        return counts.values
            .map { CategoryShare(category: $0.0, count: $0.1) }
            .sorted { $0.count > $1.count }
    }
}

@MainActor
struct DayCompleteCelebrationView: View {
    let summary: DayCompleteSummary
    let nickname: String
    let onDismiss: () -> Void

    @State private var burstTrigger = 0
    @State private var sparkleAngle: Double = 0
    @State private var sharePresentation: DayCompleteSharePresentation?
    @State private var isPreparingShare = false
    @State private var shareError: String?

    private var greetingName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "you" : trimmed
    }

    var body: some View {
        ZStack {
            DayCompleteBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    celebrationHeader
                    statsRow
                    timelineSection
                    chartSection
                    shareButton
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: 0x6C4E35))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.92), in: Circle())
                            .overlay {
                                Circle().stroke(Color(hex: 0xE7DACB), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
        }
        .sheet(item: $sharePresentation) { presentation in
            DayCompleteShareSheet(activityItems: [presentation.url])
        }
        .alert("Couldn't prepare share", isPresented: shareErrorBinding) {
            Button("OK") { shareError = nil }
        } message: {
            Text(shareError ?? "Something went wrong while rendering the image.")
        }
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                sparkleAngle = 360
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                burstTrigger &+= 1
            }
        }
    }

    private var celebrationHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) / 8.0 * 360.0
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(sparkleColor(for: index))
                        .offset(x: 64, y: 0)
                        .rotationEffect(.degrees(angle + sparkleAngle))
                }

                Image(systemName: "party.popper.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0xE56C4D), Color(hex: 0xF4B447)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: burstTrigger)
                    .shadow(color: Color(hex: 0xE56C4D).opacity(0.30), radius: 18, x: 0, y: 8)
            }
            .frame(height: 160)

            VStack(spacing: 6) {
                Text("Day complete!")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: 0x2B231F))

                Text("Nice work, \(greetingName) — every task for today is done.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x8D847A))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    private func sparkleColor(for index: Int) -> Color {
        let palette: [Color] = [
            Color(hex: 0xE56C4D),
            Color(hex: 0xF4B447),
            Color(hex: 0x8AA37D),
            Color(hex: 0x4D78AE)
        ]
        return palette[index % palette.count]
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            DayCompleteStatTile(
                value: "\(summary.totalCompleted)",
                label: "Completed",
                symbolName: "checkmark.seal.fill",
                tint: Color(hex: 0x8AA37D)
            )

            DayCompleteStatTile(
                value: activeDurationLabel,
                label: "Active span",
                symbolName: "hourglass",
                tint: Color(hex: 0xC49A3E)
            )

            DayCompleteStatTile(
                value: "\(summary.categoryBreakdown.count)",
                label: "Areas",
                symbolName: "square.stack.3d.up.fill",
                tint: Color(hex: 0x7573B6)
            )
        }
    }

    private var activeDurationLabel: String {
        guard let duration = summary.activeDuration else { return "—" }
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private var timelineSection: some View {
        DayCompleteCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Today's road")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(hex: 0x2B231F))

                    Spacer()

                    Text(summary.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: 0x8D847A))
                }

                DayCompleteTimeline(entries: summary.entries.sorted { $0.completedAt < $1.completedAt })
            }
        }
    }

    private var chartSection: some View {
        DayCompleteCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Momentum")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(hex: 0x2B231F))

                    Spacer()

                    Text("By category")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: 0x8D847A))
                }

                if summary.categoryBreakdown.isEmpty {
                    Text("No categorized tasks today.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: 0x8D847A))
                        .padding(.vertical, 12)
                } else {
                    HStack(alignment: .center, spacing: 18) {
                        DayCompleteDonut(breakdown: summary.categoryBreakdown)
                            .frame(width: 132, height: 132)

                        DayCompleteCategoryLegend(breakdown: summary.categoryBreakdown)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var shareButton: some View {
        Button {
            prepareShare()
        } label: {
            HStack(spacing: 10) {
                if isPreparingShare {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                }

                Text(isPreparingShare ? "Preparing…" : "Share my day")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xE56C4D), Color(hex: 0xF48764)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: Color(hex: 0xE56C4D).opacity(0.22), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isPreparingShare)
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareError != nil },
            set: { newValue in
                if !newValue { shareError = nil }
            }
        )
    }

    private func prepareShare() {
        isPreparingShare = true
        let snapshot = summary
        let displayName = greetingName

        Task { @MainActor in
            do {
                let url = try DayCompleteExporter.exportPNG(summary: snapshot, nickname: displayName)
                isPreparingShare = false
                sharePresentation = DayCompleteSharePresentation(url: url)
            } catch {
                isPreparingShare = false
                shareError = error.localizedDescription
            }
        }
    }
}

private struct DayCompleteCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: 0xE7DACB), lineWidth: 0.8)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

private struct DayCompleteStatTile: View {
    let value: String
    let label: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.16), in: Circle())

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Color(hex: 0x2B231F))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: 0x8D847A))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xE7DACB), lineWidth: 0.8)
        }
    }
}

private struct DayCompleteTimeline: View {
    let entries: [DayCompleteSummary.Entry]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Text(entry.completedAt.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x6C4E35))
                            .frame(width: 56, alignment: .trailing)
                    }
                    .padding(.top, 6)

                    ZStack {
                        Rectangle()
                            .fill(Color(hex: 0xE7DACB))
                            .frame(width: 2)
                            .padding(.top, index == 0 ? 18 : 0)
                            .padding(.bottom, index == entries.count - 1 ? 18 : 0)

                        Circle()
                            .fill(entry.category.tint)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            }
                            .padding(.top, 6)
                    }
                    .frame(width: 18)

                    DayCompleteTicket(entry: entry)
                        .padding(.bottom, index == entries.count - 1 ? 0 : 12)
                }
            }
        }
    }
}

private struct DayCompleteTicket: View {
    let entry: DayCompleteSummary.Entry

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(entry.category.background)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: entry.category.symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(entry.category.tint)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2B231F))
                    .lineLimit(2)

                Text(entry.category.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(entry.category.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0x8AA37D))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: 0xFFFDF9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(entry.category.border, lineWidth: 1)
        }
    }
}

private struct DayCompleteDonut: View {
    let breakdown: [DayCompleteSummary.CategoryShare]

    private var total: Int {
        breakdown.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        ZStack {
            Chart(breakdown) { share in
                SectorMark(
                    angle: .value("Count", share.count),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(share.category.tint)
            }
            .chartLegend(.hidden)

            VStack(spacing: 2) {
                Text("\(total)")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: 0x2B231F))

                Text(total == 1 ? "task" : "tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: 0x8D847A))
            }
        }
    }
}

private struct DayCompleteCategoryLegend: View {
    let breakdown: [DayCompleteSummary.CategoryShare]

    private var total: Int {
        breakdown.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(breakdown) { share in
                HStack(spacing: 8) {
                    Circle()
                        .fill(share.category.tint)
                        .frame(width: 9, height: 9)

                    Text(share.category.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2B231F))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(share.count) · \(percentLabel(for: share.count))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: 0x8D847A))
                        .monospacedDigit()
                }
            }
        }
    }

    private func percentLabel(for count: Int) -> String {
        guard total > 0 else { return "0%" }
        let value = Double(count) / Double(total) * 100
        return "\(Int(value.rounded()))%"
    }
}

private struct DayCompleteBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xFFF9F2), Color(hex: 0xF6EBDD)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(hex: 0xFFD78C).opacity(0.45), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 320
            )
            .offset(x: -90, y: -50)

            RadialGradient(
                colors: [Color(hex: 0xE56C4D).opacity(0.25), .clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 280
            )
            .offset(x: 80, y: -40)
        }
    }
}

// MARK: - Share export

private struct DayCompleteSharePresentation: Identifiable {
    let id = UUID()
    let url: URL
}

private struct DayCompleteShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum DayCompleteExportError: LocalizedError {
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "LifeTrack couldn't render the share image."
        }
    }
}

@MainActor
private enum DayCompleteExporter {
    static let canvasWidth: CGFloat = 1080

    static func exportPNG(summary: DayCompleteSummary, nickname: String) throws -> URL {
        let canvas = DayCompleteShareCanvas(summary: summary, nickname: nickname)
            .frame(width: canvasWidth)

        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 3
        renderer.proposedSize = .init(width: canvasWidth, height: nil)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw DayCompleteExportError.renderFailed
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LifeTrackShare", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let filename = "LifeTrack-DayComplete-\(Int(Date().timeIntervalSince1970)).png"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

@MainActor
private struct DayCompleteShareCanvas: View {
    let summary: DayCompleteSummary
    let nickname: String

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0xE56C4D), Color(hex: 0xF4B447)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day complete")
                            .font(.system(size: 56, weight: .bold, design: .serif))
                            .foregroundStyle(Color(hex: 0x2B231F))

                        Text("\(displayName) wrapped \(summary.totalCompleted) \(summary.totalCompleted == 1 ? "task" : "tasks")")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color(hex: 0x6C4E35))
                    }

                    Spacer(minLength: 0)
                }

                Text(summary.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(hex: 0x8D847A))
            }

            HStack(spacing: 16) {
                shareStat(value: "\(summary.totalCompleted)", label: "Tasks done", symbol: "checkmark.seal.fill", tint: Color(hex: 0x8AA37D))
                shareStat(value: activeDurationLabel, label: "Active span", symbol: "hourglass", tint: Color(hex: 0xC49A3E))
                shareStat(value: "\(summary.categoryBreakdown.count)", label: "Areas", symbol: "square.stack.3d.up.fill", tint: Color(hex: 0x7573B6))
            }

            HStack(alignment: .top, spacing: 28) {
                shareTimeline
                    .frame(maxWidth: .infinity, alignment: .leading)

                shareChart
                    .frame(width: 360)
            }

            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xE56C4D))

                Text("Tracked in LifeTrack")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: 0x2B231F))

                Spacer()

                Text(Date.now.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: 0x8D847A))
            }
        }
        .padding(64)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xFFF9F2), Color(hex: 0xF6EBDD)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [Color(hex: 0xFFD78C).opacity(0.55), .clear],
                    center: .topLeading,
                    startRadius: 60,
                    endRadius: 520
                )
                .offset(x: -120, y: -60)

                RadialGradient(
                    colors: [Color(hex: 0xE56C4D).opacity(0.30), .clear],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 460
                )
                .offset(x: 120, y: -60)
            }
        }
    }

    private var displayName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "You" : trimmed
    }

    private var activeDurationLabel: String {
        guard let duration = summary.activeDuration else { return "—" }
        let minutes = Int(duration / 60)
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func shareStat(value: String, label: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 60, height: 60)
                .background(tint.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: 0x2B231F))

                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: 0x8D847A))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color(hex: 0xE7DACB), lineWidth: 1)
        }
    }

    private var shareTimeline: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Today's road")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(Color(hex: 0x2B231F))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(summary.entries.sorted { $0.completedAt < $1.completedAt }.prefix(8))) { entry in
                    HStack(alignment: .center, spacing: 16) {
                        Text(entry.completedAt.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x6C4E35))
                            .frame(width: 88, alignment: .leading)

                        Circle()
                            .fill(entry.category.tint)
                            .frame(width: 14, height: 14)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x2B231F))
                                .lineLimit(2)

                            Text(entry.category.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(entry.category.tint)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(entry.category.border, lineWidth: 1)
                    }
                }

                if summary.entries.count > 8 {
                    Text("+ \(summary.entries.count - 8) more")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: 0x8D847A))
                        .padding(.leading, 18)
                }
            }
        }
    }

    private var shareChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Momentum")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(Color(hex: 0x2B231F))

            ZStack {
                Chart(summary.categoryBreakdown) { share in
                    SectorMark(
                        angle: .value("Count", share.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .cornerRadius(6)
                    .foregroundStyle(share.category.tint)
                }
                .chartLegend(.hidden)
                .frame(width: 260, height: 260)

                VStack(spacing: 4) {
                    Text("\(summary.totalCompleted)")
                        .font(.system(size: 56, weight: .bold, design: .serif))
                        .foregroundStyle(Color(hex: 0x2B231F))

                    Text(summary.totalCompleted == 1 ? "task" : "tasks")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: 0x8D847A))
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.categoryBreakdown) { share in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(share.category.tint)
                            .frame(width: 12, height: 12)

                        Text(share.category.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x2B231F))

                        Spacer()

                        Text("\(share.count)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x6C4E35))
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color(hex: 0xE7DACB), lineWidth: 1)
        }
    }
}
