//
//  CloudBackupView.swift
//  LifeTrack
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CloudBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LifeTask.updatedAt, order: .reverse) private var tasks: [LifeTask]
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    @AppStorage(LifeTrackSettings.Keys.lastBackupDate) private var lastBackupTimestamp: Double = 0

    @State private var shareURL: URL?
    @State private var isRestoring = false
    @State private var feedback: BackupFeedback?
    @State private var isPreparingBackup = false

    private let gold = Color(red: 0.95, green: 0.72, blue: 0.1)

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: LifeTrackTheme.Spacing.xLarge) {
                    header

                    if let feedback {
                        feedbackBanner(feedback)
                            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    statusCard
                    backupCard
                    restoreCard
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.large)
                .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
            }
        }
        .navigationTitle("iCloud Backup")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy(duration: 0.28), value: feedback == nil)
        .fileImporter(
            isPresented: $isRestoring,
            allowedContentTypes: TaskExchangeFormat.importContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleRestore
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(gold.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: "icloud.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(gold)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("iCloud Backup & Export")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text("Save a snapshot of all your tasks and restore from any backup.")
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Current Library", subtitle: "All tasks included in backup.")

            HStack(spacing: LifeTrackTheme.Spacing.small) {
                metricPill(title: "Tasks", value: tasks.count.formatted(), symbol: "checklist")
                metricPill(title: "Done", value: tasks.filter(\.isCompleted).count.formatted(), symbol: "checkmark.seal")
                metricPill(title: "Bin", value: tasks.filter(\.isDeleted).count.formatted(), symbol: "trash")
            }

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                Text(lastBackupLabel)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
        }
    }

    private var lastBackupLabel: String {
        guard lastBackupTimestamp > 0 else { return "Never backed up" }
        let date = Date(timeIntervalSince1970: lastBackupTimestamp)
        return "Last backup: \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    // MARK: - Backup Card

    private var backupCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Back Up Now",
                subtitle: "Creates a full JSON backup. Save it to iCloud Drive via the Files extension in the share sheet."
            )

            requirementRow(symbol: "curlybraces", title: "JSON format", message: "Full-fidelity backup — restores every field including categories, priority, recurrence, and notes.")
            requirementRow(symbol: "icloud.and.arrow.up", title: "iCloud Drive", message: "In the share sheet, choose Save to Files → iCloud Drive to store it in the cloud.")

            Button {
                prepareBackup()
            } label: {
                HStack(spacing: 6) {
                    if isPreparingBackup {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                        Text("Back Up Now")
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    tasks.isEmpty || isPreparingBackup
                        ? AnyShapeStyle(gold.opacity(0.4))
                        : AnyShapeStyle(LinearGradient(colors: [gold, Color(red: 0.98, green: 0.5, blue: 0.15)], startPoint: .leading, endPoint: .trailing)),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(tasks.isEmpty || isPreparingBackup)

            if let shareURL {
                ShareLink(
                    item: shareURL,
                    subject: Text("LifeTrack Backup"),
                    message: Text("LifeTrack task backup — \(tasks.count) tasks."),
                    preview: SharePreview(backupFileName)
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.up")
                        Text("Share Backup")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                            .stroke(LifeTrackTheme.ColorPalette.hairline, lineWidth: 0.8)
                    }
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.985))
                .simultaneousGesture(TapGesture().onEnded { prepareBackup() })
            }
        }
    }

    // MARK: - Restore Card

    private var restoreCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Restore from Backup",
                subtitle: "Import a previously saved LifeTrack backup. Existing tasks are preserved — duplicates are skipped."
            )

            requirementRow(symbol: "exclamationmark.triangle", title: "Non-destructive", message: "Restoring adds tasks from the backup without deleting your current tasks.")

            LifeTrackPrimaryButton(
                title: "Choose Backup File",
                systemImage: "tray.and.arrow.down",
                action: { isRestoring = true }
            )
        }
    }

    // MARK: - Helpers

    private func metricPill(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(gold)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.82), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }

    private func requirementRow(symbol: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(gold)
                .frame(width: 30, height: 30)
                .background(gold.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func feedbackBanner(_ fb: BackupFeedback) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: fb.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(fb.tint)
                .frame(width: 36, height: 36)
                .background(fb.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(fb.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text(fb.message)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button { withAnimation { self.feedback = nil } } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                    .frame(width: 28, height: 28)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.8), in: Circle())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9))
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(fb.tint.opacity(0.22), lineWidth: 0.8)
        }
    }

    // MARK: - Actions

    private var backupFileName: String {
        let date = Date().formatted(Date.FormatStyle().year().month(.twoDigits).day(.twoDigits))
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        return "LifeTrack Backup \(date).json"
    }

    private func prepareBackup() {
        guard !tasks.isEmpty else { return }
        isPreparingBackup = true
        do {
            let url = try TaskExchangeManager.shareableExportURL(
                format: .json,
                tasks: tasks,
                customCategories: customCategories,
                fileName: backupFileName
            )
            shareURL = url
            lastBackupTimestamp = Date().timeIntervalSince1970
            withAnimation { feedback = .success("Backup ready", "Tap Share Backup to save to iCloud Drive or any Files location.") }
        } catch {
            withAnimation { feedback = .error(error.localizedDescription) }
        }
        isPreparingBackup = false
    }

    private func handleRestore(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                withAnimation { feedback = .error("No file was selected.") }
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let summary = try TaskExchangeManager.importTasks(
                    from: data,
                    fileName: url.lastPathComponent,
                    existingTasks: tasks,
                    customCategories: customCategories,
                    modelContext: modelContext
                )
                withAnimation { feedback = .success("Restore complete", "\(summary.imported) total — \(summary.created) added, \(summary.updated) updated, \(summary.skipped) skipped.") }
            } catch {
                withAnimation { feedback = .error(error.localizedDescription) }
            }
        case .failure(let error):
            withAnimation { feedback = .error(error.localizedDescription) }
        }
    }
}

// MARK: - Feedback

private enum BackupFeedback: Equatable {
    case success(String, String)
    case error(String)

    var title: String {
        switch self {
        case .success(let t, _): return t
        case .error: return "Action failed"
        }
    }

    var message: String {
        switch self {
        case .success(_, let m): return m
        case .error(let m): return m
        }
    }

    var symbol: String {
        switch self {
        case .success: return "checkmark.seal.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return LifeTrackTheme.ColorPalette.success
        case .error: return LifeTrackTheme.ColorPalette.danger
        }
    }
}
