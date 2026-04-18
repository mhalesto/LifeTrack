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
    }
}
