//
//  BetaDashboardInbox.swift
//  LifeTrack
//
//  Inbox preview section extracted from BetaDashboardView. Receives the
//  precomputed inbox items plus per-action callbacks so the parent owns
//  sheet presentation.
//

import SwiftUI

struct BetaDashboardInboxSection: View {
    let inboxItems: [InboxItem]
    let onQuickCapture: () -> Void
    let onVoiceCapture: () -> Void
    let onOpenInbox: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("Inbox")
                    .font(.betaSection)
                    .foregroundStyle(BetaPalette.primaryText)

                Image(systemName: "tray.full")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BetaPalette.accent)

                Spacer(minLength: 0)

                Text(inboxItems.isEmpty ? "Clear" : "\(inboxItems.count) open")
                    .font(.betaCaption(12, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightChromeText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(BetaPalette.lightCardFill, in: Capsule())
            }

            if inboxItems.isEmpty {
                emptyState

                HStack(spacing: 10) {
                    BetaInboxActionButton(
                        title: "Text Capture",
                        icon: "square.and.pencil",
                        iconBg: BetaPalette.qaAccentBg,
                        iconTint: BetaPalette.qaAccentTint,
                        action: onQuickCapture
                    )

                    BetaInboxActionButton(
                        title: "Voice Capture",
                        icon: "mic.fill",
                        iconBg: BetaPalette.qaPlanBg,
                        iconTint: BetaPalette.qaPlanTint,
                        action: onVoiceCapture
                    )
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(inboxItems.prefix(3))) { item in
                        Button(action: onOpenInbox) {
                            BetaInboxPreviewRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if inboxItems.count > 3 {
                    Text("\(inboxItems.count - 3) more item\(inboxItems.count - 3 == 1 ? "" : "s") waiting in inbox.")
                        .font(.betaCaption(12, weight: .medium))
                        .foregroundStyle(BetaPalette.secondaryText)
                }

                HStack(spacing: 10) {
                    BetaInboxActionButton(
                        title: "Open Inbox",
                        icon: "tray.full",
                        iconBg: BetaPalette.qaInfoBg,
                        iconTint: BetaPalette.qaInfoTint,
                        action: onOpenInbox
                    )

                    BetaInboxActionButton(
                        title: "Capture More",
                        icon: "plus",
                        iconBg: BetaPalette.qaAccentBg,
                        iconTint: BetaPalette.qaAccentTint,
                        action: onQuickCapture
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BetaPalette.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "tray.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BetaPalette.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Nothing waiting in inbox")
                    .font(.lifeTrack(.subheadline, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightCardPrimaryText)
                Text("Capture rough notes first, then turn them into structured tasks when you are ready.")
                    .font(.lifeTrack(.footnote, weight: .regular))
                    .foregroundStyle(BetaPalette.lightCardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
        }
    }
}

private struct BetaInboxActionButton: View {
    let title: String
    let icon: String
    let iconBg: Color
    let iconTint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(iconBg)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(iconTint)
                }

                Text(title)
                    .font(.betaBody(13, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightCardPrimaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}
