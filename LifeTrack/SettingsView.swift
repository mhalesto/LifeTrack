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
    @AppStorage(LifeTrackSettings.Keys.avatarVersion) private var avatarVersion = 0
    @AppStorage(LifeTrackSettings.Keys.binRetentionPeriod) private var binRetentionRawValue = TaskBinRetentionPeriod.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.completedArchivePeriod) private var completedArchiveRawValue = CompletedArchivePeriod.fallback.rawValue
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var isShowingPaywall = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatarImage: UIImage?
    @State private var avatarError: String?
    @State private var isImportingAvatar = false
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
                        SubscriptionSettingsCard()
                        AISettingsCard()
                        ThemeSettingsCard()
                        TypographySettingsCard()
                        MotionSettingsCard()
                        BackgroundPatternSettingsCard()
                        DisplaySettingsCard()
                        MoneySettingsCard()
                        TaskDataSettingsCard()
                        ArchiveSettingsCard()
                        BinSettingsCard()
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
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView()
                    .environmentObject(subscriptionManager)
            }
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

    private var selectedTheme: LifeTrackAppTheme {
        LifeTrackAppTheme(rawValue: selectedThemeID) ?? .fallback
    }

    private var binRetentionPeriod: TaskBinRetentionPeriod {
        TaskBinRetentionPeriod(rawValue: binRetentionRawValue) ?? .fallback
    }

    private var completedArchivePeriod: CompletedArchivePeriod {
        CompletedArchivePeriod(rawValue: completedArchiveRawValue) ?? .fallback
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

#Preview {
    SettingsView()
}
