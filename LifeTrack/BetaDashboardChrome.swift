//
//  BetaDashboardChrome.swift
//  LifeTrack
//
//  Top-of-dashboard ornaments extracted from BetaDashboardView: the animated
//  background shapes, the LifeTrack brand mark, the brand block + greeting
//  alert banner, and the inbox preview row.
//

import SwiftUI

// MARK: - Animated background shapes

/// Floating water-like circles drifting behind the beta dashboard.
/// Uses plain `Circle` views driven by a single looping animation so
/// Core Animation handles the motion off the main thread — much cheaper
/// than a `TimelineView` + `Canvas` redraw every frame.
struct BetaAnimatedShapesBackground: View {
    var opacity: Double

    @State private var animate = false

    var body: some View {
        ZStack {
            BetaPalette.appBackground

            if opacity > 0.01 {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height

                    ZStack {
                        shape(color: BetaPalette.heroTop, size: 360)
                            .offset(
                                x: animate ? w * 0.10 : -w * 0.05,
                                y: animate ? h * 0.20 : h * 0.05
                            )

                        shape(color: BetaPalette.peach.opacity(0.55), size: 280)
                            .offset(
                                x: animate ? w * 0.72 : w * 0.88,
                                y: animate ? h * 0.18 : h * 0.32
                            )

                        shape(color: BetaPalette.peachDeep.opacity(0.5), size: 300)
                            .offset(
                                x: animate ? w * 0.65 : w * 0.80,
                                y: animate ? h * 0.82 : h * 0.70
                            )

                        shape(color: BetaPalette.heroMid, size: 240)
                            .offset(
                                x: animate ? w * 0.15 : w * 0.05,
                                y: animate ? h * 0.70 : h * 0.85
                            )
                    }
                    .frame(width: w, height: h)
                    .blur(radius: 55)
                    .opacity(opacity)
                }
                .allowsHitTesting(false)
                .onAppear {
                    guard !animate else { return }
                    withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                }
            }
        }
    }

    private func shape(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Logo mark

struct BetaLogoMark: View {
    var body: some View {
        ZStack {
            // Back leaf — pink/peach, smaller, peeks from bottom-right
            BetaLeafShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFFC5B5), Color(hex: 0xF88AA8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22, height: 26)
                .rotationEffect(.degrees(35))
                .offset(x: 10, y: 7)
                .shadow(color: Color(hex: 0xE06988).opacity(0.25), radius: 3, y: 1)

            // Front leaf — purple, main body
            BetaLeafShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xA78BFA),
                            Color(hex: 0x7C6BEE),
                            Color(hex: 0x4F3FCB)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Inner highlight vein
                    BetaLeafShape()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                        .blur(radius: 0.4)
                )
                .frame(width: 30, height: 36)
                .rotationEffect(.degrees(-18))
                .offset(x: -2, y: -1)
                .shadow(color: BetaPalette.accentDeep.opacity(0.35), radius: 5, y: 2)
        }
        .frame(width: 42, height: 42)
    }
}

// MARK: - Brand block

struct BetaBrandBlock: View {
    var body: some View {
        HStack(spacing: 8) {
            BetaLogoMark()
            Text("LifeTrack")
                .font(.betaBrand)
                .foregroundStyle(BetaPalette.primaryText)
        }
    }
}

// MARK: - Alert banner

struct BetaAlertBanner: View {
    @Binding var isVisible: Bool
    let onAIInsightsTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BetaPalette.alertIconBg)
                    .frame(width: 30, height: 30)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BetaPalette.alertIcon)
            }

            Text("You can still make this dashboard useful today.")
                .font(.betaCaption(13, weight: .medium))
                .foregroundStyle(BetaPalette.alertText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Button {
                onAIInsightsTap()
            } label: {
                Label("AI", systemImage: "brain.head.profile")
                    .font(.betaCaption(11, weight: .bold))
                    .foregroundStyle(BetaPalette.alertText)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(BetaPalette.heroGlassFill, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open AI money insights")

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BetaPalette.alertText.opacity(0.75))
                    .frame(width: 24, height: 24)
                    .background(BetaPalette.heroGlassFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss dashboard alert")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            BetaPalette.alertBg,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

// MARK: - Inbox preview row

struct BetaInboxPreviewRow: View {
    let item: InboxItem

    private var draft: CapturedTaskDraft {
        item.captureDraft
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.source.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(sourceTint)
                .frame(width: 34, height: 34)
                .background(sourceTint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.previewTitle)
                    .font(.lifeTrack(.subheadline, weight: .semibold))
                    .foregroundStyle(BetaPalette.lightCardPrimaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(draft.resolvedDueDate.dayMonthString)
                    Text("•")
                    Text(item.source.title)
                }
                .font(.lifeTrack(.caption, weight: .medium))
                .foregroundStyle(BetaPalette.lightCardSecondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(BetaPalette.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(BetaPalette.lightCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BetaPalette.lightCardBorder, lineWidth: 0.8)
        }
    }

    private var sourceTint: Color {
        switch item.source {
        case .typed:
            BetaPalette.qaAccentTint
        case .voice:
            BetaPalette.qaPlanTint
        case .shared:
            BetaPalette.qaSuccessTint
        }
    }
}
