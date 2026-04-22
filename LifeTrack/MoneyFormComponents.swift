//
//  MoneyFormComponents.swift
//  LifeTrack
//
//  Created by Codex on 2026/04/23.
//

import SwiftUI

struct MoneyOptionPill: View {
    let title: String
    let symbolName: String
    let tint: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(isSelected ? Color.white : tint)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(optionBackground, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.22) : tint.opacity(0.25), lineWidth: 0.8)
        }
    }

    private var optionBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(tint)
        }
        return AnyShapeStyle(tint.opacity(0.10))
    }
}

struct MoneyCurrencyPicker: View {
    @Binding var currencyCode: String

    var body: some View {
        Menu {
            Picker("Currency", selection: $currencyCode) {
                ForEach(MoneyCurrency.supportedCodes, id: \.self) { code in
                    Text(MoneyCurrency.displayName(for: code))
                        .tag(code)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "coloncurrencysign.circle")
                    .font(.system(size: 13, weight: .semibold))
                Text(MoneyCurrency.normalized(currencyCode))
                    .font(.footnote.weight(.bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(LifeTrackTheme.ColorPalette.accentSoft, in: Capsule())
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96))
        .onAppear {
            currencyCode = MoneyCurrency.normalized(currencyCode)
        }
        .onChange(of: currencyCode) { _, newValue in
            currencyCode = MoneyCurrency.normalized(newValue)
        }
    }
}

struct MoneyAmountField: View {
    let title: String
    @Binding var amountText: String
    @Binding var currencyCode: String
    var placeholder: String = "0"

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            HStack(spacing: 10) {
                MoneyCurrencyPicker(currencyCode: $currencyCode)

                TextField(placeholder, text: $amountText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                LifeTrackTheme.ColorPalette.backgroundTop,
                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
            }
        }
    }
}

struct MoneyValueRow: View {
    let title: String
    let value: String
    let symbolName: String
    var tint: Color = LifeTrackTheme.ColorPalette.accent
    var subtitle: String?

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(11)
        .background(
            LifeTrackTheme.ColorPalette.cardElevated.opacity(0.76),
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
        )
    }
}

struct MoneyEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LifeTrackTheme.Spacing.large)
    }
}
