//
//  BetaDashboardQuickActions.swift
//  LifeTrack
//
//  Quick Actions section extracted from BetaDashboardView. The parent owns
//  the @AppStorage visibility toggles plus the subscription / sheet /
//  navigation callbacks that produce a [BetaQuickAction] array, and this
//  view just renders the result.
//

import SwiftUI

struct BetaDashboardQuickActionsSection: View {
    let items: [BetaQuickAction]
    let onCustomize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Quick Actions")
                    .font(.betaSection)
                    .foregroundStyle(BetaPalette.primaryText)
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BetaPalette.accentDeep)

                Spacer(minLength: 0)

                Button(action: onCustomize) {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("Customize")
                            .font(.betaCaption(12, weight: .semibold))
                    }
                    .foregroundStyle(BetaPalette.lightChromeText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(BetaPalette.lightCardFill)
                            .shadow(color: BetaPalette.lightCardShadow, radius: 4, y: 2)
                    )
                    .overlay {
                        Capsule().stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
            }

            layout
        }
    }

    @ViewBuilder
    private var layout: some View {
        if items.count > 4 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        BetaQuickActionTile(item: item)
                            .frame(width: 128)
                    }
                }
                .padding(.vertical, 2)
            }
        } else {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    BetaQuickActionTile(item: item)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct BetaQuickActionTile: View {
    let item: BetaQuickAction

    var body: some View {
        Button(action: item.action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Circle()
                        .fill(item.iconBg)
                        .frame(width: 30, height: 30)
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(item.iconTint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.betaBody(13, weight: .bold))
                        .foregroundStyle(BetaPalette.lightCardPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.subtitle)
                        .font(.betaCaption(11, weight: .medium))
                        .foregroundStyle(BetaPalette.lightCardSecondaryText)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BetaPalette.lightCardFill)
                    .shadow(color: BetaPalette.lightCardShadow, radius: 8, y: 3)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
            }
            .overlay(alignment: .topTrailing) {
                if item.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(BetaPalette.accentDeep, in: Circle())
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
