//
//  CategoryChipView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct CategoryChipView: View {
    let category: TaskCategory
    var isSelected = false

    var body: some View {
        Label(category.title, systemImage: category.symbolName)
            .font(.lifeTrackCaption)
            .foregroundStyle(isSelected ? .white : category.style.tint)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? category.style.tint : category.style.background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? category.style.tint.opacity(0.2) : category.style.border, lineWidth: 0.8)
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
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10), in: Capsule())
    }
}
