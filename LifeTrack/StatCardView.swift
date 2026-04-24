//
//  StatCardView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct StatCardView: View {
    let title: String
    let value: Int
    let subtitle: String
    let symbolName: String
    let tint: Color
    var showsDisclosure = false
    var minHeight: CGFloat = 82
    var iconSize: CGFloat = LifeTrackTheme.IconSize.smallCircle
    var valueFontSize: CGFloat = 27
    var cardPadding: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small) {
            HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: iconSize, height: iconSize)
                    .background(tint.opacity(0.12), in: Circle())

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value.formatted())
                        .font(.lifeTrack(size: valueFontSize, role: .title, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    if showsDisclosure {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText.opacity(0.58))
                            .offset(y: -1)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .lifeTrackCard(padding: cardPadding, backgroundColor: LifeTrackTheme.ColorPalette.cardElevated)
    }
}
