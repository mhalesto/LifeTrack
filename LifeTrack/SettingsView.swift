//
//  SettingsView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemColorScheme
    @Query(sort: \LifeTask.updatedAt, order: .reverse) private var tasks: [LifeTask]

    @AppStorage(LifeTrackSettings.Keys.themeID) private var selectedThemeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.appearanceMode) private var appearanceModeRaw = AppearanceMode.current.rawValue
    @AppStorage(LifeTrackSettings.Keys.binRetentionPeriod) private var binRetentionRawValue = TaskBinRetentionPeriod.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.completedArchivePeriod) private var completedArchiveRawValue = CompletedArchivePeriod.fallback.rawValue
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var isShowingPaywall = false
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
                        ProfileSettingsCard(
                            focusedField: $focusedField,
                            onUpgradeTap: { isShowingPaywall = true },
                            onNicknameFrameChange: { nicknameInputFrame = $0 }
                        )
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

    private var selectedTheme: LifeTrackAppTheme {
        LifeTrackAppTheme(rawValue: selectedThemeID) ?? .fallback
    }

    private var binRetentionPeriod: TaskBinRetentionPeriod {
        TaskBinRetentionPeriod(rawValue: binRetentionRawValue) ?? .fallback
    }

    private var completedArchivePeriod: CompletedArchivePeriod {
        CompletedArchivePeriod(rawValue: completedArchiveRawValue) ?? .fallback
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

#Preview {
    SettingsView()
}
