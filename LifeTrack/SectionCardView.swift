//
//  SectionCardView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct SectionCardView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeTrackCard()
    }
}

struct SectionHeaderView: View {
    let title: String
    var subtitle: String?
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.lifeTrackHeadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }

            Spacer(minLength: LifeTrackTheme.Spacing.medium)

            if let trailing {
                Text(trailing)
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
        }
    }
}
