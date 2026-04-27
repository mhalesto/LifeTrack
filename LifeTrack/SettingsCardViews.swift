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

// MARK: - Typography

struct TypographySettingsCard: View {
    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.appFontChoice) private var appFontChoice = LifeTrackFontChoice.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.titleTextScale) private var titleTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.bodyTextScale) private var bodyTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.captionTextScale) private var captionTextScale = LifeTrackTypography.defaultScale
    @State private var isExpanded = false

    private var theme: LifeTrackAppTheme {
        LifeTrackAppTheme(rawValue: selectedThemeID) ?? .fallback
    }

    private var selectedFontChoice: LifeTrackFontChoice {
        LifeTrackFontChoice(rawValue: appFontChoice) ?? .fallback
    }

    private var clampedTitleScale: Double {
        LifeTrackTypography.clamped(titleTextScale, role: .title)
    }

    private var clampedBodyScale: Double {
        LifeTrackTypography.clamped(bodyTextScale, role: .body)
    }

    private var clampedCaptionScale: Double {
        LifeTrackTypography.clamped(captionTextScale, role: .caption)
    }

    private var typographyScaleSummary: String {
        "T \(percentage(clampedTitleScale))  B \(percentage(clampedBodyScale))  C \(percentage(clampedCaptionScale))"
    }

    private var isTypographyDefault: Bool {
        LifeTrackTypography.isDefault(
            fontChoiceRaw: appFontChoice,
            titleScale: titleTextScale,
            bodyScale: bodyTextScale,
            captionScale: captionTextScale
        )
    }

    private var titleScaleBinding: Binding<Double> {
        Binding(
            get: { clampedTitleScale },
            set: { titleTextScale = LifeTrackTypography.clamped($0, role: .title) }
        )
    }

    private var bodyScaleBinding: Binding<Double> {
        Binding(
            get: { clampedBodyScale },
            set: { bodyTextScale = LifeTrackTypography.clamped($0, role: .body) }
        )
    }

    private var captionScaleBinding: Binding<Double> {
        Binding(
            get: { clampedCaptionScale },
            set: { captionTextScale = LifeTrackTypography.clamped($0, role: .caption) }
        )
    }

    var body: some View {
        SectionCardView {
            Button {
                withAnimation(.snappy(duration: 0.24)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                    Image(systemName: "textformat.alt")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 42, height: 42)
                        .background(theme.accentSoft, in: Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Typography")
                            .font(.lifeTrackHeadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                        Text("Choose app fonts and keep text sizing comfortably in range.")
                            .font(.lifeTrackFootnote)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Text(selectedFontChoice.title)
                                .font(.lifeTrackCaption)
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(theme.accentSoft, in: Capsule())

                            Text(typographyScaleSummary)
                                .font(.lifeTrackCaption)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: LifeTrackTheme.Spacing.small)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.lifeTrack(.caption, weight: .bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        .frame(width: 32, height: 32)
                        .background(LifeTrackTheme.ColorPalette.controlSurfaceStrong, in: Circle())
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                    typographyPreview

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Font Style")
                            .font(.lifeTrackCaption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(LifeTrackFontChoice.allCases) { choice in
                                Button {
                                    withAnimation(.snappy(duration: 0.22)) {
                                        appFontChoice = choice.rawValue
                                    }
                                } label: {
                                    TypographyFontChoiceChip(
                                        choice: choice,
                                        isSelected: selectedFontChoice == choice,
                                        theme: theme
                                    )
                                }
                                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97, pressedOpacity: 0.92))
                            }
                        }
                    }

                    TypographyScaleControl(
                        title: "Titles",
                        subtitle: "Headings and large emphasis text.",
                        value: titleScaleBinding,
                        role: .title,
                        accent: theme.accent
                    )

                    TypographyScaleControl(
                        title: "Body",
                        subtitle: "Descriptions, paragraphs, and supporting copy.",
                        value: bodyScaleBinding,
                        role: .body,
                        accent: theme.accent
                    )

                    TypographyScaleControl(
                        title: "Captions",
                        subtitle: "Metadata, helper labels, and smaller notes.",
                        value: captionScaleBinding,
                        role: .caption,
                        accent: theme.accent
                    )

                    Button(action: resetTypography) {
                        Label("Reset Typography", systemImage: "arrow.counterclockwise")
                            .font(.lifeTrack(.footnote, weight: .bold))
                            .foregroundStyle(
                                isTypographyDefault
                                    ? LifeTrackTheme.ColorPalette.tertiaryText
                                    : LifeTrackTheme.ColorPalette.primaryText
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                isTypographyDefault
                                    ? LifeTrackTheme.ColorPalette.controlSurface
                                    : theme.accentSoft,
                                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                            )
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98, pressedOpacity: 0.94))
                    .disabled(isTypographyDefault)
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var typographyPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Plan")
                    .font(.lifeTrack(.title2, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text("Typography changes apply to major headings, descriptions, and smaller labels across LifeTrack.")
                    .font(.lifeTrackBody)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Small copy stays tighter so layouts do not break when you increase the font.")
                    .font(.lifeTrack(.footnote, weight: .medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
            }
        }
    }

    private func resetTypography() {
        appFontChoice = LifeTrackFontChoice.fallback.rawValue
        titleTextScale = LifeTrackTypography.defaultScale
        bodyTextScale = LifeTrackTypography.defaultScale
        captionTextScale = LifeTrackTypography.defaultScale
        LifeTrackHaptics.lightImpact()
    }

    private func percentage(_ scale: Double) -> String {
        "\(Int((scale * 100).rounded()))%"
    }
}

private struct TypographyFontChoiceChip: View {
    let choice: LifeTrackFontChoice
    let isSelected: Bool
    let theme: LifeTrackAppTheme

    private var previewDesign: Font.Design {
        choice.resolvedDesign(default: theme.fontDesign)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("Aa")
                .font(.system(size: 18, weight: .bold, design: previewDesign))
                .foregroundStyle(isSelected ? theme.accent : LifeTrackTheme.ColorPalette.primaryText)
                .frame(width: 36, height: 36)
                .background(
                    (isSelected ? theme.accentSoft : LifeTrackTheme.ColorPalette.controlSurfaceStrong),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(choice.title)
                    .font(.lifeTrack(.subheadline, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(choice.subtitle)
                    .font(.lifeTrack(.caption, weight: .medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected
                ? theme.accentSoft.opacity(LifeTrackTheme.ColorPalette.isDarkTheme ? 0.9 : 1)
                : LifeTrackTheme.ColorPalette.controlSurface,
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(
                    isSelected
                        ? theme.accent.opacity(LifeTrackTheme.ColorPalette.isDarkTheme ? 0.75 : 0.35)
                        : LifeTrackTheme.ColorPalette.hairline.opacity(0.8),
                    lineWidth: isSelected ? 1.1 : 0.8
                )
        }
    }
}

private struct TypographyScaleControl: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    let role: LifeTrackTypography.Role
    let accent: Color

    private var percentage: String {
        "\(Int((LifeTrackTypography.clamped(value, role: role) * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.lifeTrack(.subheadline, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(subtitle)
                        .font(.lifeTrack(.caption, weight: .medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text(percentage)
                    .font(.lifeTrack(.footnote, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.14), in: Capsule())
                    .monospacedDigit()
            }

            Slider(
                value: $value,
                in: LifeTrackTypography.range(for: role),
                step: LifeTrackTypography.sliderStep
            )
            .tint(accent)

            HStack {
                Text("Smaller")
                    .font(.lifeTrack(.caption, weight: .medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)

                Spacer(minLength: 0)

                Text("Default 100%")
                    .font(.lifeTrack(.caption, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                Spacer(minLength: 0)

                Text("Larger")
                    .font(.lifeTrack(.caption, weight: .medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }
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

// MARK: - Subscription

struct SubscriptionSettingsCard: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var isShowingPaywall = false

    var body: some View {
        SectionCardView {
            SectionHeaderView(title: "Subscription", subtitle: "Manage your LifeTrack plan.")

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(subscriptionManager.tier.accentColor.opacity(0.18))
                            .frame(width: 40, height: 40)
                        Image(systemName: subscriptionManager.tier == .free ? "lock.fill" : "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(subscriptionManager.tier.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(subscriptionManager.tier.displayName) Plan")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        Text(subscriptionManager.tier.tagline)
                            .font(.caption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }

                    Spacer(minLength: LifeTrackTheme.Spacing.small)

                    Button(subscriptionManager.tier == .free ? "Upgrade" : "Manage") {
                        isShowingPaywall = true
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(subscriptionManager.tier == .free ? Color.white : LifeTrackTheme.ColorPalette.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        subscriptionManager.tier == .free
                            ? LifeTrackTheme.ColorPalette.accent
                            : LifeTrackTheme.ColorPalette.accentSoft,
                        in: Capsule()
                    )
                }

                if subscriptionManager.tier > .free {
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(subscriptionManager.tier.features) { feature in
                            ProFeatureRow(symbol: feature.icon, label: feature.title, color: feature.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.snappy(duration: 0.28), value: subscriptionManager.tier)
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
    }
}

// MARK: - AI

struct AISettingsCard: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var claudeAPIKey = ClaudeAPIKeyStore.current
    @AppStorage(LifeTrackSettings.Keys.anonymiseBillNamesInAI) private var anonymiseBillNamesInAI = false

    var body: some View {
        if subscriptionManager.tier >= .ultimate {
            card
        }
    }

    private var card: some View {
        SectionCardView {
            SectionHeaderView(title: "AI Settings", subtitle: "Required for AI Task Suggestions.")

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.95, green: 0.72, blue: 0.1).opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "key.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.1))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude API Key")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        Text("Get yours at console.anthropic.com")
                            .font(.caption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                }

                SecureField("sk-ant-...", text: $claudeAPIKey)
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(LifeTrackTheme.ColorPalette.hairline, lineWidth: 0.8)
                    }
                    .onChange(of: claudeAPIKey) { _, newValue in
                        ClaudeAPIKeyStore.set(newValue)
                    }

                if !claudeAPIKey.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Stored securely in Keychain")
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                    .font(.caption)
                }

                Toggle(isOn: $anonymiseBillNamesInAI) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Anonymise bill names in AI prompts")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        Text("Replace category and bill titles with placeholders before sending to Claude.")
                            .font(.caption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Pro Feature Row

struct ProFeatureRow: View {
    let symbol: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
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
