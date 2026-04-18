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
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.small + 2) {
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
    var infoMessage: String?

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.lifeTrackHeadline)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    if let infoMessage {
                        InfoTipButton(message: infoMessage)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
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

private struct InfoTipButton: View {
    let message: String

    @State private var isShowingInfo = false
    @AppStorage(LifeTrackSettings.Keys.animationsEnabled) private var animationsEnabled = true

    var body: some View {
        Button {
            toggleInfo()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.88, pressedOpacity: 0.86))
        .accessibilityLabel("More information")
        .accessibilityHint(message)
        .overlay(alignment: .bottom) {
            if isShowingInfo {
                InfoTooltipView(message: message) {
                    hideInfo()
                }
                .offset(x: -10, y: -30)
                .transition(.opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98)))
                .zIndex(20)
            }
        }
        .zIndex(isShowingInfo ? 20 : 0)
    }

    private func toggleInfo() {
        guard animationsEnabled else {
            isShowingInfo.toggle()
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            isShowingInfo.toggle()
        }
    }

    private func hideInfo() {
        guard animationsEnabled else {
            isShowingInfo = false
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            isShowingInfo = false
        }
    }
}

private struct InfoTooltipView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(message)
                .font(.footnote.weight(.medium))
                .lineSpacing(2)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(width: 252, alignment: .leading)
                .background(
                    tooltipBackground,
                    in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.26), lineWidth: 0.9)
                }
                .shadow(color: LifeTrackTheme.ColorPalette.accent.opacity(0.14), radius: 14, x: 0, y: 9)
                .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(0.8), radius: 8, x: 0, y: 4)

            TooltipTail()
                .fill(tooltipBackground)
                .frame(width: 16, height: 8)
                .overlay {
                    TooltipTail()
                        .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.26), lineWidth: 0.8)
                }
                .offset(x: 10, y: -1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
    }

    private var tooltipBackground: Color {
        LifeTrackTheme.ColorPalette.accentSoft
            .mixed(with: LifeTrackTheme.ColorPalette.cardElevated, amount: 0.38)
    }
}

private struct TooltipTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
