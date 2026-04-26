//
//  LifeTrackButtons.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct LifeTrackPressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var pressedOpacity: Double = 0.94

    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(animationsEnabled && configuration.isPressed ? scale : 1)
            .opacity(animationsEnabled && configuration.isPressed ? pressedOpacity : 1)
            .animation(animationsEnabled ? .smooth(duration: 0.16) : nil, value: configuration.isPressed)
    }
}

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
            .padding(.vertical, 12)
            .background(
                LifeTrackTheme.ColorPalette.accentGradient,
                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
            )
            .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.22), radius: 12, x: 0, y: 7)
            .opacity(isDisabled ? 0.45 : 1)
        }
        .disabled(isDisabled)
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.985))
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
            .padding(.vertical, 11)
            .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline, lineWidth: 0.8)
            }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.985))
    }
}

struct PrimaryFloatingButton: View {
    var accessibilityLabel: String = "Add task"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LifeTrackTheme.ColorPalette.accentGradient,
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.34), radius: 22, x: 0, y: 14)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92, pressedOpacity: 0.96))
        .accessibilityLabel(accessibilityLabel)
    }
}

struct VoiceFloatingButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    isRecording
                        ? AnyShapeStyle(LifeTrackTheme.ColorPalette.danger)
                        : AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(
                    color: (isRecording ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.accent).opacity(0.34),
                    radius: 22,
                    x: 0,
                    y: 14
                )
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92, pressedOpacity: 0.96))
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color
    var width: CGFloat = 178
    var height: CGFloat = 68
    var iconSize: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: iconSize, height: iconSize)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)

                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: width, height: height, alignment: .leading)
            .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
            }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97))
    }
}
