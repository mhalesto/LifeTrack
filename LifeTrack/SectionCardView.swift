//
//  SectionCardView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI
import UIKit

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
                        .font(.lifeTrackFootnote)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: LifeTrackTheme.Spacing.medium)

            if let trailing {
                Text(trailing)
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
        }
    }
}

struct InfoTipButton: View {
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
        .overlay(alignment: .topLeading) {
            if isShowingInfo {
                AdaptiveInfoTooltipView(message: message) {
                    hideInfo()
                }
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

private struct AdaptiveInfoTooltipView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let buttonFrame = proxy.frame(in: .global)
            let screenSize = currentScreenSize
            let width = min(286, max(220, screenSize.width - 32))
            let height = estimatedTooltipHeight(for: message, width: width)
            let preferredLeading = buttonFrame.midX - (width * 0.36)
            let clampedLeading = min(max(preferredLeading, 16), screenSize.width - width - 16)
            let tailX = min(max(buttonFrame.midX - clampedLeading, 18), width - 18)
            let placement: InfoTooltipPlacement = .above
            let preferredVerticalOffset = -(height + 8)
            let topSafeInset: CGFloat = 12
            let verticalOffset = max(preferredVerticalOffset, topSafeInset - buttonFrame.minY)

            InfoTooltipView(
                message: message,
                width: width,
                tailX: tailX,
                placement: placement,
                onDismiss: onDismiss
            )
            .offset(x: clampedLeading - buttonFrame.minX, y: verticalOffset)
        }
        .frame(width: 22, height: 22)
    }

    private var currentScreenSize: CGSize {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.size }
            .first ?? CGSize(width: 393, height: 852)
    }

    private func estimatedTooltipHeight(for message: String, width: CGFloat) -> CGFloat {
        let fontSize = UIFont.preferredFont(forTextStyle: .footnote).pointSize
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let textBounds = NSString(string: message).boundingRect(
            with: CGSize(width: width - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )

        return ceil(textBounds.height) + 20 + 8
    }
}

private enum InfoTooltipPlacement {
    case above
    case below
}

private struct InfoTooltipView: View {
    let message: String
    let width: CGFloat
    let tailX: CGFloat
    let placement: InfoTooltipPlacement
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if placement == .below {
                tooltipTail(rotation: .degrees(180), verticalOffset: 1)
            }

            tooltipBubble

            if placement == .above {
                tooltipTail(rotation: .zero, verticalOffset: -1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
    }

    private var tooltipBubble: some View {
        Text(message)
            .font(.lifeTrack(.footnote, weight: .medium))
            .lineSpacing(2)
            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: width, alignment: .leading)
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
    }

    private func tooltipTail(rotation: Angle, verticalOffset: CGFloat) -> some View {
        TooltipTail()
            .fill(tooltipBackground)
            .frame(width: 16, height: 8)
            .rotationEffect(rotation)
            .overlay {
                TooltipTail()
                    .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.26), lineWidth: 0.8)
                    .rotationEffect(rotation)
            }
            .offset(x: tailX - (width / 2), y: verticalOffset)
    }

    private var tooltipBackground: Color {
        LifeTrackTheme.ColorPalette.accentSoft
            .mixed(with: LifeTrackTheme.ColorPalette.accent, amount: 0.13)
            .mixed(with: LifeTrackTheme.ColorPalette.cardElevated, amount: 0.10)
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
