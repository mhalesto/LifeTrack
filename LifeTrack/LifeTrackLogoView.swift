//
//  LifeTrackLogoView.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import SwiftUI

struct LifeTrackLogoView: View {
    var size: CGFloat = 88
    var showsShadow = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            LifeTrackTheme.ColorPalette.cardElevated,
                            LifeTrackTheme.ColorPalette.accentSoft
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: max(size * 0.018, 1))

            Circle()
                .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.20), lineWidth: size * 0.08)
                .frame(width: size * 0.58, height: size * 0.58)

            Circle()
                .trim(from: 0.04, to: 0.77)
                .stroke(
                    LifeTrackTheme.ColorPalette.accentGradient,
                    style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round)
                )
                .rotationEffect(.degrees(-92))
                .frame(width: size * 0.58, height: size * 0.58)

            CheckmarkShape()
                .stroke(
                    LifeTrackTheme.ColorPalette.primaryText,
                    style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size * 0.30, height: size * 0.21)
                .offset(x: size * 0.015, y: size * 0.01)

            Circle()
                .fill(LifeTrackTheme.ColorPalette.success)
                .frame(width: size * 0.13, height: size * 0.13)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: size * 0.025)
                }
                .offset(x: size * 0.31, y: -size * 0.31)
        }
        .frame(width: size, height: size)
        .shadow(color: showsShadow ? LifeTrackTheme.ColorPalette.accent.opacity(0.20) : .clear, radius: size * 0.18, x: 0, y: size * 0.12)
        .shadow(color: showsShadow ? Color.black.opacity(0.10) : .clear, radius: size * 0.07, x: 0, y: size * 0.035)
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#Preview {
    ZStack {
        LifeTrackTheme.appBackground
            .ignoresSafeArea()
        LifeTrackLogoView(size: 120)
    }
}
