//
//  TaskRowView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct TaskRowView: View {
    let task: LifeTask
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.tertiaryText)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

            NavigationLink {
                TaskDetailView(task: task)
            } label: {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.secondaryText : LifeTrackTheme.ColorPalette.primaryText)
                            .strikethrough(task.isCompleted)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        if task.hasDocument {
                            Image(systemName: "paperclip")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        }
                    }

                    HStack(spacing: 8) {
                        CategoryChipView(category: task.category)

                        StatusPillView(
                            title: task.dueDate.dayMonthString,
                            symbolName: task.isOverdue ? "exclamationmark.circle.fill" : "clock",
                            tint: task.isOverdue ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.secondaryText
                        )
                    }
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(LifeTrackTheme.ColorPalette.backgroundBottom.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }
}
