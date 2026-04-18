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

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: Circle())

                Spacer()

                Text(value.formatted())
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeTrackCard(padding: LifeTrackTheme.Spacing.medium, backgroundColor: LifeTrackTheme.ColorPalette.cardElevated)
    }
}
