//
//  CategoryManagerView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftData
import SwiftUI

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    let onSelect: (TaskCategoryOption) -> Void

    @State private var title = ""
    @State private var selectedSymbol = "tag"
    @State private var selectedColorHex = 0x3159D9

    private let symbols = [
        "tag", "star", "book", "graduationcap", "cart", "car", "airplane",
        "fork.knife", "paintpalette", "hammer", "building.2", "figure.run"
    ]

    private let colors = [
        0x3159D9, 0x6A5AE0, 0x2F7E66, 0xD08B2E,
        0xC94A4A, 0xB54A73, 0x009A84, 0xE5482E
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        header
                        createCard
                        existingCard
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Custom Categories")
                .font(.lifeTrackTitle)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Create labels that match the way you organize your life.")
                .font(.footnote)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var createCard: some View {
        SectionCardView {
            SectionHeaderView(title: "New Category", subtitle: "Name, icon, and color.")

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                ZStack(alignment: .leading) {
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("e.g. Learning")
                            .font(.body.weight(.medium))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.placeholderText)
                            .padding(.horizontal, 14)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .textInputAutocapitalization(.words)
                        .padding(14)
                }
                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 42), spacing: 8)], spacing: 8) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selectedSymbol == symbol ? .white : selectedColor)
                                .frame(width: 42, height: 42)
                                .background(selectedSymbol == symbol ? selectedColor : selectedColor.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 8)], spacing: 8) {
                    ForEach(colors, id: \.self) { colorHex in
                        Button {
                            selectedColorHex = colorHex
                        } label: {
                            Circle()
                                .fill(Color(hex: UInt(colorHex)))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Circle()
                                        .stroke(selectedColorHex == colorHex ? LifeTrackTheme.ColorPalette.primaryText : Color.white.opacity(0.85), lineWidth: selectedColorHex == colorHex ? 2 : 1)
                                }
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92))
                    }
                }
            }

            LifeTrackPrimaryButton(
                title: "Create Category",
                systemImage: "plus",
                isDisabled: cleanedTitle.isEmpty,
                action: createCategory
            )
        }
    }

    private var existingCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Your Categories",
                subtitle: customCategories.isEmpty ? "Created categories will appear here." : "Tap one to use it."
            )

            if customCategories.isEmpty {
                CompactCategoryMessage()
            } else {
                VStack(spacing: LifeTrackTheme.Spacing.small) {
                    ForEach(customCategories) { category in
                        let option = TaskCategoryOption.custom(category)
                        Button {
                            onSelect(option)
                            dismiss()
                        } label: {
                            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                                CategoryChipView(option: option)

                                Spacer()

                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(option.tint)
                            }
                            .padding(12)
                            .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.82), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
                    }
                }
            }
        }
    }

    private var selectedColor: Color {
        Color(hex: UInt(selectedColorHex))
    }

    private var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createCategory() {
        guard !cleanedTitle.isEmpty else {
            return
        }

        let category = CustomTaskCategory(
            title: cleanedTitle,
            symbolName: selectedSymbol,
            colorHex: selectedColorHex
        )
        modelContext.insert(category)
        try? modelContext.save()

        onSelect(.custom(category))
        dismiss()
    }
}

private struct CompactCategoryMessage: View {
    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "tag")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

            Text("Add a category for anything that does not fit Health, Finance, Work, Home, or Personal.")
                .font(.footnote)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
