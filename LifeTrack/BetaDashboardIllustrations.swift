//
//  BetaDashboardIllustrations.swift
//  LifeTrack
//
//  Decorative illustration views extracted from BetaDashboardView.
//

import SwiftUI

// MARK: - Streak Hero Illustration

struct StreakHeroIllustration: View {
    private struct SparkleDot: Identifiable {
        let id = UUID()
        let offsetX: CGFloat
        let offsetY: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    private let sparkles: [SparkleDot] = [
        .init(offsetX: -58, offsetY: -55, size: 12, opacity: 0.9),
        .init(offsetX: 52, offsetY: -70, size: 10, opacity: 0.8),
        .init(offsetX: 78, offsetY: -10, size: 8, opacity: 0.95),
        .init(offsetX: -40, offsetY: -80, size: 6, opacity: 0.6),
        .init(offsetX: 28, offsetY: -96, size: 6, opacity: 0.55),
        .init(offsetX: -78, offsetY: 10, size: 7, opacity: 0.7),
        .init(offsetX: 92, offsetY: -50, size: 6, opacity: 0.6),
        .init(offsetX: -20, offsetY: -38, size: 5, opacity: 0.55),
        .init(offsetX: 64, offsetY: 22, size: 5, opacity: 0.5)
    ]

    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xFFB07A).opacity(0.45),
                            Color(hex: 0xFFD2A8).opacity(0.22),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 130
                    )
                )
                .frame(width: 240, height: 210)
                .offset(y: -10)

            Group {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0x9986CC), Color(hex: 0x5E4E8F)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(32))
                    .offset(x: 86, y: -6)
                    .shadow(color: Color(hex: 0x4A3D78).opacity(0.3), radius: 3, y: 2)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0xB5A2DE), Color(hex: 0x7464A8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(-12))
                    .offset(x: 100, y: 28)
                    .opacity(0.9)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xC8B7E5))
                    .rotationEffect(.degrees(50))
                    .offset(x: 74, y: -30)
                    .opacity(0.75)
            }

            ForEach(sparkles) { dot in
                Image(systemName: "sparkle")
                    .font(.system(size: dot.size, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xFFE8C8).opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(dot.opacity)
                    .offset(x: dot.offsetX, y: dot.offsetY)
                    .shadow(color: Color(hex: 0xFFCFA0).opacity(0.7), radius: 3)
            }

            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: 196, height: 20)
                    .blur(radius: 10)
                    .offset(y: 94)

                PedestalShape()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: 0x8A7AB4), location: 0.0),
                                .init(color: Color(hex: 0x6B5C96), location: 0.4),
                                .init(color: Color(hex: 0x3F3368), location: 0.9),
                                .init(color: Color(hex: 0x2A2050), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 200, height: 100)
                    .offset(y: 54)
                    .shadow(color: Color.black.opacity(0.18), radius: 6, y: 4)

                PedestalShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: 0xFFC99A).opacity(0.55),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.5, y: 0.1),
                            startRadius: 4,
                            endRadius: 90
                        )
                    )
                    .frame(width: 200, height: 100)
                    .offset(y: 54)
                    .blendMode(.plusLighter)

                PedestalShape()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: 0xDFCEF1), location: 0.0),
                                .init(color: Color(hex: 0xAF9ED6), location: 0.55),
                                .init(color: Color(hex: 0x7A68AD), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 176, height: 62)
                    .offset(y: 38)

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.75),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 150, height: 18)
                    .offset(y: 30)
                    .blur(radius: 0.5)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0xB19ED8), Color(hex: 0x6B5CA0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(-38))
                    .offset(x: -86, y: 52)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0xD3C2E8), Color(hex: 0x8A79BE)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(22))
                    .offset(x: -72, y: 66)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xE9B4C4))
                    .rotationEffect(.degrees(18))
                    .offset(x: 74, y: 44)
                    .opacity(0.88)
            }

            Circle()
                .stroke(Color(hex: 0xFF8A4C).opacity(0.28), lineWidth: 28)
                .frame(width: 128, height: 128)
                .blur(radius: 10)

            Circle()
                .stroke(
                    AngularGradient(
                        stops: [
                            .init(color: Color(hex: 0x6B5CE0), location: 0.0),
                            .init(color: Color(hex: 0x9884F2), location: 0.10),
                            .init(color: Color(hex: 0xCBBDFF), location: 0.25),
                            .init(color: Color(hex: 0xFFE3CE), location: 0.42),
                            .init(color: Color(hex: 0xFFB071), location: 0.55),
                            .init(color: Color(hex: 0xFF7A3E), location: 0.68),
                            .init(color: Color(hex: 0xFFB47A), location: 0.82),
                            .init(color: Color(hex: 0x8B5CF6), location: 1.0)
                        ],
                        center: .center,
                        startAngle: .degrees(-110),
                        endAngle: .degrees(250)
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 128, height: 128)
                .shadow(color: Color(hex: 0xFF8A4C).opacity(0.35), radius: 10, x: 0, y: 4)

            Circle()
                .trim(from: 0.60, to: 0.88)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 128, height: 128)

            Circle()
                .stroke(Color(hex: 0x3A2D6E).opacity(0.25), lineWidth: 1.4)
                .frame(width: 112, height: 112)

            Circle()
                .fill(Color(hex: 0xFFA64C).opacity(0.55))
                .frame(width: 72, height: 72)
                .blur(radius: 14)

            Circle()
                .fill(Color(hex: 0xFFD98A).opacity(0.5))
                .frame(width: 46, height: 46)
                .blur(radius: 8)

            FlameShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0xFFDA7A), location: 0.0),
                            .init(color: Color(hex: 0xFFA84B), location: 0.45),
                            .init(color: Color(hex: 0xFF5E1C), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 42, height: 62)
                .shadow(color: Color(hex: 0xFF5E1C).opacity(0.6), radius: 8, y: 2)

            FlameShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white, location: 0.0),
                            .init(color: Color(hex: 0xFFF0C4), location: 0.35),
                            .init(color: Color(hex: 0xFFB261).opacity(0.8), location: 0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 22, height: 38)
                .offset(y: 6)
                .blendMode(.plusLighter)
        }
        .frame(width: 220, height: 220)
    }
}

// MARK: - Daily Focus Backdrop

struct DailyFocusBackdrop: View {
    var body: some View {
        ZStack {
            if LifeTrackAppTheme.isDarkModeEnabled {
                LinearGradient(
                    colors: [
                        Color(hex: 0x1A2027),
                        Color(hex: 0x1B2230),
                        Color(hex: 0x171C27)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(hex: 0xF1E7DC),
                        Color(hex: 0xEEDCE4),
                        Color(hex: 0xE8D8EA)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            MountainShape(peaks: [
                (0.0, 0.68), (0.2, 0.45), (0.42, 0.58), (0.65, 0.36), (0.85, 0.52), (1.0, 0.48)
            ])
            .fill(
                LinearGradient(
                    colors: LifeTrackAppTheme.isDarkModeEnabled
                        ? [Color(hex: 0x22313B).opacity(0.95), Color(hex: 0x27354A).opacity(0.55)]
                        : [Color(hex: 0xC9B5D9).opacity(0.65), Color(hex: 0xB39CCE).opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .offset(y: 8)

            MountainShape(peaks: [
                (0.0, 0.85), (0.18, 0.62), (0.38, 0.76), (0.6, 0.55), (0.82, 0.72), (1.0, 0.6)
            ])
            .fill(
                LinearGradient(
                    colors: LifeTrackAppTheme.isDarkModeEnabled
                        ? [Color(hex: 0x30444C).opacity(0.72), Color(hex: 0x253041).opacity(0.42)]
                        : [Color(hex: 0xE9B7A2).opacity(0.55), Color(hex: 0xE9A4AB).opacity(0.35)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .offset(y: 32)

            LinearGradient(
                colors: LifeTrackAppTheme.isDarkModeEnabled
                    ? [Color.clear, Color(hex: 0x172631).opacity(0.42), Color(hex: 0x141A27).opacity(0.28)]
                    : [Color.clear, Color(hex: 0xF0D9C4).opacity(0.45), Color(hex: 0xEEC9D5).opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
