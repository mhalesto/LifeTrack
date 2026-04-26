//
//  CategoryChipView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct CategoryChipView: View {
    let option: TaskCategoryOption
    var isSelected = false

    init(category: TaskCategory, isSelected: Bool = false) {
        self.option = .builtIn(category)
        self.isSelected = isSelected
    }

    init(option: TaskCategoryOption, isSelected: Bool = false) {
        self.option = option
        self.isSelected = isSelected
    }

    var body: some View {
        Label(option.title, systemImage: option.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : option.tint)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? option.tint : option.background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? option.tint.opacity(0.2) : option.border, lineWidth: 0.8)
            }
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct StatusPillView: View {
    let title: String
    let symbolName: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: symbolName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10), in: Capsule())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct PriorityPillView: View {
    let priority: TaskPriority
    var isSelected = false

    var body: some View {
        Label(priority.title, systemImage: priority.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : priority.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? priority.tint : priority.tint.opacity(0.11), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(priority.tint.opacity(isSelected ? 0.18 : 0.24), lineWidth: 0.8)
            }
    }
}

struct RecurrencePillView: View {
    let recurrence: TaskRecurrence
    var isSelected = false

    var body: some View {
        Label(recurrence.shortTitle, systemImage: recurrence.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : recurrence.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? recurrence.tint : recurrence.tint.opacity(0.11), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(recurrence.tint.opacity(isSelected ? 0.18 : 0.24), lineWidth: 0.8)
            }
    }
}

extension TaskPriority {
    var tint: Color {
        switch self {
        case .low:
            LifeTrackTheme.ColorPalette.secondaryText
        case .normal:
            LifeTrackTheme.ColorPalette.accent
        case .high:
            LifeTrackTheme.ColorPalette.warning
        }
    }
}

extension TaskRecurrence {
    var tint: Color {
        switch self {
        case .none:
            LifeTrackTheme.ColorPalette.secondaryText
        case .daily:
            LifeTrackTheme.ColorPalette.accent
        case .weekly:
            LifeTrackTheme.ColorPalette.secondaryAccent
        case .biweekly:
            LifeTrackTheme.ColorPalette.secondaryAccent
        case .monthly:
            LifeTrackTheme.ColorPalette.success
        case .yearly:
            LifeTrackTheme.ColorPalette.warning
        }
    }
}
