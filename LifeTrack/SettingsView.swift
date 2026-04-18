//
//  SettingsView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import PhotosUI
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LifeTrackSettings.Keys.nickname) private var nickname = ""
    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.avatarVersion) private var avatarVersion = 0
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(LifeTrackSettings.Keys.colorStrength) private var colorStrength = 1.0

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatarImage: UIImage?
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
                        motionCard
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

                ThemeStrengthControl(strength: $colorStrength)
                    .padding(.top, LifeTrackTheme.Spacing.small)
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
            .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.78), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
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
            isSelected ? theme.accentSoft.opacity(0.65) : LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.78),
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.28) : LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
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
                        .fill(LifeTrackTheme.ColorPalette.backgroundTop)
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
                                .stroke(Color.white.opacity(0.9), lineWidth: 1)
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
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.78), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
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

#Preview {
    SettingsView()
}
