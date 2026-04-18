//
//  SettingsView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import PhotosUI
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LifeTrackSettings.Keys.nickname) private var nickname = ""
    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.avatarVersion) private var avatarVersion = 0

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarError: String?
    @State private var isImportingAvatar = false

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                        header
                        profileCard
                        themeCard
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                importAvatar(from: newItem)
            }
        }
        .tint(selectedTheme.accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Personalize how LifeTrack greets you and feels day to day.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var profileCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Profile", subtitle: "Name and avatar.")

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
                        .padding(14)
                }
                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
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
            }
        }
    }

    private var selectedTheme: LifeTrackAppTheme {
        LifeTrackAppTheme(rawValue: selectedThemeID) ?? .fallback
    }

    private var cleanedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var greetingPreview: String {
        cleanedNickname.isEmpty ? "Good afternoon" : "Good afternoon, \(cleanedNickname)"
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

                try AvatarImageStore.saveAvatar(data: data)
                avatarVersion += 1
            } catch {
                avatarError = "That image could not be imported."
            }
        }
    }

    private func removeAvatar() {
        AvatarImageStore.deleteAvatar()
        avatarVersion += 1
        avatarError = nil
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

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isSelected ? theme.accent : LifeTrackTheme.ColorPalette.tertiaryText)
        }
        .padding(12)
        .background(
            isSelected ? theme.accentSoft.opacity(0.65) : LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.78),
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.28) : LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
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
        }
        .frame(width: 46, height: 18)
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        }
    }
}

#Preview {
    SettingsView()
}
