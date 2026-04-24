//
//  SplashScreenView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct SplashScreenView: View {
    private let playsIntroAnimation: Bool

    @State private var isPresented: Bool
    @State private var titleOffset: CGFloat
    @State private var subtitleOffset: CGFloat
    @State private var captionOpacity: Double
    @State private var titleShimmerPhase: CGFloat = -0.4
    @State private var activeDotIndex: Int = 1

    init(playsIntroAnimation: Bool = true) {
        self.playsIntroAnimation = playsIntroAnimation
        _isPresented = State(initialValue: !playsIntroAnimation)
        _titleOffset = State(initialValue: playsIntroAnimation ? 22 : 0)
        _subtitleOffset = State(initialValue: playsIntroAnimation ? 14 : 0)
        _captionOpacity = State(initialValue: playsIntroAnimation ? 0 : 1)
    }

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            VStack(spacing: LifeTrackTheme.Spacing.xLarge) {
                ZStack {
                    Circle()
                        .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.08), lineWidth: 22)
                        .frame(width: 178, height: 178)
                        .opacity(isPresented ? 0.82 : 0.28)

                    Circle()
                        .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.12), lineWidth: 1)
                        .frame(width: 218, height: 218)
                        .opacity(isPresented ? 0.6 : 0.18)

                    LifeTrackLogoView(size: 112)
                        .scaleEffect(isPresented ? 1 : 0.9)
                        .opacity(isPresented ? 1 : 0.86)
                }

                VStack(spacing: 9) {
                    Text("LifeTrack")
                        .font(.lifeTrack(size: 42, role: .title, weight: .bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .overlay(shimmerHighlight.mask(titleMask))
                        .offset(y: titleOffset)
                        .opacity(captionOpacity)

                    Text("Tasks, reminders, and documents in flow.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .multilineTextAlignment(.center)
                        .offset(y: subtitleOffset)
                        .opacity(captionOpacity * 0.95)
                }

                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(LifeTrackTheme.ColorPalette.accent.opacity(activeDotIndex == index ? 0.72 : 0.28))
                            .frame(width: activeDotIndex == index ? 22 : 7, height: 7)
                            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: activeDotIndex)
                    }
                }
                .opacity(captionOpacity)
            }
            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        }
        .task {
            guard playsIntroAnimation else { return }

            await Task.yield()

            withAnimation(.easeOut(duration: 0.22)) {
                isPresented = true
            }

            withAnimation(.spring(response: 0.52, dampingFraction: 0.82).delay(0.04)) {
                titleOffset = 0
                captionOpacity = 1
            }

            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.12)) {
                subtitleOffset = 0
            }

            withAnimation(.linear(duration: 0.9).delay(0.18)) {
                titleShimmerPhase = 1.4
            }

            for step in 0..<3 {
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    activeDotIndex = (step + 2) % 3
                }
            }
        }
    }

    private var shimmerHighlight: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    LifeTrackTheme.ColorPalette.accent.opacity(0.55),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width * 0.6)
            .offset(x: proxy.size.width * titleShimmerPhase)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    private var titleMask: some View {
        Text("LifeTrack")
            .font(.lifeTrack(size: 42, role: .title, weight: .bold))
    }
}

#Preview {
    SplashScreenView()
}
