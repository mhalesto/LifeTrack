//
//  SplashScreenView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            VStack(spacing: LifeTrackTheme.Spacing.xLarge) {
                ZStack {
                    Circle()
                        .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.08), lineWidth: 22)
                        .frame(width: 178, height: 178)
                        .scaleEffect(isAnimating ? 1.08 : 0.92)
                        .opacity(isAnimating ? 1 : 0.35)

                    Circle()
                        .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.12), lineWidth: 1)
                        .frame(width: 218, height: 218)
                        .scaleEffect(isAnimating ? 1.04 : 0.96)
                        .opacity(isAnimating ? 0.78 : 0.38)

                    LifeTrackLogoView(size: 112)
                        .scaleEffect(isAnimating ? 1 : 0.88)
                }
                .animation(.spring(response: 0.75, dampingFraction: 0.78), value: isAnimating)

                VStack(spacing: 9) {
                    Text("LifeTrack")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    Text("Tasks, reminders, and documents in flow.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 14)
                .animation(.easeOut(duration: 0.6).delay(0.15), value: isAnimating)

                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(LifeTrackTheme.ColorPalette.accent.opacity(index == 1 ? 0.72 : 0.28))
                            .frame(width: index == 1 ? 20 : 7, height: 7)
                    }
                }
                .opacity(isAnimating ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.32), value: isAnimating)
            }
            .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    SplashScreenView()
}
