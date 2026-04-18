//
//  LifeTrackButtons.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct LifeTrackPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [
                        LifeTrackTheme.ColorPalette.accent,
                        Color(hex: 0x243FA3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
            )
            .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.24), radius: 14, x: 0, y: 8)
            .opacity(isDisabled ? 0.45 : 1)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

struct LifeTrackSecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LinearGradient(
                        colors: [
                            LifeTrackTheme.ColorPalette.accent,
                            Color(hex: 0x243FA3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.34), radius: 22, x: 0, y: 14)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task")
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 184, height: 72, alignment: .leading)
            .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }
}
