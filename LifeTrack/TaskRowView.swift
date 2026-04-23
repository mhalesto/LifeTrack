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
    var showsBorder: Bool = true

    @State private var restingOffset: CGFloat = 0
    @State private var isShowingActions = false
    @GestureState private var dragOffset: CGFloat = 0
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    private let leadingRevealWidth: CGFloat = 78
    private let trailingRevealWidth: CGFloat = 150
    private let swipeMinimumDistance: CGFloat = 22
    private let swipeTrackingBias: CGFloat = 1.3
    private let swipeCommitBias: CGFloat = 1.45

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
        .sheet(isPresented: $isShowingActions) {
            TaskRowActionSheet(
                taskTitle: task.title,
                onEdit: {
                    isShowingActions = false
                    onEdit()
                },
                onDelete: {
                    isShowingActions = false
                    onDelete()
                }
            )
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: LifeTrackTheme.Spacing.small) {
            Button {
                playActionFeedback()
                onToggleCompletion()
            } label: {
                TaskCompletionCheckmark(
                    isCompleted: task.isCompleted,
                    size: leadingIconSize
                )
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

                    WrappingChipLayout(spacing: 7, rowSpacing: 6) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.99, pressedOpacity: 0.96))

            Button {
                playActionFeedback()
                isShowingActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(LifeTrackTheme.ColorPalette.backgroundBottom.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Task actions")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            if showsBorder {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
            }
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
        DragGesture(minimumDistance: swipeMinimumDistance)
            .updating($dragOffset) { value, state, _ in
                guard isHorizontalSwipe(value, minimumDistance: swipeMinimumDistance, bias: swipeTrackingBias) else {
                    return
                }

                state = value.translation.width
            }
            .onEnded { value in
                guard isHorizontalSwipe(value, minimumDistance: swipeMinimumDistance + 8, bias: swipeCommitBias) else {
                    return
                }

                let predictedOffset = clampedOffset(restingOffset + value.predictedEndTranslation.width)
                let nextOffset: CGFloat
                if predictedOffset > leadingRevealWidth * 0.62 {
                    nextOffset = leadingRevealWidth
                } else if predictedOffset < -(trailingRevealWidth * 0.50) {
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

    private func isHorizontalSwipe(_ value: DragGesture.Value, minimumDistance: CGFloat, bias: CGFloat) -> Bool {
        let horizontalDistance = abs(value.translation.width)
        let verticalDistance = abs(value.translation.height)

        return horizontalDistance >= minimumDistance && horizontalDistance > verticalDistance * bias
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

private struct TaskCompletionCheckmark: View {
    let isCompleted: Bool
    let size: CGFloat

    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.accent.opacity(0.08))
                .overlay {
                    Circle()
                        .stroke(
                            isCompleted ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.accent.opacity(0.65),
                            lineWidth: isCompleted ? 0 : 2.4
                        )
                }
                .shadow(
                    color: isCompleted ? LifeTrackTheme.ColorPalette.accent.opacity(0.24) : .clear,
                    radius: 8,
                    y: 4
                )

            Image(systemName: isCompleted ? "checkmark" : "circle")
                .font(.system(size: isCompleted ? size * 0.40 : size * 0.08, weight: .bold))
                .foregroundStyle(isCompleted ? .white : Color.clear)
                .scaleEffect(isCompleted ? 1 : 0.3)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
        .scaleEffect(isCompleted ? 1.03 : 1)
        .animation(animationsEnabled ? .snappy(duration: 0.22) : nil, value: isCompleted)
    }
}

private struct TaskRowActionSheet: View {
    let taskTitle: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Task actions")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text(taskTitle)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(1)
                }

                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    sheetActionRow(
                        title: "Edit task",
                        subtitle: "Change details, dates, notes, or money fields",
                        systemImage: "pencil",
                        tint: LifeTrackTheme.ColorPalette.accent,
                        action: onEdit
                    )

                    sheetActionRow(
                        title: "Move to Bin",
                        subtitle: "Remove it from active focus",
                        systemImage: "trash",
                        tint: LifeTrackTheme.ColorPalette.danger,
                        action: onDelete
                    )
                }
            }
            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
            .padding(.top, LifeTrackTheme.Spacing.large)
            .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
        }
    }

    private func sheetActionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                action()
            }
        } label: {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(title == "Move to Bin" ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.primaryText)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            }
            .padding(LifeTrackTheme.Spacing.medium)
            .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 0.8)
            }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98, pressedOpacity: 0.94))
    }
}

struct WrappingChipLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? CGFloat.greatestFiniteMagnitude
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedX = currentX == 0 ? size.width : currentX + spacing + size.width

            if currentX > 0 && proposedX > maxWidth {
                totalHeight += currentRowHeight + rowSpacing
                widestRow = max(widestRow, currentX)
                currentX = size.width
                currentRowHeight = size.height
            } else {
                currentX = proposedX
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        totalHeight += currentRowHeight
        widestRow = max(widestRow, currentX)

        return CGSize(width: proposal.width ?? widestRow, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedX = currentX == bounds.minX ? currentX + size.width : currentX + spacing + size.width

            if currentX > bounds.minX && proposedX > bounds.maxX {
                currentX = bounds.minX
                currentY += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
