//
//  SettingsView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    @Query(sort: \LifeTask.updatedAt, order: .reverse) private var tasks: [LifeTask]

    @AppStorage(LifeTrackSettings.Keys.nickname) private var nickname = ""
    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.appearanceMode) private var appearanceModeRaw = AppearanceMode.current.rawValue
    @AppStorage(LifeTrackSettings.Keys.appFontChoice) private var appFontChoice = LifeTrackFontChoice.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.titleTextScale) private var titleTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.bodyTextScale) private var bodyTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.captionTextScale) private var captionTextScale = LifeTrackTypography.defaultScale
    @AppStorage(LifeTrackSettings.Keys.avatarVersion) private var avatarVersion = 0
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(LifeTrackSettings.Keys.colorStrength) private var colorStrength = 1.0
    @AppStorage(LifeTrackSettings.Keys.binRetentionPeriod) private var binRetentionRawValue = TaskBinRetentionPeriod.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.completedArchivePeriod) private var completedArchiveRawValue = CompletedArchivePeriod.fallback.rawValue
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var isShowingPaywall = false
    @State private var claudeAPIKey = ClaudeAPIKeyStore.current
    @AppStorage(LifeTrackSettings.Keys.anonymiseBillNamesInAI) private var anonymiseBillNamesInAI = false
    @AppStorage(LifeTrackSettings.Keys.dashboardExperience) private var dashboardExperienceRaw = DashboardExperience.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.hideStatusBar) private var hideStatusBar = false
    @AppStorage(LifeTrackSettings.Keys.moneyCurrencyCode) private var moneyCurrencyCode = MoneyCurrency.defaultCode
    @AppStorage(LifeTrackSettings.Keys.moneyCurrencyLocked) private var isMoneyCurrencyLocked = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatarImage: UIImage?
    @State private var avatarError: String?
    @State private var isImportingAvatar = false
    @State private var isTypographyExpanded = false
    @State private var nicknameInputFrame: CGRect = .zero
    @FocusState private var focusedField: SettingsFocusField?

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                        header
                        profileCard
                        proCard
                        if subscriptionManager.tier >= .ultimate {
                            aiCard
                        }
                        themeCard
                        typographyCard
                        motionCard
                        dashboardExperienceCard
                        displayCard
                        moneyCard
                        taskDataCard
                        archiveCard
                        binCard
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .coordinateSpace(name: SettingsCoordinateSpace.scrollView)
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            dismissKeyboardIfNeeded(for: value.location)
                        }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        focusedField = nil
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LifeTrackTheme.ColorPalette.isDarkTheme
                            ? selectedTheme.accent
                            : LifeTrackTheme.ColorPalette.secondaryText
                    )
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                importAvatar(from: newItem)
            }
            .onAppear {
                purgeExpiredBinItems()
                archiveOldCompletedTasks()
            }
            .onChange(of: binRetentionRawValue) { _, _ in
                purgeExpiredBinItems()
            }
            .onChange(of: completedArchiveRawValue) { _, _ in
                archiveOldCompletedTasks()
            }
            .onChange(of: appearanceModeRaw) { _, _ in
                syncDarkModeFlagSynchronously()
            }
            .onChange(of: systemColorScheme) { _, _ in
                syncDarkModeFlagSynchronously()
            }
            .id("settings-\(appearanceModeRaw)-\(systemColorScheme == .dark ? "d" : "l")")
            .sheet(isPresented: isShowingAvatarCropper) {
                if let pendingAvatarImage {
                    AvatarCropView(
                        image: pendingAvatarImage,
                        onCancel: {
                            self.pendingAvatarImage = nil
                        },
                        onSave: saveCroppedAvatar
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
        .tint(selectedTheme.accent)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Settings")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            InfoTipButton(message: "Personalize how LifeTrack greets you and feels day to day.")

            Spacer(minLength: 0)
        }
    }

    private var profileCard: some View {
        SectionCardView {
            HStack(alignment: .top) {
                SectionHeaderView(title: "Profile", subtitle: "Name and avatar.")
                Spacer(minLength: LifeTrackTheme.Spacing.small)
                Button {
                    isShowingPaywall = true
                } label: {
                    let isFree = subscriptionManager.tier == .free
                    Text(isFree ? "Upgrade" : "Manage")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isFree ? Color.white : LifeTrackTheme.ColorPalette.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isFree ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.accentSoft,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(subscriptionManager.tier == .free ? "Upgrade subscription" : "Manage subscription")
            }

            HStack(alignment: .center, spacing: LifeTrackTheme.Spacing.large) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        ProfileAvatarView(size: 86, avatarVersion: avatarVersion, showsEditBadge: true)

                        if isImportingAvatar {
                            Circle()
                                .fill(Color.black.opacity(0.18))
                                .frame(width: 86, height: 86)

                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text(greetingPreview)
                        .font(.lifeTrackHeadline)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)

                    HStack(spacing: LifeTrackTheme.Spacing.small) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Change Photo", systemImage: "photo")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if AvatarImageStore.hasAvatar {
                            Button(action: removeAvatar) {
                                Image(systemName: "trash")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                                    .frame(width: 34, height: 34)
                                    .background(LifeTrackTheme.ColorPalette.danger.opacity(0.10), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove photo")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Nickname")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                ZStack(alignment: .leading) {
                    if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("What should LifeTrack call you?")
                            .font(.body.weight(.medium))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.placeholderText)
                            .padding(.horizontal, 14)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $nickname)
                        .font(.body.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($focusedField, equals: .nickname)
                        .onSubmit {
                            focusedField = nil
                        }
                        .padding(14)
                }
                .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: NicknameInputFramePreferenceKey.self,
                            value: proxy.frame(in: .named(SettingsCoordinateSpace.scrollView))
                        )
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
                }
                .onPreferenceChange(NicknameInputFramePreferenceKey.self) { frame in
                    nicknameInputFrame = frame
                }
            }

            if let avatarError {
                Text(avatarError)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var themeCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Theme", subtitle: "Choose the mood.")

            VStack(spacing: LifeTrackTheme.Spacing.small) {
                ForEach(LifeTrackAppTheme.allCases) { theme in
                    Button {
                        withAnimation(.snappy) {
                            selectedThemeID = theme.rawValue
                        }
                    } label: {
                        ThemeOptionRow(
                            theme: theme,
                            isSelected: selectedThemeID == theme.rawValue
                        )
                    }
                    .buttonStyle(.plain)
                }

                AppearanceModePicker(selectionRaw: $appearanceModeRaw, theme: selectedTheme)

                ThemeStrengthControl(strength: $colorStrength)
                    .padding(.top, LifeTrackTheme.Spacing.small)
            }
        }
    }

    private var typographyCard: some View {
        SectionCardView {
            Button {
                withAnimation(.snappy(duration: 0.24)) {
                    isTypographyExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                    Image(systemName: "textformat.alt")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selectedTheme.accent)
                        .frame(width: 42, height: 42)
                        .background(selectedTheme.accentSoft, in: Circle())

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
                                .foregroundStyle(selectedTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedTheme.accentSoft, in: Capsule())

                            Text(typographyScaleSummary)
                                .font(.lifeTrackCaption)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: LifeTrackTheme.Spacing.small)

                    Image(systemName: isTypographyExpanded ? "chevron.up" : "chevron.down")
                        .font(.lifeTrack(.caption, weight: .bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        .frame(width: 32, height: 32)
                        .background(LifeTrackTheme.ColorPalette.controlSurfaceStrong, in: Circle())
                }
            }
            .buttonStyle(.plain)

            if isTypographyExpanded {
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
                                        theme: selectedTheme
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
                        accent: selectedTheme.accent
                    )

                    TypographyScaleControl(
                        title: "Body",
                        subtitle: "Descriptions, paragraphs, and supporting copy.",
                        value: bodyScaleBinding,
                        role: .body,
                        accent: selectedTheme.accent
                    )

                    TypographyScaleControl(
                        title: "Captions",
                        subtitle: "Metadata, helper labels, and smaller notes.",
                        value: captionScaleBinding,
                        role: .caption,
                        accent: selectedTheme.accent
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
                                    : selectedTheme.accentSoft,
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

    private var motionCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Motion", subtitle: "Subtle interaction polish.")

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: animationsEnabled ? "sparkles" : "pause.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selectedTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(selectedTheme.accentSoft, in: Circle())

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
                    .tint(selectedTheme.accent)
            }
            .padding(12)
            .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
            }
        }
    }

    private var dashboardExperienceCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Dashboard Experience",
                subtitle: "Choose which home screen appears after launch. Restart the app to switch."
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(DashboardExperience.allCases) { experience in
                    Button {
                        withAnimation(.snappy) {
                            dashboardExperienceRaw = experience.rawValue
                        }
                    } label: {
                        DashboardExperienceChip(
                            experience: experience,
                            isSelected: dashboardExperienceRaw == experience.rawValue
                        )
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                }
            }

            NavigationLink {
                BetaDashboardView()
                    .navigationTitle("Beta Dashboard")
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                HStack(spacing: LifeTrackTheme.Spacing.medium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LifeTrackTheme.ColorPalette.accent.opacity(0.18))
                            .frame(width: 42, height: 42)
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Preview Beta Dashboard")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            Text("BETA")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LifeTrackTheme.ColorPalette.accent, in: Capsule())
                        }
                        Text("Streak, metrics, quick actions, and today's focus.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: LifeTrackTheme.Spacing.small)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                        .frame(width: 32, height: 32)
                        .background(LifeTrackTheme.ColorPalette.controlSurfaceStrong, in: Circle())
                }
                .padding(12)
                .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
                }
            }
            .buttonStyle(.plain)

            betaShapesControl
        }
    }

    @AppStorage(LifeTrackSettings.Keys.betaShapesOpacity) private var betaShapesOpacity: Double = 0.35

    private var displayCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Display", subtitle: "Fine-tune what's visible on screen.")

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: hideStatusBar ? "eye.slash.fill" : "wifi")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selectedTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(selectedTheme.accentSoft, in: Circle())

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
                    .tint(selectedTheme.accent)
            }
            .padding(12)
            .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
            }
        }
    }

    private var moneyCard: some View {
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

    private var betaShapesControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: LifeTrackTheme.Spacing.small) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)

                Text("Background Shapes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                Text("\(Int(betaShapesOpacity * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .monospacedDigit()
            }

            Slider(value: $betaShapesOpacity, in: 0...1, step: 0.05)
                .tint(LifeTrackTheme.ColorPalette.accent)

            Text("Adjusts how visible the drifting circles are behind the beta dashboard.")
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

    private var proCard: some View {
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

    private var aiCard: some View {
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

    private var archiveCard: some View {
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

                    Text(completedArchivePeriod == .off ? "No tasks will be archived automatically." : "Completed tasks move to Bin after \(completedArchivePeriod.title.lowercased()).")
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
                                isSelected: completedArchivePeriod == period
                            )
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                    }
                }
            }
        }
    }

    private var binCard: some View {
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

                    Text(binRetentionPeriod == .immediately ? "Deleted tasks are removed forever immediately." : "Items expire after \(binRetentionPeriod.title.lowercased()).")
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
                                isSelected: binRetentionPeriod == period
                            )
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95, pressedOpacity: 0.92))
                    }
                }
            }
        }
    }

    private var taskDataCard: some View {
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

    private var selectedFontChoice: LifeTrackFontChoice {
        LifeTrackFontChoice(rawValue: appFontChoice) ?? .fallback
    }

    private var typographyScaleSummary: String {
        "T \(typographyPercentage(clampedTitleScale))  B \(typographyPercentage(clampedBodyScale))  C \(typographyPercentage(clampedCaptionScale))"
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

    private var clampedTitleScale: Double {
        LifeTrackTypography.clamped(titleTextScale, role: .title)
    }

    private var clampedBodyScale: Double {
        LifeTrackTypography.clamped(bodyTextScale, role: .body)
    }

    private var clampedCaptionScale: Double {
        LifeTrackTypography.clamped(captionTextScale, role: .caption)
    }

    private var selectedTheme: LifeTrackAppTheme {
        LifeTrackAppTheme(rawValue: selectedThemeID) ?? .fallback
    }

    private var binRetentionPeriod: TaskBinRetentionPeriod {
        TaskBinRetentionPeriod(rawValue: binRetentionRawValue) ?? .fallback
    }

    private var completedArchivePeriod: CompletedArchivePeriod {
        CompletedArchivePeriod(rawValue: completedArchiveRawValue) ?? .fallback
    }

    private var binCount: Int {
        tasks.filter(\.isDeleted).count
    }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted && !$0.isDeleted }.count
    }

    private var cleanedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var greetingPreview: String {
        cleanedNickname.isEmpty ? "Good afternoon" : "Good afternoon, \(cleanedNickname)"
    }

    private var isShowingAvatarCropper: Binding<Bool> {
        Binding(
            get: { pendingAvatarImage != nil },
            set: { isPresented in
                if !isPresented {
                    pendingAvatarImage = nil
                }
            }
        )
    }

    private func importAvatar(from item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        isImportingAvatar = true
        avatarError = nil

        Task {
            defer {
                isImportingAvatar = false
                selectedPhotoItem = nil
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    avatarError = "That image could not be imported."
                    return
                }

                guard let image = UIImage(data: data) else {
                    avatarError = "That image could not be imported."
                    return
                }

                pendingAvatarImage = image
            } catch {
                avatarError = "That image could not be imported."
            }
        }
    }

    private func saveCroppedAvatar(_ image: UIImage) {
        do {
            try AvatarImageStore.saveAvatar(image: image)
            pendingAvatarImage = nil
            avatarVersion += 1
            avatarError = nil
        } catch {
            avatarError = "That image could not be saved."
        }
    }

    private func removeAvatar() {
        AvatarImageStore.deleteAvatar()
        avatarVersion += 1
        avatarError = nil
    }

    private func syncDarkModeFlagSynchronously() {
        let mode = AppearanceMode(rawValue: appearanceModeRaw) ?? .auto
        let resolved = mode.resolve(system: systemColorScheme)
        UserDefaults.standard.set(resolved == .dark, forKey: LifeTrackSettings.Keys.darkModeEnabled)
    }

    private func purgeExpiredBinItems() {
        TaskLifecycleManager.purgeExpiredBinItems(
            from: tasks,
            in: modelContext,
            retentionPeriod: binRetentionPeriod
        )
    }

    private func archiveOldCompletedTasks() {
        TaskLifecycleManager.archiveOldCompletedTasks(
            from: tasks,
            in: modelContext,
            archivePeriod: completedArchivePeriod
        )
    }

    private func dismissKeyboardIfNeeded(for tapLocation: CGPoint) {
        guard focusedField != nil else {
            return
        }

        let tappableInputFrame = nicknameInputFrame.insetBy(dx: -8, dy: -8)

        if !tappableInputFrame.contains(tapLocation) {
            focusedField = nil
        }
    }

    private func resetTypography() {
        appFontChoice = LifeTrackFontChoice.fallback.rawValue
        titleTextScale = LifeTrackTypography.defaultScale
        bodyTextScale = LifeTrackTypography.defaultScale
        captionTextScale = LifeTrackTypography.defaultScale
        LifeTrackHaptics.lightImpact()
    }

    private func typographyPercentage(_ scale: Double) -> String {
        "\(Int((scale * 100).rounded()))%"
    }
}

private enum SettingsFocusField: Hashable {
    case nickname
}

private enum SettingsCoordinateSpace {
    static let scrollView = "settings-scroll-view"
}

private struct NicknameInputFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
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

private struct CompletedArchiveChip: View {
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

private struct BinRetentionChip: View {
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

private struct ThemeOptionRow: View {
    let theme: LifeTrackAppTheme
    let isSelected: Bool

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(theme.accentSoft)
                    .frame(width: 42, height: 42)

                Image(systemName: theme.symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(theme.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(theme.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            ThemeSwatches(theme: theme)

            ThemeSelectionIndicator(theme: theme, isSelected: isSelected)
        }
        .padding(12)
        .background(
            isSelected
                ? selectedBackground
                : LifeTrackTheme.ColorPalette.controlSurface,
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(isSelected ? selectedBorder : LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }

    private var selectedBackground: Color {
        if LifeTrackTheme.ColorPalette.isDarkTheme {
            return theme.accentSoft.mixed(with: LifeTrackTheme.ColorPalette.cardElevated, amount: 0.34)
        }
        return theme.accentSoft.opacity(0.65)
    }

    private var selectedBorder: Color {
        LifeTrackTheme.ColorPalette.isDarkTheme ? theme.accent.opacity(0.42) : theme.accent.opacity(0.28)
    }
}

private struct ThemeSelectionIndicator: View {
    let theme: LifeTrackAppTheme
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? theme.accent.opacity(0.38) : LifeTrackTheme.ColorPalette.tertiaryText.opacity(0.36), lineWidth: 1.5)
                .frame(width: 24, height: 24)

            if isSelected {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.accent, theme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 18, height: 18)

                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ThemeStrengthControl: View {
    @Binding var strength: Double

    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Color Strength")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Tune the selected theme from softer to stronger.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                Text("\(Int((strength * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let progress = normalizedProgress

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LifeTrackTheme.ColorPalette.controlSurfaceStrong)
                        .frame(height: 10)
                        .overlay {
                            Capsule()
                                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
                        }

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    LifeTrackTheme.ColorPalette.accentSoft,
                                    LifeTrackTheme.ColorPalette.accent,
                                    LifeTrackTheme.ColorPalette.accentDeep
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(18, width * progress), height: 10)

                    Circle()
                        .fill(LifeTrackTheme.ColorPalette.cardElevated)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .fill(LifeTrackTheme.ColorPalette.accentGradient)
                                .frame(width: 18, height: 18)
                        }
                        .overlay {
                            Circle()
                                .stroke(
                                    LifeTrackTheme.ColorPalette.isDarkTheme
                                        ? LifeTrackTheme.ColorPalette.hairline.opacity(0.95)
                                        : Color.white.opacity(0.9),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.22), radius: 10, x: 0, y: 5)
                        .offset(x: min(max(width * progress - 14, 0), width - 28))
                }
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateStrength(for: value.location.x, width: width)
                        }
                )
            }
            .frame(height: 32)

            HStack {
                Text("Softer")
                Spacer()
                Button("Reset 100%") {
                    setStrength(1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                Spacer()
                Text("Stronger")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }

    private var normalizedProgress: Double {
        let range = LifeTrackAppTheme.colorStrengthRange
        return (clampedStrength - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var clampedStrength: Double {
        let range = LifeTrackAppTheme.colorStrengthRange
        return min(max(strength, range.lowerBound), range.upperBound)
    }

    private func updateStrength(for locationX: CGFloat, width: CGFloat) {
        let progress = min(max(Double(locationX / max(width, 1)), 0), 1)
        let range = LifeTrackAppTheme.colorStrengthRange
        setStrength(range.lowerBound + progress * (range.upperBound - range.lowerBound))
    }

    private func setStrength(_ value: Double) {
        let range = LifeTrackAppTheme.colorStrengthRange
        let nextValue = min(max(value, range.lowerBound), range.upperBound)

        guard animationsEnabled else {
            strength = nextValue
            return
        }

        withAnimation(.smooth(duration: 0.18)) {
            strength = nextValue
        }
    }
}

private struct AppearanceModePicker: View {
    @Binding var selectionRaw: String

    let theme: LifeTrackAppTheme

    private var selection: AppearanceMode {
        AppearanceMode(rawValue: selectionRaw) ?? .auto
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                ZStack {
                    Circle()
                        .fill(theme.accentSoft)
                        .frame(width: 42, height: 42)

                    Image(systemName: selection.symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Appearance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Auto follows your device. Light or Dark keeps your theme fixed either way.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Picker("Appearance", selection: $selectionRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.controlSurface, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }
}

private struct ThemeSwatches: View {
    let theme: LifeTrackAppTheme

    var body: some View {
        HStack(spacing: -5) {
            Circle()
                .fill(theme.backgroundTop)
            Circle()
                .fill(theme.backgroundBottom)
            Circle()
                .fill(theme.accent)
            Circle()
                .fill(theme.secondaryAccent)
        }
        .frame(width: 54, height: 18)
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        }
    }
}

private struct ProFeatureRow: View {
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

private struct DashboardExperienceChip: View {
    let experience: DashboardExperience
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: experience == .beta ? "sparkles" : "house.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : LifeTrackTheme.ColorPalette.accent)
                Text(experience.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? .white : LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Text(experience.subtitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? Color.white.opacity(0.82) : LifeTrackTheme.ColorPalette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

#Preview {
    SettingsView()
}
