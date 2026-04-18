//
//  TaskSafetyOverlays.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct TaskBinUndoState: Identifiable {
    let id = UUID()
    let task: LifeTask
}

struct TaskRestoredToastState: Identifiable {
    let id = UUID()
    let taskTitle: String
}

struct ReminderActionTipToastState: Identifiable {
    let id = UUID()
}

struct LifeTrackConfirmationOverlay: View {
    let symbolName: String
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let tint: Color
    var isDestructive = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                    Image(systemName: symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(tint.opacity(0.18), lineWidth: 8)
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.lifeTrackHeadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: LifeTrackTheme.Spacing.small) {
                    Button(action: onCancel) {
                        Text(cancelTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97))

                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(confirmBackground, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                            .shadow(color: tint.opacity(0.18), radius: 12, x: 0, y: 7)
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97))
                }
            }
            .padding(LifeTrackTheme.Spacing.large)
            .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.8)
            }
            .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(1.2), radius: 24, x: 0, y: 16)
            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
        .animation(animationsEnabled ? .snappy(duration: 0.22) : nil, value: title)
        .zIndex(200)
    }

    private var confirmBackground: some ShapeStyle {
        isDestructive
            ? AnyShapeStyle(LinearGradient(colors: [LifeTrackTheme.ColorPalette.danger, LifeTrackTheme.ColorPalette.danger.mixed(with: .black, amount: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient)
    }
}

struct TaskBinUndoToast: View {
    let taskTitle: String
    let onRestore: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "trash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: 34, height: 34)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Moved to Bin")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(taskTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Button(action: onRestore) {
                Text("Undo")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LifeTrackTheme.ColorPalette.accentGradient, in: Capsule())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.95))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.9), in: Circle())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9))
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.82), lineWidth: 0.8)
        }
        .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(1.1), radius: 18, x: 0, y: 12)
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: .bottom))
        ))
    }
}

struct TaskRestoredToast: View {
    let taskTitle: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                .frame(width: 34, height: 34)
                .background(LifeTrackTheme.ColorPalette.success.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Restored")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(taskTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.9), in: Circle())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9))
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.success.opacity(0.18), lineWidth: 0.8)
        }
        .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(1.1), radius: 18, x: 0, y: 12)
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: .bottom))
        ))
    }
}

struct ReminderActionTipToast: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: 36, height: 36)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())
                .overlay {
                    Circle()
                        .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.16), lineWidth: 7)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("Reminder actions are ready")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text("Hold a LifeTrack notification to complete, snooze, or open the task.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.9), in: Circle())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9))
            .accessibilityLabel("Dismiss reminder actions tip")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.18), lineWidth: 0.8)
        }
        .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(1.1), radius: 18, x: 0, y: 12)
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }
}
