//
//  TaskRowView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI
import UIKit

struct TaskRowView: View {
    let task: LifeTask
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var categoryOption: TaskCategoryOption? = nil
    var verticalPadding: CGFloat = 12
    var leadingIconSize: CGFloat = 28

    @State private var restingOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    private let leadingRevealWidth: CGFloat = 78
    private let trailingRevealWidth: CGFloat = 150

    var body: some View {
        ZStack {
            swipeActions

            rowContent
                .overlay {
                    if restingOffset != 0 {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                closeSwipe()
                            }
                    }
                }
                .offset(x: currentOffset)
                .simultaneousGesture(swipeGesture)
                .animation(animationsEnabled ? .interactiveSpring(response: 0.28, dampingFraction: 0.82) : nil, value: restingOffset)
                .animation(animationsEnabled ? .interactiveSpring(response: 0.18, dampingFraction: 0.86) : nil, value: dragOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: leadingIconSize * 0.78, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.tertiaryText)
                    .frame(width: leadingIconSize, height: leadingIconSize)
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9, pressedOpacity: 0.9))
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

            NavigationLink {
                TaskDetailView(task: task)
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.secondaryText : LifeTrackTheme.ColorPalette.primaryText)
                            .strikethrough(task.isCompleted)
                            .lineLimit(2)
                            .layoutPriority(1)

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 8) {
                        CategoryChipView(option: categoryOption ?? task.categoryOption(customCategories: []))

                        StatusPillView(
                            title: task.dueDate.dayMonthString,
                            symbolName: task.isOverdue ? "exclamationmark.circle.fill" : "clock",
                            tint: task.isOverdue ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.secondaryText
                        )

                        StatusPillView(
                            title: task.durationTitle,
                            symbolName: "timer",
                            tint: LifeTrackTheme.ColorPalette.secondaryText
                        )

                        if task.priority == .high {
                            StatusPillView(
                                title: "High",
                                symbolName: "flag.fill",
                                tint: TaskPriority.high.tint
                            )
                        }

                        if task.recurrence != .none {
                            StatusPillView(
                                title: task.recurrence.shortTitle,
                                symbolName: "repeat",
                                tint: task.recurrence.tint
                            )
                        }

                        if task.hasDocument {
                            Image(systemName: "paperclip")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .frame(width: 22, height: 22)
                                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())
                        }
                    }
                }
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.99, pressedOpacity: 0.96))

            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Move to Bin", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(LifeTrackTheme.ColorPalette.backgroundBottom.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }

    private var swipeActions: some View {
        HStack(spacing: 0) {
            Button {
                playActionFeedback()
                closeSwipe()
                onToggleCompletion()
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: task.isCompleted ? "arrow.uturn.left" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text(task.isCompleted ? "Open" : "Done")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(width: leadingRevealWidth)
                .frame(maxHeight: .infinity)
                .background(task.isCompleted ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.success)
            }
            .buttonStyle(.plain)
            .opacity(currentOffset > 6 ? 1 : 0)

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                Button {
                    playActionFeedback()
                    closeSwipe()
                    onEdit()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .bold))
                        Text("Edit")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .frame(width: trailingRevealWidth / 2)
                    .frame(maxHeight: .infinity)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    playActionFeedback()
                    closeSwipe()
                    onDelete()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .bold))
                        Text("Bin")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: trailingRevealWidth / 2)
                    .frame(maxHeight: .infinity)
                    .background(LifeTrackTheme.ColorPalette.danger)
                }
                .buttonStyle(.plain)
            }
            .opacity(currentOffset < -6 ? 1 : 0)
        }
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                let predictedOffset = clampedOffset(restingOffset + value.predictedEndTranslation.width)
                let nextOffset: CGFloat
                if predictedOffset > leadingRevealWidth * 0.46 {
                    nextOffset = leadingRevealWidth
                } else if predictedOffset < -(trailingRevealWidth * 0.36) {
                    nextOffset = -trailingRevealWidth
                } else {
                    nextOffset = 0
                }

                if animationsEnabled && nextOffset != restingOffset {
                    playActionFeedback()
                }

                updateRestingOffset(nextOffset, animation: .interactiveSpring(response: 0.3, dampingFraction: 0.82))
            }
    }

    private var currentOffset: CGFloat {
        clampedOffset(restingOffset + dragOffset)
    }

    private func clampedOffset(_ offset: CGFloat) -> CGFloat {
        min(max(offset, -trailingRevealWidth), leadingRevealWidth)
    }

    private func closeSwipe() {
        updateRestingOffset(0, animation: .interactiveSpring(response: 0.28, dampingFraction: 0.86))
    }

    private func updateRestingOffset(_ offset: CGFloat, animation: Animation) {
        guard animationsEnabled else {
            restingOffset = offset
            return
        }

        withAnimation(animation) {
            restingOffset = offset
        }
    }

    private func playActionFeedback() {
        guard animationsEnabled else {
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
