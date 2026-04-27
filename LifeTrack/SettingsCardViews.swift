//
//  SettingsCardViews.swift
//  LifeTrack
//
//  Self-contained Settings cards extracted from SettingsView. Each card owns
//  its own @AppStorage / @Query / @EnvironmentObject dependencies so the parent
//  becomes a layout container.
//

import SwiftData
import SwiftUI

// MARK: - Motion

struct MotionSettingsCard: View {
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue

    private var theme: LifeTrackAppTheme {
        LifeTrackAppTheme(rawValue: selectedThemeID) ?? .fallback
    }

    var body: some View {
        SectionCardView {
            SectionHeaderView(title: "Motion", subtitle: "Subtle interaction polish.")

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: animationsEnabled ? "sparkles" : "pause.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 42, height: 42)
                    .background(theme.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Animations")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Use gentle motion for taps, swipes, and progress counts.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                Toggle("", isOn: $animationsEnabled)
                    .labelsHidden()
                    .tint(theme.accent)
            }
            .padding(12)
            .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
            }
        }
    }
}

// MARK: - Background Pattern

struct BackgroundPatternSettingsCard: View {
    @AppStorage(LifeTrackSettings.Keys.betaShapesOpacity) private var shapesOpacity: Double = 0.35

    var body: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Background Pattern",
                subtitle: "Adjust the decorative shapes behind the home screen."
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: LifeTrackTheme.Spacing.small) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)

                    Text("Background Shapes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Spacer(minLength: LifeTrackTheme.Spacing.small)

                    Text("\(Int(shapesOpacity * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .monospacedDigit()
                }

                Slider(value: $shapesOpacity, in: 0...1, step: 0.05)
                    .tint(LifeTrackTheme.ColorPalette.accent)

                Text("Adjusts how visible the drifting circles are behind the home dashboard.")
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
            }
        }
    }
}

// MARK: - Display

struct DisplaySettingsCard: View {
    @AppStorage(LifeTrackSettings.Keys.hideStatusBar) private var hideStatusBar = false
    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue

    private var theme: LifeTrackAppTheme {
        LifeTrackAppTheme(rawValue: selectedThemeID) ?? .fallback
    }

    var body: some View {
        SectionCardView {
            SectionHeaderView(title: "Display", subtitle: "Fine-tune what's visible on screen.")

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: hideStatusBar ? "eye.slash.fill" : "wifi")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 42, height: 42)
                    .background(theme.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Hide Status Bar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Hides the top bar with time, Wi-Fi, and battery for a cleaner view.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                Toggle("", isOn: $hideStatusBar)
                    .labelsHidden()
                    .tint(theme.accent)
            }
            .padding(12)
            .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
            }
        }
    }
}

// MARK: - Money

struct MoneySettingsCard: View {
    @AppStorage(LifeTrackSettings.Keys.moneyCurrencyCode) private var moneyCurrencyCode = MoneyCurrency.defaultCode
    @AppStorage(LifeTrackSettings.Keys.moneyCurrencyLocked) private var isMoneyCurrencyLocked = false

    var body: some View {
        SectionCardView {
            SectionHeaderView(title: "Money", subtitle: "Choose the currency used across money tracking.")

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: 42, height: 42)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("App Money Currency")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(isMoneyCurrencyLocked ? "Locked for reports, tasks, entries, and forecasts." : "Pick once before logging money, then lock it in.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                if isMoneyCurrencyLocked {
                    MoneyCurrencyBadge(currencyCode: moneyCurrencyCode, showsLock: true)
                } else {
                    MoneyCurrencyPicker(currencyCode: $moneyCurrencyCode)
                }
            }
            .padding(12)
            .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
            }

            if !isMoneyCurrencyLocked {
                Button {
                    moneyCurrencyCode = MoneyCurrency.normalized(moneyCurrencyCode)
                    isMoneyCurrencyLocked = true
                    LifeTrackHaptics.lightImpact()
                } label: {
                    Label("Lock Currency", systemImage: "lock.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(LifeTrackTheme.ColorPalette.accentGradient, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
            }
        }
    }
}

// MARK: - Archive

struct ArchiveSettingsCard: View {
    @Query(sort: \LifeTask.updatedAt, order: .reverse) private var tasks: [LifeTask]
    @AppStorage(LifeTrackSettings.Keys.completedArchivePeriod) private var completedArchiveRawValue = CompletedArchivePeriod.fallback.rawValue

    private var period: CompletedArchivePeriod {
        CompletedArchivePeriod(rawValue: completedArchiveRawValue) ?? .fallback
    }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted && !$0.isDeleted }.count
    }

    var body: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Archive",
                subtitle: "Move old completed tasks out of the dashboard to keep things fast."
            )

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: "archivebox")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: 42, height: 42)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(completedCount == 1 ? "1 completed task" : "\(completedCount) completed tasks")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(period == .off ? "No tasks will be archived automatically." : "Completed tasks move to Bin after \(period.title.lowercased()).")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)
            }
            .padding(12)
            .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Archive completed tasks older than")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(CompletedArchivePeriod.allCases) { period in
                        Button {
                            withAnimation(.snappy) {
                                completedArchiveRawValue = period.rawValue
                            }
                        } label: {
                            CompletedArchiveChip(
                                period: period,
                                isSelected: self.period == period
                            )
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                    }
                }
            }
        }
    }
}

// MARK: - Bin

struct BinSettingsCard: View {
    @Query(sort: \LifeTask.updatedAt, order: .reverse) private var tasks: [LifeTask]
    @AppStorage(LifeTrackSettings.Keys.binRetentionPeriod) private var binRetentionRawValue = TaskBinRetentionPeriod.fallback.rawValue

    private var period: TaskBinRetentionPeriod {
        TaskBinRetentionPeriod(rawValue: binRetentionRawValue) ?? .fallback
    }

    private var binCount: Int {
        tasks.filter(\.isDeleted).count
    }

    var body: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Bin",
                subtitle: "Restore deleted tasks before they are removed forever."
            )

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                    .frame(width: 42, height: 42)
                    .background(LifeTrackTheme.ColorPalette.danger.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(binCount == 1 ? "1 task in Bin" : "\(binCount) tasks in Bin")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(period == .immediately ? "Deleted tasks are removed forever immediately." : "Items expire after \(period.title.lowercased()).")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                NavigationLink {
                    TaskBinView()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        .frame(width: 32, height: 32)
                        .background(LifeTrackTheme.ColorPalette.controlSurfaceStrong, in: Circle())
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92))
                .accessibilityLabel("Open Bin")
            }
            .padding(12)
            .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Keep deleted tasks for")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(TaskBinRetentionPeriod.allCases) { period in
                        Button {
                            withAnimation(.snappy) {
                                binRetentionRawValue = period.rawValue
                            }
                        } label: {
                            BinRetentionChip(
                                period: period,
                                isSelected: self.period == period
                            )
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                    }
                }
            }
        }
    }
}

// MARK: - Task Data

struct TaskDataSettingsCard: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Task Data",
                subtitle: "Import and export backups or spreadsheet-ready task lists."
            )

            taskDataRow(
                symbol: "tray.and.arrow.down.fill",
                title: "JSON, CSV, and TSV",
                subtitle: "Import, export, and share task lists.",
                destination: TaskDataExchangeView()
            )

            if subscriptionManager.tier >= .ultimate {
                Divider()

                taskDataRow(
                    symbol: "icloud.fill",
                    title: "iCloud Backup & Export",
                    subtitle: "Full backup with restore. Save to iCloud Drive.",
                    destination: CloudBackupView()
                )
            }
        }
    }

    @ViewBuilder
    private func taskDataRow<D: View>(symbol: String, title: String, subtitle: String, destination: D) -> some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: 42, height: 42)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            NavigationLink {
                destination
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                    .frame(width: 32, height: 32)
                    .background(LifeTrackTheme.ColorPalette.controlSurfaceStrong, in: Circle())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92))
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }
}

// MARK: - Chips

struct CompletedArchiveChip: View {
    let period: CompletedArchivePeriod
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(period.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? .white : LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)

            Text(period.subtitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? Color.white.opacity(0.82) : LifeTrackTheme.ColorPalette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            isSelected ? AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient) : AnyShapeStyle(LifeTrackTheme.ColorPalette.controlSurfaceStrong),
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.24) : LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }
}

struct BinRetentionChip: View {
    let period: TaskBinRetentionPeriod
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(period.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? .white : LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)

            Text(period.subtitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? Color.white.opacity(0.82) : LifeTrackTheme.ColorPalette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            isSelected ? AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient) : AnyShapeStyle(LifeTrackTheme.ColorPalette.controlSurfaceStrong),
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.24) : LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }
}
