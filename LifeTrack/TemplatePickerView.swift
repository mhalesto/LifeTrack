//
//  TemplatePickerView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct TemplatePickerView: View {
    let onSelectBlank: () -> Void
    let onSelectTemplate: (TaskTemplate) -> Void

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                Capsule()
                    .fill(LifeTrackTheme.ColorPalette.hairline)
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick Add")
                        .font(.lifeTrackTitle)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Start clean or use a smart shortcut.")
                        .font(.subheadline)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Button(action: onSelectBlank) {
                    TemplatePickerRow(
                        symbolName: "square.and.pencil",
                        title: "Blank task",
                        subtitle: "Create a custom task from scratch.",
                        tint: LifeTrackTheme.ColorPalette.accent
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                    Text("Templates")
                        .font(.lifeTrackCaption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .textCase(.uppercase)

                    VStack(spacing: LifeTrackTheme.Spacing.small) {
                        ForEach(TaskTemplate.common) { template in
                            Button {
                                onSelectTemplate(template)
                            } label: {
                                TemplatePickerRow(
                                    symbolName: template.symbolName,
                                    title: template.title,
                                    subtitle: template.subtitle,
                                    tint: template.category.style.tint
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
            .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

private struct TemplatePickerRow: View {
    let symbolName: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
        }
        .padding(14)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
        .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(0.75), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    TemplatePickerView(
        onSelectBlank: {},
        onSelectTemplate: { _ in }
    )
}
