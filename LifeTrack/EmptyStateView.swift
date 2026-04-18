//
//  EmptyStateView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                ZStack {
                    Circle()
                        .fill(LifeTrackTheme.ColorPalette.accentSoft)
                        .frame(width: 66, height: 66)

                    Circle()
                        .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.16), lineWidth: 10)
                        .frame(width: 86, height: 86)

                    Image(systemName: "checklist.checked")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(.lifeTrackTitle)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LifeTrackPrimaryButton(title: actionTitle, systemImage: "plus", action: action)
            }
        }
    }
}
