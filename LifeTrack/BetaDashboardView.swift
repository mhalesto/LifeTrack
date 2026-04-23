//
//  BetaDashboardView.swift
//  LifeTrack
//

import Combine
import SwiftData
import SwiftUI

// MARK: - Animated background

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

// MARK: - Palette

/// Beta dashboard palette. Keeps the warm purple/pink/peach pastel
/// aesthetic as the default look, but routes accent/status tints and
/// text tones through `LifeTrackAppTheme.current` so it reacts to
/// theme and color-strength changes just like the default dashboard.
private enum BetaPalette {
    // Background washes (beta aesthetic — stay constant)
    static let bgTop = Color(hex: 0xF8F2FB)
    static let bgMid = Color(hex: 0xF7ECF1)
    static let bgBottom = Color(hex: 0xFBF2E9)

    // Hero streak card (beta aesthetic — stay constant)
    static let heroTop = Color(hex: 0xE8DEF6)
    static let heroMid = Color(hex: 0xF0DEEA)
    static let heroBottom = Color(hex: 0xFBE5D2)

    static let faintBorder = Color.black.opacity(0.05)

    static let peach = Color(hex: 0xFFB07A)
    static let peachDeep = Color(hex: 0xFF8EAC)

    // Alert (cream/peach — beta aesthetic)
    static let alertBg = Color(hex: 0xFCE7DA)
    static let alertIconBg = Color(hex: 0xFFD2B8)
    static let alertIcon = Color(hex: 0xD97757)
    static let alertText = Color(hex: 0xB35A3F)

    // Category placeholders kept for any legacy usage
    static let catHome = Color(hex: 0xC98258)
    static let catHomeBg = Color(hex: 0xF2E4D6)
    static let catPersonal = Color(hex: 0x3B82F6)
    static let catPersonalBg = Color(hex: 0xE0ECFE)
    static let catHealth = Color(hex: 0x10B981)
    static let catHealthBg = Color(hex: 0xDCF3E8)
    static let catFallback = Color(hex: 0x8B5CF6)
    static let catFallbackBg = Color(hex: 0xEADDFB)

    // MARK: Theme-reactive tones

    private static var theme: LifeTrackAppTheme { LifeTrackAppTheme.current }

    static var primaryText: Color { theme.primaryText }
    static var secondaryText: Color { theme.secondaryText }
    static var tertiaryText: Color { theme.tertiaryText }

    static var accent: Color { theme.accent }
    static var accentDeep: Color { theme.accentDeep }
    static var accentSoft: Color { theme.accentSoft }

    static var overdue: Color { theme.danger }

    // Stat icons — tinted per category of stat, but each routed through the theme
    static var statDueToday: Color { theme.accent }
    static var statDueTodayBg: Color { theme.accentSoft }
    static var statUpcoming: Color { theme.secondaryAccent }
    static var statUpcomingBg: Color { theme.secondaryAccent.opacity(0.18) }
    static var statCompleted: Color { theme.success }
    static var statCompletedBg: Color { theme.success.opacity(0.18) }
    static var statOverdue: Color { theme.danger }
    static var statOverdueBg: Color { theme.danger.opacity(0.18) }

    // Wave strokes below each stat
    static var waveDueToday: Color { theme.accentDeep }
    static var waveUpcoming: Color { theme.secondaryAccent }
    static var waveCompleted: Color { theme.success }
    static var waveOverdue: Color { theme.danger }

    // Quick actions
    static var qaPlanTint: Color { theme.warning }
    static var qaPlanBg: Color { theme.warning.opacity(0.14) }
    static var qaHabitsTint: Color { theme.danger }
    static var qaHabitsBg: Color { theme.danger.opacity(0.14) }
    static var qaReviewTint: Color { theme.secondaryAccent }
    static var qaReviewBg: Color { theme.secondaryAccent.opacity(0.14) }
    static var qaFocusTint: Color { theme.accent }
    static var qaFocusBg: Color { theme.accentSoft }
    static var qaAccentTint: Color { theme.accent }
    static var qaAccentBg: Color { theme.accentSoft }
    static var qaSuccessTint: Color { theme.success }
    static var qaSuccessBg: Color { theme.success.opacity(0.14) }
    static var qaInfoTint: Color { theme.secondaryAccent }
    static var qaInfoBg: Color { theme.secondaryAccent.opacity(0.14) }
    static var qaWarningTint: Color { theme.warning }
    static var qaWarningBg: Color { theme.warning.opacity(0.14) }
    static var qaDangerTint: Color { theme.danger }
    static var qaDangerBg: Color { theme.danger.opacity(0.14) }

    // Gradients
    static var appBackground: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: bgTop, location: 0.0),
                .init(color: bgMid, location: 0.45),
                .init(color: bgBottom, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroBackground: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: heroTop, location: 0.0),
                .init(color: heroMid, location: 0.55),
                .init(color: heroBottom, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var fabGradient: LinearGradient {
        LinearGradient(
            colors: [accentDeep, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Serif font helpers

private extension Font {
    static let betaBrand = Font.system(size: 30, weight: .bold, design: .serif)
    static let betaGreeting = Font.system(size: 22, weight: .semibold, design: .serif)
    static let betaHeroTitle = Font.system(size: 28, weight: .bold, design: .serif)
    static let betaSection = Font.system(size: 20, weight: .bold, design: .serif)
    static let betaMetric = Font.system(size: 26, weight: .bold, design: .serif)
    static let betaStreakStat = Font.system(size: 20, weight: .bold, design: .serif)
}

// MARK: - Stat Wave shape

private struct StatSparkline: Shape {
    var values: [Double]
    var closed: Bool = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset: CGFloat = 2
        let bottomInset: CGFloat = 2
        let usableHeight = max(rect.height - topInset - bottomInset, 1)

        guard values.count >= 2 else {
            let y = rect.midY
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            if closed {
                path.addLine(to: CGPoint(x: rect.width, y: rect.height))
                path.addLine(to: CGPoint(x: 0, y: rect.height))
                path.closeSubpath()
            }
            return path
        }

        let maxV = values.max() ?? 0
        let minV = values.min() ?? 0
        let range = maxV - minV

        let stepX = rect.width / CGFloat(values.count - 1)
        var points: [CGPoint] = []
        for (i, v) in values.enumerated() {
            let x = CGFloat(i) * stepX
            let y: CGFloat
            if range < 0.0001 {
                y = rect.midY
            } else {
                let normalized = (v - minV) / range
                y = rect.maxY - bottomInset - CGFloat(normalized) * usableHeight
            }
            points.append(CGPoint(x: x, y: y))
        }

        path.move(to: points[0])
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }

        if closed {
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
        return path
    }
}

private struct BetaMetricTrends {
    var dueToday: [Double]
    var upcoming: [Double]
    var completed: [Double]
    var overdue: [Double]
}

private struct StatWave: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat
    var closed: Bool = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let steps = 60
        path.move(to: CGPoint(x: 0, y: midY))
        for i in 1...steps {
            let x = CGFloat(i) / CGFloat(steps) * rect.width
            let relative = x / rect.width
            let envelope = sin(relative * .pi) // taper ends
            let y = midY + sin(relative * .pi * 2 * frequency + phase) * amplitude * envelope
            path.addLine(to: CGPoint(x: x, y: y))
        }
        if closed {
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Streak Hero Illustration

private struct PedestalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // Rounded, slightly asymmetric stone silhouette
        path.move(to: CGPoint(x: w * 0.06, y: h * 0.52))
        path.addCurve(
            to: CGPoint(x: w * 0.34, y: h * 0.06),
            control1: CGPoint(x: w * 0.02, y: h * 0.28),
            control2: CGPoint(x: w * 0.15, y: h * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.68, y: h * 0.04),
            control1: CGPoint(x: w * 0.46, y: h * 0.00),
            control2: CGPoint(x: w * 0.56, y: h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.96, y: h * 0.46),
            control1: CGPoint(x: w * 0.86, y: h * 0.08),
            control2: CGPoint(x: w * 0.98, y: h * 0.22)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.84, y: h * 0.94),
            control1: CGPoint(x: w * 0.98, y: h * 0.76),
            control2: CGPoint(x: w * 0.96, y: h * 0.92)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.16, y: h * 0.92),
            control1: CGPoint(x: w * 0.56, y: h * 1.02),
            control2: CGPoint(x: w * 0.42, y: h * 1.00)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.06, y: h * 0.52),
            control1: CGPoint(x: w * 0.04, y: h * 0.86),
            control2: CGPoint(x: w * 0.02, y: h * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.52, y: h * 0.99))
        path.addCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.58),
            control1: CGPoint(x: w * 0.15, y: h * 0.94),
            control2: CGPoint(x: w * 0.02, y: h * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.34, y: h * 0.18),
            control1: CGPoint(x: w * 0.22, y: h * 0.36),
            control2: CGPoint(x: w * 0.18, y: h * 0.28)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.58, y: h * 0.02),
            control1: CGPoint(x: w * 0.46, y: h * 0.10),
            control2: CGPoint(x: w * 0.48, y: h * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.74, y: h * 0.40),
            control1: CGPoint(x: w * 0.66, y: h * 0.12),
            control2: CGPoint(x: w * 0.62, y: h * 0.28)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.92, y: h * 0.62),
            control1: CGPoint(x: w * 0.82, y: h * 0.46),
            control2: CGPoint(x: w * 0.94, y: h * 0.50)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.52, y: h * 0.99),
            control1: CGPoint(x: w * 0.94, y: h * 0.86),
            control2: CGPoint(x: w * 0.76, y: h * 0.98)
        )
        path.closeSubpath()
        return path
    }
}

private struct StreakHeroIllustration: View {
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
            // Warm ambient glow behind everything
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

            // Back decorative ferns (right)
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

            // Sparkles layer (behind ring)
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

            // Rocky pedestal — 3D layered stone
            ZStack {
                // Soft ground shadow
                Ellipse()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: 196, height: 20)
                    .blur(radius: 10)
                    .offset(y: 94)

                // Darker back/base of rock
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

                // Inner rim lighting (warm from the flame)
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

                // Upper facet — brighter top of the stone
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

                // Specular top highlight (glossy arc)
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

                // Side fern (left, in front of rock)
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

                // Tiny pink bud on right
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xE9B4C4))
                    .rotationEffect(.degrees(18))
                    .offset(x: 74, y: 44)
                    .opacity(0.88)
            }

            // Streak ring — outer warm glow
            Circle()
                .stroke(Color(hex: 0xFF8A4C).opacity(0.28), lineWidth: 28)
                .frame(width: 128, height: 128)
                .blur(radius: 10)

            // Streak ring — main (angular gradient with strong orange hotspot on right)
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

            // Specular highlight on top-right of ring
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

            // Inner dark rim to give ring depth
            Circle()
                .stroke(Color(hex: 0x3A2D6E).opacity(0.25), lineWidth: 1.4)
                .frame(width: 112, height: 112)

            // Flame layered glow
            Circle()
                .fill(Color(hex: 0xFFA64C).opacity(0.55))
                .frame(width: 72, height: 72)
                .blur(radius: 14)

            Circle()
                .fill(Color(hex: 0xFFD98A).opacity(0.5))
                .frame(width: 46, height: 46)
                .blur(radius: 8)

            // Flame body — outer orange
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

            // Flame inner — yellow/white core
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

private struct DailyFocusBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xF1E7DC),
                    Color(hex: 0xEEDCE4),
                    Color(hex: 0xE8D8EA)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Back mountain (lavender)
            MountainShape(peaks: [
                (0.0, 0.68), (0.2, 0.45), (0.42, 0.58), (0.65, 0.36), (0.85, 0.52), (1.0, 0.48)
            ])
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0xC9B5D9).opacity(0.65), Color(hex: 0xB39CCE).opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .offset(y: 8)

            // Mid mountain (peach)
            MountainShape(peaks: [
                (0.0, 0.85), (0.18, 0.62), (0.38, 0.76), (0.6, 0.55), (0.82, 0.72), (1.0, 0.6)
            ])
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0xE9B7A2).opacity(0.55), Color(hex: 0xE9A4AB).opacity(0.35)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .offset(y: 32)

            // Foreground haze
            LinearGradient(
                colors: [Color.clear, Color(hex: 0xF0D9C4).opacity(0.45), Color(hex: 0xEEC9D5).opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct MountainShape: Shape {
    let peaks: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        for peak in peaks {
            path.addLine(to: CGPoint(x: peak.0 * rect.width, y: peak.1 * rect.height))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - LifeTrack Logo Mark

private struct BetaLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Curved leaf: narrow at top, wider at base, with a soft point at top-left
        path.move(to: CGPoint(x: w * 0.22, y: h * 0.08))
        path.addCurve(
            to: CGPoint(x: w * 0.95, y: h * 0.72),
            control1: CGPoint(x: w * 0.92, y: h * 0.04),
            control2: CGPoint(x: w * 1.05, y: h * 0.36)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.35, y: h * 0.96),
            control1: CGPoint(x: w * 0.85, y: h * 1.02),
            control2: CGPoint(x: w * 0.55, y: h * 1.05)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.22, y: h * 0.08),
            control1: CGPoint(x: w * 0.02, y: h * 0.82),
            control2: CGPoint(x: w * -0.10, y: h * 0.32)
        )
        path.closeSubpath()
        return path
    }
}

private struct BetaLogoMark: View {
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

// MARK: - Routes & Tabs

private enum BetaHomeRoute: Hashable {
    case statistics
    case calendar
    case documents
    case importTasks
    case exportTasks
    case money
}

private struct BetaQuickAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let iconBg: Color
    let iconTint: Color
    var isLocked: Bool = false
    let action: () -> Void
}

private enum BetaTab: Hashable {
    case home, tasks, focus, habits, more
}

private enum DashboardSortOrder: String, CaseIterable {
    case dueDate = "Due Date"
    case priority = "Priority"
    case title = "Title"
}

enum BetaSummaryKind: String, CaseIterable, Identifiable {
    case dueToday, upcoming, completed, overdue
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dueToday: "Due Today"
        case .upcoming: "Upcoming"
        case .completed: "Completed"
        case .overdue: "Overdue"
        }
    }

    var subtitle: String {
        switch self {
        case .dueToday: "Needs attention"
        case .upcoming: "Planned ahead"
        case .completed: "Finished"
        case .overdue: "Past due"
        }
    }

    var sheetSubtitle: String {
        switch self {
        case .dueToday: "Tasks that need attention before the day closes."
        case .upcoming: "Planned work coming up after today."
        case .completed: "Finished tasks you can review or move back to open."
        case .overdue: "Past-due tasks that need a new decision."
        }
    }

    var emptyTitle: String {
        switch self {
        case .dueToday: "Nothing due today"
        case .upcoming: "No upcoming tasks"
        case .completed: "No completed tasks yet"
        case .overdue: "Nothing overdue"
        }
    }

    var emptyMessage: String {
        switch self {
        case .dueToday: "Your day is clear. Create a task if something needs attention."
        case .upcoming: "Add due dates to see what is planned beyond today."
        case .completed: "Completed tasks will appear here once you finish them."
        case .overdue: "No past-due items. Keep the dashboard current by updating due dates."
        }
    }

    var symbolName: String {
        switch self {
        case .dueToday: "sun.max.fill"
        case .upcoming: "calendar"
        case .completed: "checkmark.seal.fill"
        case .overdue: "exclamationmark.triangle.fill"
        }
    }

    var iconTint: Color {
        switch self {
        case .dueToday: BetaPalette.statDueToday
        case .upcoming: BetaPalette.statUpcoming
        case .completed: BetaPalette.statCompleted
        case .overdue: BetaPalette.statOverdue
        }
    }

    var iconBg: Color {
        switch self {
        case .dueToday: BetaPalette.statDueTodayBg
        case .upcoming: BetaPalette.statUpcomingBg
        case .completed: BetaPalette.statCompletedBg
        case .overdue: BetaPalette.statOverdueBg
        }
    }
}

// MARK: - BetaDashboardHomeView

struct BetaDashboardHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && !$0.isCompleted }, sort: \LifeTask.dueDate, order: .forward)
    private var openTasks: [LifeTask]

    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && $0.isCompleted }, sort: \LifeTask.dueDate, order: .reverse)
    private var completedTasks: [LifeTask]

    private var allTasks: [LifeTask] { openTasks + completedTasks }

    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]

    @State private var navigationPath: [BetaHomeRoute] = []
    @State private var selectedTab: BetaTab = .home
    @State private var isShowingSettings = false
    @State private var isShowingTemplatePicker = false
    @State private var isShowingTaskEditor = false
    @State private var isShowingHabits = false
    @State private var isShowingDailyRitual = false
    @State private var isShowingWeeklyReview = false
    @State private var selectedTemplate: TaskTemplate? = nil
    @State private var shouldAutoStartVoice = false
    @State private var editingTask: LifeTask? = nil
    @State private var isShowingAISuggestions = false
    @State private var isShowingSmartScheduling = false
    @State private var isShowingAvailability = false
    @State private var isShowingPaywall = false
    @State private var availabilityShareRange: AvailabilityShareRange = .today
    @AppStorage(LifeTrackSettings.Keys.betaShapesOpacity) private var shapesOpacity: Double = 0.35

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                ZStack {
                    BetaAnimatedShapesBackground(opacity: shapesOpacity)
                        .ignoresSafeArea()

                    BetaDashboardView(
                        onOpenStatistics: { navigationPath.append(.statistics) },
                        onOpenSettings: { isShowingSettings = true },
                        onPresentSheet: handleSheetRequest,
                        onNavigate: { navigationPath.append($0) }
                    )
                }
                .frame(maxHeight: .infinity)

                tabBarOverlay
                    .background(BetaPalette.appBackground.ignoresSafeArea(edges: .bottom))
            }
            .overlay(alignment: .bottomTrailing) { fabOverlay }
            .navigationBarHidden(true)
            .navigationDestination(for: BetaHomeRoute.self) { route in
                switch route {
                case .statistics:
                    StatisticsView(tasks: allTasks)
                case .calendar:
                    TaskCalendarView(
                        tasks: openTasks,
                        customCategories: customCategories,
                        focusAvailabilityOnAppear: false,
                        initialAvailabilityRange: .today,
                        onToggleCompletion: toggleCompletion,
                        onEdit: { editingTask = $0 },
                        onDelete: { _ in }
                    )
                case .documents:
                    DocumentSearchView()
                case .importTasks:
                    TaskDataExchangeView(initialMode: .importTasks)
                case .exportTasks:
                    TaskDataExchangeView(initialMode: .exportTasks)
                case .money:
                    MoneyOverviewView()
                }
            }
            .onChange(of: selectedTab) { _, tab in
                handleTabSelection(tab)
            }
        }
        .tint(BetaPalette.accent)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $isShowingTemplatePicker) {
            TemplatePickerView(
                onSelectBlank: openBlankTaskFromPicker,
                onSelectVoice: openVoiceTaskFromPicker,
                onSelectTemplate: openTemplateFromPicker
            )
        }
        .sheet(isPresented: $isShowingTaskEditor, onDismiss: { shouldAutoStartVoice = false }) {
            NewTaskView(template: selectedTemplate, autoStartVoice: shouldAutoStartVoice)
        }
        .sheet(item: $editingTask) { task in
            NewTaskView(task: task)
        }
        .sheet(isPresented: $isShowingHabits) {
            HabitTrackerView(
                tasks: openTasks,
                customCategories: customCategories,
                onToggleCompletion: toggleCompletion
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingDailyRitual) {
            DailyPlanningRitualView(
                tasks: openTasks,
                customCategories: customCategories,
                onToggleCompletion: toggleCompletion,
                onReschedule: { task, date in
                    task.dueDate = date
                    task.updatedAt = Date()
                    try? modelContext.save()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingWeeklyReview) {
            WeeklyReviewView(tasks: openTasks, customCategories: customCategories)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingAISuggestions) {
            AITaskSuggestionsView(tasks: openTasks)
        }
        .sheet(isPresented: $isShowingSmartScheduling) {
            SmartSchedulingOptimizerView(tasks: openTasks)
        }
        .sheet(isPresented: $isShowingAvailability) {
            AvailabilityShareSheet(
                selectedRange: $availabilityShareRange,
                tasks: openTasks,
                customCategories: customCategories,
                onOpenCalendar: {
                    isShowingAvailability = false
                    navigationPath.append(.calendar)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
    }

    private var fabOverlay: some View {
        Button {
            isShowingTemplatePicker = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(BetaPalette.fabGradient, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: BetaPalette.accent.opacity(0.55), radius: 18, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 22)
        .padding(.bottom, 16)
        .accessibilityLabel("Create task")
    }

    private var tabBarOverlay: some View {
        BetaDashboardTabBar(selectedTab: $selectedTab)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }

    private func handleTabSelection(_ tab: BetaTab) {
        switch tab {
        case .home:
            break
        case .tasks:
            isShowingWeeklyReview = true
            resetTab()
        case .focus:
            isShowingDailyRitual = true
            resetTab()
        case .habits:
            isShowingHabits = true
            resetTab()
        case .more:
            isShowingSettings = true
            resetTab()
        }
    }

    private func resetTab() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            selectedTab = .home
        }
    }

    private func handleSheetRequest(_ sheet: BetaDashboardView.Sheet) {
        switch sheet {
        case .streaks: isShowingHabits = true
        case .planMyDay: isShowingDailyRitual = true
        case .review: isShowingWeeklyReview = true
        case .newTask:
            selectedTemplate = nil
            shouldAutoStartVoice = false
            isShowingTaskEditor = true
        case .templates:
            isShowingTemplatePicker = true
        case .availability:
            isShowingAvailability = true
        case .aiSuggestions:
            isShowingAISuggestions = true
        case .smartScheduling:
            isShowingSmartScheduling = true
        case .template(let id):
            selectedTemplate = TaskTemplate.common.first { $0.id == id }
            shouldAutoStartVoice = false
            isShowingTaskEditor = true
        case .paywall:
            isShowingPaywall = true
        }
    }

    private func openBlankTaskFromPicker() {
        selectedTemplate = nil
        shouldAutoStartVoice = false
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func openVoiceTaskFromPicker() {
        selectedTemplate = nil
        shouldAutoStartVoice = true
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func openTemplateFromPicker(_ template: TaskTemplate) {
        selectedTemplate = template
        shouldAutoStartVoice = false
        isShowingTemplatePicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isShowingTaskEditor = true
        }
    }

    private func toggleCompletion(_ task: LifeTask) {
        let pending = TaskLifecycleManager.beginToggleCompletion(for: task)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            TaskLifecycleManager.finishToggleCompletion(pending, in: modelContext, customCategories: customCategories)
        }
    }
}

// MARK: - BetaDashboardView (scroll content)

struct BetaDashboardView: View {
    enum Sheet {
        case streaks, planMyDay, review
        case newTask, templates, availability, aiSuggestions, smartScheduling
        case template(id: String)
        case paywall
    }

    var onOpenStatistics: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil
    var onPresentSheet: ((Sheet) -> Void)? = nil
    fileprivate var onNavigate: ((BetaHomeRoute) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query private var tasks: [LifeTask]
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]
    @AppStorage(LifeTrackSettings.Keys.nickname) private var nickname = ""
    @AppStorage(LifeTrackSettings.Keys.avatarVersion) private var avatarVersion = 0
    @AppStorage(LifeTrackSettings.Keys.themeID) private var themeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.colorStrength) private var colorStrength: Double = 1.0
    @AppStorage("qa.planMyDay") private var showPlanMyDay = true
    @AppStorage("qa.habits") private var showHabits = true
    @AppStorage("qa.review") private var showReview = true
    @AppStorage("qa.focusTimer") private var showFocusTimer = true
    @AppStorage("qa.newTask") private var showNewTask = true
    @AppStorage("qa.templates") private var showTemplates = true
    @AppStorage("qa.availability") private var showAvailability = false
    @AppStorage("qa.calendar") private var showCalendar = true
    @AppStorage("qa.statistics") private var showStatistics = true
    @AppStorage("qa.documents") private var showDocuments = false
    @AppStorage("qa.import") private var showImport = false
    @AppStorage("qa.export") private var showExport = false
    @AppStorage("qa.email") private var showEmail = false
    @AppStorage("qa.bill") private var showBill = false
    @AppStorage("qa.medication") private var showMedication = false
    @AppStorage("qa.budget") private var showBudget = false
    @AppStorage("qa.checkup") private var showCheckup = false
    @AppStorage("qa.aiSuggestions") private var showAISuggestions = true
    @AppStorage("qa.smartSchedule") private var showSmartSchedule = true

    @State private var focusSortOrder: DashboardSortOrder = .dueDate
    @State private var isShowingFocusTimer = false
    @State private var isShowingCustomize = false
    @State private var selectedSummaryKind: BetaSummaryKind?
    @State private var editingTask: LifeTask?

    private var isEmbeddedAsHome: Bool {
        onOpenStatistics != nil || onOpenSettings != nil || onPresentSheet != nil
    }

    private var activeTasks: [LifeTask] {
        tasks.filter { $0.deletedAt == nil }
    }

    private var dueToday: Int {
        activeTasks.filter { !$0.isCompleted && Calendar.current.isDateInToday($0.dueDate) }.count
    }

    private var upcoming: Int {
        let now = Date()
        let cal = Calendar.current
        return activeTasks
            .filter { !$0.isCompleted && $0.dueDate > now && !cal.isDateInToday($0.dueDate) }
            .count
    }

    private var completed: Int {
        tasks.filter { $0.isCompleted }.count
    }

    private var overdue: Int {
        activeTasks.filter { $0.isOverdue }.count
    }

    private var metricTrends: BetaMetricTrends {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let pastDays: [Date] = (0..<7).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
        let futureDays: [Date] = (1...7).compactMap {
            cal.date(byAdding: .day, value: $0, to: today)
        }
        let pastEndOfDays: [Date] = pastDays.compactMap {
            cal.date(bySettingHour: 23, minute: 59, second: 59, of: $0)
        }

        var dueTodayCounts = Array(repeating: 0.0, count: pastDays.count)
        var upcomingCounts = Array(repeating: 0.0, count: futureDays.count)
        var completedCounts = Array(repeating: 0.0, count: pastDays.count)
        var overdueCounts = Array(repeating: 0.0, count: pastEndOfDays.count)

        for task in tasks {
            guard task.deletedAt == nil else { continue }

            let dueDay = cal.startOfDay(for: task.dueDate)
            for (i, day) in pastDays.enumerated() where dueDay == day {
                dueTodayCounts[i] += 1
            }
            if !task.isCompleted {
                for (i, day) in futureDays.enumerated() where dueDay == day {
                    upcomingCounts[i] += 1
                }
            }
            if let completedAt = task.completedAt {
                let completedDay = cal.startOfDay(for: completedAt)
                for (i, day) in pastDays.enumerated() where completedDay == day {
                    completedCounts[i] += 1
                }
            }
            for (i, endOfDay) in pastEndOfDays.enumerated() {
                guard task.dueDate < endOfDay else { continue }
                let wasIncomplete: Bool
                if task.isCompleted {
                    wasIncomplete = (task.completedAt ?? .distantPast) > endOfDay
                } else {
                    wasIncomplete = true
                }
                if wasIncomplete {
                    overdueCounts[i] += 1
                }
            }
        }

        return BetaMetricTrends(
            dueToday: dueTodayCounts,
            upcoming: upcomingCounts,
            completed: completedCounts,
            overdue: overdueCounts
        )
    }

    private var focusTasks: [LifeTask] {
        let base = activeTasks.filter { !$0.isCompleted }
        switch focusSortOrder {
        case .dueDate:
            return base.sorted { $0.dueDate < $1.dueDate }
        case .priority:
            return base.sorted { $0.priority.focusScore > $1.priority.focusScore }
        case .title:
            return base.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    private var dueTodayTaskList: [LifeTask] {
        activeTasks.filter { !$0.isCompleted && Calendar.current.isDateInToday($0.dueDate) }
    }

    private var upcomingTaskList: [LifeTask] {
        let now = Date(); let cal = Calendar.current
        return activeTasks.filter { !$0.isCompleted && $0.dueDate > now && !cal.isDateInToday($0.dueDate) }
    }

    private var completedTaskList: [LifeTask] {
        tasks.filter { $0.deletedAt == nil && $0.isCompleted }
    }

    private var overdueTaskList: [LifeTask] {
        activeTasks.filter { $0.isOverdue }
    }

    private var documentTasks: [LifeTask] {
        tasks
            .filter { $0.deletedAt == nil && $0.hasDocument }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func taskList(for kind: BetaSummaryKind) -> [LifeTask] {
        switch kind {
        case .dueToday: dueTodayTaskList
        case .upcoming: upcomingTaskList
        case .completed: completedTaskList
        case .overdue: overdueTaskList
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let phase: String
        switch hour {
        case 0..<12: phase = "Good morning"
        case 12..<17: phase = "Good afternoon"
        default: phase = "Good evening"
        }
        let name = nickname.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? phase : "\(phase), \(name)"
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: Date())
    }

    private var streakCurrent: Int {
        let cal = Calendar.current
        let days = Set(tasks.compactMap(\.completedAt).map { cal.startOfDay(for: $0) })
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private var streakBest: Int {
        let cal = Calendar.current
        let days = Set(tasks.compactMap(\.completedAt).map { cal.startOfDay(for: $0) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<days.count {
            if let next = cal.date(byAdding: .day, value: 1, to: days[i - 1]), next == days[i] {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    private var streakWeek: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekAgo = cal.date(byAdding: .day, value: -6, to: today) else { return 0 }
        let days = Set(tasks.compactMap(\.completedAt).map { cal.startOfDay(for: $0) })
        return days.filter { $0 >= weekAgo && $0 <= today }.count
    }

    private var streakSubtitle: String {
        switch streakCurrent {
        case 0: return "Complete a task today\nto start your streak."
        case 1: return "Great start! You've completed\na task 1 day in a row."
        default: return "You've completed a task\n\(streakCurrent) days in a row."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                greetingHeader
                brandBlock
                if overdue > 0 {
                    alertBanner
                }
                streakHeroPager
                statsGrid
                    .padding(.bottom, -4)
                quickActionsSection
                dailyFocusSection
                recentDocumentsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $selectedSummaryKind) { kind in
            BetaStatSummarySheet(kind: kind)
        }
        .sheet(item: $editingTask) { task in
            NewTaskView(task: task)
        }
        .sheet(isPresented: $isShowingFocusTimer) {
            FocusTimerSheet()
        }
        .sheet(isPresented: $isShowingCustomize) {
            QuickActionsCustomizeSheet(
                showPlanMyDay: $showPlanMyDay,
                showHabits: $showHabits,
                showReview: $showReview,
                showFocusTimer: $showFocusTimer,
                showNewTask: $showNewTask,
                showTemplates: $showTemplates,
                showAvailability: $showAvailability,
                showCalendar: $showCalendar,
                showStatistics: $showStatistics,
                showDocuments: $showDocuments,
                showImport: $showImport,
                showExport: $showExport,
                showEmail: $showEmail,
                showBill: $showBill,
                showMedication: $showMedication,
                showBudget: $showBudget,
                showCheckup: $showCheckup,
                showAISuggestions: $showAISuggestions,
                showSmartSchedule: $showSmartSchedule
            )
        }
    }

    // MARK: Greeting header

    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.betaGreeting)
                    .foregroundStyle(BetaPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(dateLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BetaPalette.secondaryText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                headerCircleButton(icon: "chart.line.uptrend.xyaxis", showsDot: false) {
                    onOpenStatistics?()
                }
                .accessibilityLabel("Open statistics")

                Button {
                    onOpenSettings?()
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatarView(size: 40, avatarVersion: avatarVersion)
                        Circle()
                            .fill(Color(hex: 0xEF4444))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .offset(x: 1, y: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
            }
        }
    }

    private func headerCircleButton(icon: String, showsDot: Bool, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(filled ? AnyShapeStyle(BetaPalette.accentSoft) : AnyShapeStyle(Color.white))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BetaPalette.accent)

                if showsDot {
                    Circle()
                        .fill(Color(hex: 0xEF4444))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 13, y: 13)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Brand block

    private var brandBlock: some View {
        HStack(spacing: 8) {
            BetaLogoMark()
            Text("LifeTrack")
                .font(.betaBrand)
                .foregroundStyle(BetaPalette.primaryText)
        }
    }

    // MARK: Alert banner

    private var alertBanner: some View {
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BetaPalette.alertText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BetaPalette.alertText.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            BetaPalette.alertBg,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    // MARK: Productivity hero pager

    private var weeklyCompletionCounts: [Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekAgo = cal.date(byAdding: .day, value: -6, to: today) else {
            return Array(repeating: 0, count: 7)
        }
        var counts = Array(repeating: 0, count: 7)
        for task in tasks {
            guard let completedAt = task.completedAt else { continue }
            let day = cal.startOfDay(for: completedAt)
            if day >= weekAgo && day <= today,
               let diff = cal.dateComponents([.day], from: weekAgo, to: day).day,
               diff >= 0 && diff < 7 {
                counts[diff] += 1
            }
        }
        return counts
    }

    private var streakHeroPager: some View {
        HeroPager(
            pages: [
                AnyView(weeklyRhythmCard),
                AnyView(todayPlanHeroCard),
                AnyView(nextMoveHeroCard),
                AnyView(streakHeroCard),
                AnyView(upgradeHeroCard)
            ]
        )
    }

    private var upgradeHeroCard: some View {
        let isUltimate = subscriptionManager.tier >= .ultimate
        let features: [(String, String)] = [
            ("brain.head.profile", "AI Suggestions"),
            ("calendar.badge.clock", "Smart Schedule"),
            ("icloud.fill", "Auto Backups"),
            ("timer", "Focus Timer"),
            ("flame.fill", "Habit Streaks"),
            ("doc.badge.plus", "Templates"),
        ]
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                }
                .shadow(color: BetaPalette.accentDeep.opacity(0.08), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 0) {
                // — top row: title + crown
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isUltimate ? "You're Ultimate" : "Unlock Ultimate")
                            .font(.betaHeroTitle)
                            .foregroundStyle(BetaPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(isUltimate
                             ? "Every premium feature unlocked."
                             : "AI, scheduling, backups & more.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(BetaPalette.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [BetaPalette.accent.opacity(0.18), BetaPalette.accentDeep.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: isUltimate ? "crown.fill" : "sparkles")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [BetaPalette.accent, BetaPalette.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }

                Spacer(minLength: 12)

                // — feature chips grid
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(features, id: \.0) { icon, label in
                        HStack(spacing: 5) {
                            Image(systemName: icon)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(BetaPalette.accent)
                            Text(label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(BetaPalette.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(isUltimate ? 0.55 : 0.38), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(BetaPalette.accent.opacity(0.18), lineWidth: 0.7)
                        }
                    }
                }

                Spacer(minLength: 14)

                // — CTA button
                Button {
                    if !isUltimate { onPresentSheet?(.paywall) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isUltimate ? "checkmark.seal.fill" : "crown.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isUltimate ? "Your Plan" : "See Plans")
                            .font(.system(size: 14, weight: .semibold))
                        if !isUltimate {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isUltimate || onPresentSheet == nil)
                .opacity(isUltimate ? 0.8 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var weeklyRhythmCard: some View {
        let counts = weeklyCompletionCounts
        let maxV = max(counts.max() ?? 0, 1)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekAgo = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let symbols = cal.veryShortWeekdaySymbols

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                }
                .shadow(color: BetaPalette.accentDeep.opacity(0.08), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("This Week's Rhythm")
                    .font(.betaHeroTitle)
                    .foregroundStyle(BetaPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(streakWeek > 0
                     ? "You finished a task on \(streakWeek) of 7 days."
                     : "No completions yet.\nFinish one to start the rhythm.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(BetaPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        let day = cal.date(byAdding: .day, value: i, to: weekAgo) ?? today
                        let isToday = cal.isDate(day, inSameDayAs: today)
                        let heightValue = max(6, CGFloat(counts[i]) / CGFloat(maxV) * 58)
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: isToday
                                            ? [BetaPalette.accent, BetaPalette.accentDeep]
                                            : [BetaPalette.accent.opacity(0.55), BetaPalette.accent.opacity(0.28)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: heightValue)
                            Text(symbols[cal.component(.weekday, from: day) - 1])
                                .font(.system(size: 10, weight: isToday ? .bold : .medium))
                                .foregroundStyle(isToday ? BetaPalette.primaryText : BetaPalette.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 78)

                Button {
                    onPresentSheet?(.review)
                } label: {
                    HStack(spacing: 6) {
                        Text("Open Review")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(onPresentSheet == nil)
                .opacity(onPresentSheet == nil ? 0.65 : 1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 14)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var todayPlanHeroCard: some View {
        let subtitle: String
        if overdue > 0 {
            subtitle = "\(overdue) overdue task\(overdue == 1 ? "" : "s") need a decision before new work."
        } else if dueToday > 0 {
            subtitle = "\(dueToday) task\(dueToday == 1 ? "" : "s") due today. Start with the clearest next step."
        } else {
            subtitle = "No tasks due today. Pull one upcoming item forward if you want momentum."
        }

        return productivityHeroShell {
            VStack(alignment: .leading, spacing: 11) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Today's Plan")
                        .font(.betaHeroTitle)
                        .foregroundStyle(BetaPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    heroMetricPill(
                        title: "Due",
                        value: dueToday.formatted(),
                        subtitle: "today",
                        tint: BetaPalette.statDueToday,
                        symbolName: "sun.max.fill"
                    )
                    heroMetricPill(
                        title: "Next",
                        value: upcoming.formatted(),
                        subtitle: "upcoming",
                        tint: BetaPalette.statUpcoming,
                        symbolName: "calendar"
                    )
                    heroMetricPill(
                        title: "Risk",
                        value: overdue.formatted(),
                        subtitle: "overdue",
                        tint: BetaPalette.statOverdue,
                        symbolName: "exclamationmark.triangle.fill"
                    )
                }

                Spacer(minLength: 0)

                heroActionButton(title: "Plan My Day", systemImage: "wand.and.stars") {
                    onPresentSheet?(.planMyDay)
                }
                .disabled(onPresentSheet == nil)
                .opacity(onPresentSheet == nil ? 0.65 : 1)
            }
        }
    }

    private var nextMoveHeroCard: some View {
        let completionShare = activeTasks.isEmpty ? 0 : Int((Double(completedTaskList.count) / Double(activeTasks.count)) * 100)
        let subtitle: String
        if overdue > 0 {
            subtitle = "Clear or reschedule the backlog so today feels honest."
        } else if upcoming > dueToday {
            subtitle = "Your next seven days are loaded. Decide what deserves attention now."
        } else {
            subtitle = "Your queue is light. Review progress and keep priorities tidy."
        }

        return productivityHeroShell {
            VStack(alignment: .leading, spacing: 11) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Next Best Move")
                        .font(.betaHeroTitle)
                        .foregroundStyle(BetaPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 9) {
                    heroProgressRow(
                        title: "Open queue",
                        value: "\(focusTasks.count)",
                        progress: activeTasks.isEmpty ? 0 : Double(focusTasks.count) / Double(max(activeTasks.count, 1)),
                        tint: BetaPalette.accent
                    )
                    heroProgressRow(
                        title: "Completed share",
                        value: "\(completionShare)%",
                        progress: Double(completionShare) / 100,
                        tint: BetaPalette.statCompleted
                    )
                    heroProgressRow(
                        title: "Overdue pressure",
                        value: "\(overdue)",
                        progress: min(Double(overdue) / Double(max(focusTasks.count, 1)), 1),
                        tint: BetaPalette.statOverdue
                    )
                }
                .padding(10)
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer(minLength: 0)

                heroActionButton(title: "Open Review", systemImage: "chart.bar.fill") {
                    onPresentSheet?(.review)
                }
                .disabled(onPresentSheet == nil)
                .opacity(onPresentSheet == nil ? 0.65 : 1)
            }
        }
    }

    private func productivityHeroShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                }
                .shadow(color: BetaPalette.accentDeep.opacity(0.08), radius: 18, y: 8)

            content()
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 14)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func heroMetricPill(title: String, value: String, subtitle: String, tint: Color, symbolName: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: symbolName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)
                    .background(tint.opacity(0.13), in: Circle())

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BetaPalette.secondaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(BetaPalette.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(BetaPalette.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(height: 68)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        }
    }

    private func heroProgressRow(title: String, value: String, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BetaPalette.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(BetaPalette.secondaryText)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.14))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(8, proxy.size.width * CGFloat(min(max(progress, 0), 1))))
                }
            }
            .frame(height: 7)
        }
    }

    private func heroActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Capsule()
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Streak hero card

    private var streakHeroCard: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BetaPalette.heroBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                }
                .shadow(color: BetaPalette.accentDeep.opacity(0.08), radius: 18, y: 8)

            // Illustration on right — extends down so the stone reads above the stats row
            HStack {
                Spacer(minLength: 110)
                StreakHeroIllustration()
                    .scaleEffect(0.82)
                    .frame(width: 180, height: 180)
                    .padding(.trailing, -12)
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Left text + docked stats
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(streakCurrent)-day streak")
                        .font(.betaHeroTitle)
                        .foregroundStyle(BetaPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(streakSubtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        onPresentSheet?(.streaks)
                    } label: {
                        HStack(spacing: 6) {
                            Text("View Streaks")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x1F1B2E), Color(hex: 0x2A2540)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: Capsule()
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(onPresentSheet == nil)
                    .opacity(onPresentSheet == nil ? 0.65 : 1)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                Spacer(minLength: 6)

                // Docked stats row
                streakStatsRow
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var streakStatsRow: some View {
        HStack(spacing: 0) {
            streakStatCell(icon: "flame.fill", iconTint: BetaPalette.accent, value: "\(streakCurrent)", unit: "Day", label: "Current")
            Divider().frame(height: 44).overlay(BetaPalette.faintBorder)
            streakStatCell(icon: "star.fill", iconTint: BetaPalette.accent, value: "\(streakBest)", unit: "Days", label: "Best")
            Divider().frame(height: 44).overlay(BetaPalette.faintBorder)
            streakStatCell(icon: "calendar", iconTint: BetaPalette.accent, value: "\(streakWeek)/7", unit: "Days", label: "This Week")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
    }

    private func streakStatCell(icon: String, iconTint: Color, value: String, unit: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(iconTint)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.betaStreakStat)
                    .foregroundStyle(BetaPalette.primaryText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BetaPalette.secondaryText)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BetaPalette.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: Stats grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            let trends = metricTrends
            statCard(
                icon: "sun.max.fill", iconTint: BetaPalette.statDueToday, iconBg: BetaPalette.statDueTodayBg,
                title: "Due Today", value: dueToday, subtitle: "7-day due",
                waveColor: BetaPalette.waveDueToday, series: trends.dueToday,
                action: { selectedSummaryKind = .dueToday }
            )
            statCard(
                icon: "calendar", iconTint: BetaPalette.statUpcoming, iconBg: BetaPalette.statUpcomingBg,
                title: "Upcoming", value: upcoming, subtitle: "Next week",
                waveColor: BetaPalette.waveUpcoming, series: trends.upcoming,
                action: { selectedSummaryKind = .upcoming }
            )
            statCard(
                icon: "checkmark.seal.fill", iconTint: BetaPalette.statCompleted, iconBg: BetaPalette.statCompletedBg,
                title: "Completed", value: completed, subtitle: "7-day done",
                waveColor: BetaPalette.waveCompleted, series: trends.completed,
                action: { selectedSummaryKind = .completed }
            )
            statCard(
                icon: "exclamationmark.triangle.fill", iconTint: BetaPalette.statOverdue, iconBg: BetaPalette.statOverdueBg,
                title: "Overdue", value: overdue, subtitle: "Backlog",
                waveColor: BetaPalette.waveOverdue, series: trends.overdue,
                action: { selectedSummaryKind = .overdue }
            )
        }
    }

    private func statCard(icon: String, iconTint: Color, iconBg: Color, title: String, value: Int, subtitle: String, waveColor: Color, series: [Double], action: (() -> Void)? = nil) -> some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconTint)
            }

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BetaPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(formattedValue(value))
                .font(.betaMetric)
                .foregroundStyle(BetaPalette.primaryText)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(BetaPalette.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            ZStack(alignment: .bottom) {
                StatSparkline(values: series, closed: true)
                    .fill(
                        LinearGradient(
                            colors: [
                                waveColor.opacity(0.55),
                                waveColor.opacity(0.22),
                                waveColor.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                StatSparkline(values: series, closed: false)
                    .stroke(waveColor, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 32)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BetaPalette.faintBorder, lineWidth: 0.8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            LifeTrackHaptics.lightImpact()
            action?()
        }
    }

    private func formattedValue(_ n: Int) -> String {
        if n < 1000 {
            return "\(n)"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Quick Actions")
                    .font(.betaSection)
                    .foregroundStyle(BetaPalette.primaryText)
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BetaPalette.accentDeep)

                Spacer(minLength: 0)

                Button { isShowingCustomize = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("Customize")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(BetaPalette.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(Color.white)
                            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                    )
                    .overlay {
                        Capsule().stroke(BetaPalette.faintBorder, lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
            }

            quickActionsLayout
        }
    }

    @ViewBuilder
    private var quickActionsLayout: some View {
        let items = visibleQuickActions
        if items.count > 4 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        quickActionTile(item: item)
                            .frame(width: 128)
                    }
                }
                .padding(.vertical, 2)
            }
        } else {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    quickActionTile(item: item)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var visibleQuickActions: [BetaQuickAction] {
        let isStandard = subscriptionManager.tier >= .standard
        let isUltimate = subscriptionManager.tier >= .ultimate
        var items: [BetaQuickAction] = []

        if showPlanMyDay {
            let locked = !isStandard
            items.append(.init(id: "planMyDay", title: "Plan My Day", subtitle: "Daily ritual",
                               icon: "sun.max.fill", iconBg: BetaPalette.qaPlanBg, iconTint: BetaPalette.qaPlanTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.planMyDay)
            })
        }
        if showHabits {
            let locked = !isStandard
            items.append(.init(id: "habits", title: "Habits", subtitle: "Streaks",
                               icon: "flame.fill", iconBg: BetaPalette.qaHabitsBg, iconTint: BetaPalette.qaHabitsTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.streaks)
            })
        }
        if showReview {
            let locked = !isStandard
            items.append(.init(id: "review", title: "Review", subtitle: "Progress",
                               icon: "chart.bar.fill", iconBg: BetaPalette.qaReviewBg, iconTint: BetaPalette.qaReviewTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.review)
            })
        }
        if showFocusTimer {
            items.append(.init(id: "focusTimer", title: "Focus Timer", subtitle: "Deep work",
                               icon: "timer", iconBg: BetaPalette.qaFocusBg, iconTint: BetaPalette.qaFocusTint) {
                isShowingFocusTimer = true
            })
        }
        if showAISuggestions {
            let locked = !isUltimate
            items.append(.init(id: "aiSuggestions", title: "AI Suggestions", subtitle: "Smart focus",
                               icon: "sparkles", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.aiSuggestions)
            })
        }
        if showSmartSchedule {
            let locked = !isUltimate
            items.append(.init(id: "smartSchedule", title: "Schedule", subtitle: "Optimize day",
                               icon: "brain.head.profile", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                               isLocked: locked) {
                locked ? onPresentSheet?(.paywall) : onPresentSheet?(.smartScheduling)
            })
        }
        if showNewTask {
            items.append(.init(id: "newTask", title: "New Task", subtitle: "Start fresh",
                               icon: "plus", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint) {
                onPresentSheet?(.newTask)
            })
        }
        if showTemplates {
            items.append(.init(id: "templates", title: "Templates", subtitle: "Smart shortcuts",
                               icon: "sparkles", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint) {
                onPresentSheet?(.templates)
            })
        }
        if showAvailability {
            items.append(.init(id: "availability", title: "Availability", subtitle: "Share times",
                               icon: "calendar.badge.clock", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint) {
                onPresentSheet?(.availability)
            })
        }
        if showCalendar {
            items.append(.init(id: "calendar", title: "Calendar", subtitle: "See dates",
                               icon: "calendar", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint) {
                onNavigate?(.calendar)
            })
        }
        if showStatistics {
            items.append(.init(id: "statistics", title: "Statistics", subtitle: "See trends",
                               icon: "chart.bar.xaxis", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint) {
                onOpenStatistics?()
            })
        }
        if showDocuments {
            items.append(.init(id: "documents", title: "Documents", subtitle: "Search files",
                               icon: "doc.text.magnifyingglass", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint) {
                onNavigate?(.documents)
            })
        }
        if showImport {
            items.append(.init(id: "import", title: "Import", subtitle: "From file",
                               icon: "tray.and.arrow.down", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint) {
                onNavigate?(.importTasks)
            })
        }
        if showExport {
            items.append(.init(id: "export", title: "Export", subtitle: "Share/AirDrop",
                               icon: "square.and.arrow.up", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint) {
                onNavigate?(.exportTasks)
            })
        }
        if showEmail {
            items.append(.init(id: "email", title: "Email follow-up", subtitle: "Use template",
                               icon: "envelope.badge", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint) {
                onPresentSheet?(.template(id: "email"))
            })
        }
        if showBill {
            items.append(.init(id: "bill", title: "Pay bill", subtitle: "Monthly",
                               icon: "creditcard", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint) {
                onPresentSheet?(.template(id: "bill"))
            })
        }
        if showMedication {
            items.append(.init(id: "medication", title: "Medication", subtitle: "Daily routine",
                               icon: "cross.case", iconBg: BetaPalette.qaDangerBg, iconTint: BetaPalette.qaDangerTint) {
                onPresentSheet?(.template(id: "medication"))
            })
        }
        if showBudget {
            items.append(.init(id: "budget", title: "Money", subtitle: "Budget & actuals",
                               icon: "chart.pie", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint) {
                onNavigate?(.money)
            })
        }
        if showCheckup {
            items.append(.init(id: "checkup", title: "Health check", subtitle: "Book visit",
                               icon: "heart.text.square", iconBg: BetaPalette.qaDangerBg, iconTint: BetaPalette.qaDangerTint) {
                onPresentSheet?(.template(id: "checkup"))
            })
        }
        return items
    }

    private func quickActionTile(item: BetaQuickAction) -> some View {
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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BetaPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BetaPalette.faintBorder, lineWidth: 0.8)
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

    // MARK: Daily Focus

    private var dailyFocusSection: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clear)
                .background(
                    DailyFocusBackdrop()
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Daily Focus")
                        .font(.betaSection)
                        .foregroundStyle(BetaPalette.primaryText)

                    Text("\(focusTasks.count) tasks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BetaPalette.secondaryText)

                    Spacer(minLength: 0)

                    Menu {
                        ForEach(DashboardSortOrder.allCases, id: \.self) { order in
                            Button {
                                focusSortOrder = order
                            } label: {
                                if focusSortOrder == order {
                                    Label(order.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(order.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(focusSortOrder.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BetaPalette.primaryText)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(BetaPalette.secondaryText)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color.white)
                                .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)

                focusList
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
            }
        }
    }

    private var focusList: some View {
        Group {
            if focusTasks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(BetaPalette.secondaryText)
                    Text("Nothing in focus — you're all caught up.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BetaPalette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(focusTasks.prefix(5))) { task in
                        TaskRowView(
                            task: task,
                            onToggleCompletion: { toggleFocusCompletion(task) },
                            onEdit: { editingTask = task },
                            onDelete: { deleteFocusTask(task) },
                            categoryOption: task.categoryOption(customCategories: customCategories),
                            showsBorder: false
                        )
                    }

                    HStack(spacing: 10) {
                        betaFocusPlanningButton(
                            title: "Reset My Day",
                            symbol: "arrow.clockwise",
                            tint: BetaPalette.accent
                        ) { resetMyDay() }

                        betaFocusPlanningButton(
                            title: "Reschedule Overdue",
                            symbol: "calendar.badge.clock",
                            tint: BetaPalette.overdue
                        ) { rescheduleOverdue() }
                    }
                }
            }
        }
    }

    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("Recent Documents")
                    .font(.betaSection)
                    .foregroundStyle(BetaPalette.primaryText)

                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BetaPalette.tertiaryText)

                Spacer(minLength: 0)

                if !documentTasks.isEmpty {
                    Text("\(documentTasks.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BetaPalette.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.85), in: Capsule())
                }
            }

            if documentTasks.isEmpty {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(BetaPalette.accent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(BetaPalette.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("No documents yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BetaPalette.primaryText)
                        Text("Attach a file from any task to keep supporting context nearby.")
                            .font(.footnote)
                            .foregroundStyle(BetaPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BetaPalette.faintBorder, lineWidth: 0.8)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(documentTasks.prefix(3))) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            BetaRecentDocumentRow(
                                task: task,
                                categoryOption: task.categoryOption(customCategories: customCategories)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func betaFocusPlanningButton(title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 9)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
    }

    private func toggleFocusCompletion(_ task: LifeTask) {
        let pending = TaskLifecycleManager.beginToggleCompletion(for: task)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            TaskLifecycleManager.finishToggleCompletion(pending, in: modelContext, customCategories: customCategories)
        }
    }

    private func deleteFocusTask(_ task: LifeTask) {
        _ = TaskLifecycleManager.delete(task, in: modelContext)
    }

    private func resetMyDay() {
        let openTasks = activeTasks.filter { !$0.isCompleted }
        let focusIDs = Set(focusTasks.prefix(5).map(\.id))
        let plan = DailyFocusPlanner.resetSchedule(for: openTasks, focusIDs: focusIDs)
        TaskLifecycleManager.applySchedule(plan, in: modelContext, customCategories: customCategories)
    }

    private func rescheduleOverdue() {
        let openTasks = activeTasks.filter { !$0.isCompleted }
        let plan = DailyFocusPlanner.overdueReschedulePlan(for: openTasks)
        TaskLifecycleManager.applySchedule(plan, in: modelContext, customCategories: customCategories)
    }
}

// MARK: - Stat Summary Sheet

private struct BetaStatSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && !$0.isCompleted }, sort: \LifeTask.dueDate)
    private var openTasks: [LifeTask]
    @Query(filter: #Predicate<LifeTask> { $0.deletedAt == nil && $0.isCompleted }, sort: \LifeTask.dueDate, order: .reverse)
    private var completedTasks: [LifeTask]
    @Query(sort: \CustomTaskCategory.title) private var customCategories: [CustomTaskCategory]
    @State private var editingTask: LifeTask?
    @AppStorage(LifeTrackSettings.Keys.themeID) private var themeID = LifeTrackAppTheme.fallback.rawValue
    @AppStorage(LifeTrackSettings.Keys.colorStrength) private var colorStrength: Double = 1.0

    let kind: BetaSummaryKind

    private var filteredTasks: [LifeTask] {
        let cal = Calendar.current
        let now = Date()
        switch kind {
        case .dueToday:
            return openTasks.filter { cal.isDateInToday($0.dueDate) }
        case .upcoming:
            return openTasks.filter { $0.dueDate > now && !cal.isDateInToday($0.dueDate) }
        case .completed:
            return completedTasks
        case .overdue:
            return openTasks.filter(\.isOverdue)
        }
    }

    private var uniqueCategoryCount: Int {
        Set(filteredTasks.map(\.categoryRawValue)).count
    }

    private var fileCount: Int {
        filteredTasks.filter(\.hasDocument).count
    }

    private var latestLabel: String {
        if kind == .completed {
            return filteredTasks.compactMap(\.completedAt).max()?.dayMonthString ?? "—"
        }
        return filteredTasks.map(\.dueDate).min()?.dayMonthString ?? "—"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryHeader

                        statsRow

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Tasks")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            Text(kind.subtitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        }

                        if filteredTasks.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: LifeTrackTheme.Spacing.small) {
                                ForEach(filteredTasks) { task in
                                    BetaSummaryTaskCard(
                                        task: task,
                                        categoryOption: task.categoryOption(customCategories: customCategories),
                                        onToggleCompletion: { toggleCompletion(task) },
                                        onEdit: { editingTask = task },
                                        onDelete: { deleteTask(task) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
        }
        .sheet(item: $editingTask) { task in
            NewTaskView(task: task)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(kind.iconBg)
                    .frame(width: 56, height: 56)
                Image(systemName: kind.symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(kind.iconTint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(kind.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text("\(filteredTasks.count)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(kind.iconTint)
                }
                Text(kind.sheetSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.6), lineWidth: 0.7)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(uniqueCategoryCount)", label: "Categories")
            Divider().frame(height: 36)
            statCell(value: "\(fileCount)", label: "Files")
            Divider().frame(height: 36)
            statCell(value: latestLabel, label: kind == .completed ? "Latest" : "Nearest")
        }
        .padding(.vertical, 12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.6), lineWidth: 0.7)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            Text(kind.emptyTitle)
                .font(.headline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            Text(kind.emptyMessage)
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggleCompletion(_ task: LifeTask) {
        let pending = TaskLifecycleManager.beginToggleCompletion(for: task)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            TaskLifecycleManager.finishToggleCompletion(pending, in: modelContext, customCategories: customCategories)
        }
    }

    private func deleteTask(_ task: LifeTask) {
        _ = TaskLifecycleManager.delete(task, in: modelContext)
    }
}

// MARK: - Focus Timer Sheet

private struct FocusTimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var timeRemaining: Int = 25 * 60
    @State private var isRunning = false
    @State private var isBreak = false
    @State private var timerTask: Task<Void, Never>?

    private let workDuration = 25 * 60
    private let breakDuration = 5 * 60

    var body: some View {
        NavigationView {
            VStack(spacing: 36) {
                Spacer()

                Text(isBreak ? "Break" : "Focus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isBreak ? BetaPalette.statCompleted : BetaPalette.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(isBreak ? BetaPalette.statCompletedBg : BetaPalette.accentSoft)
                    )

                ZStack {
                    Circle()
                        .stroke(BetaPalette.faintBorder, lineWidth: 14)
                        .frame(width: 240, height: 240)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isBreak ? BetaPalette.statCompleted : BetaPalette.accent,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 240, height: 240)
                        .animation(.linear(duration: 0.8), value: progress)

                    Text(timeString)
                        .font(.system(size: 54, weight: .bold, design: .monospaced))
                        .foregroundStyle(BetaPalette.primaryText)
                }

                HStack(spacing: 24) {
                    circleButton(icon: "arrow.counterclockwise", size: 56) {
                        resetTimer()
                    }

                    circleButton(icon: isRunning ? "pause.fill" : "play.fill", size: 72, isPrimary: true) {
                        isRunning ? pauseTimer() : startTimer()
                    }

                    circleButton(icon: "forward.end.fill", size: 56) {
                        skipPhase()
                    }
                }

                HStack(spacing: 24) {
                    sessionLabel(value: "25 min", caption: "Focus")
                    Rectangle()
                        .fill(BetaPalette.faintBorder)
                        .frame(width: 1, height: 32)
                    sessionLabel(value: "5 min", caption: "Break")
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(BetaPalette.appBackground.ignoresSafeArea())
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BetaPalette.accent)
                }
            }
        }
        .onDisappear { pauseTimer() }
    }

    private var timeString: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    private var progress: Double {
        let total = isBreak ? Double(breakDuration) : Double(workDuration)
        return 1.0 - Double(timeRemaining) / total
    }

    private func startTimer() {
        isRunning = true
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    isBreak.toggle()
                    timeRemaining = isBreak ? breakDuration : workDuration
                    LifeTrackHaptics.lightImpact()
                }
            }
        }
    }

    private func pauseTimer() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
    }

    private func resetTimer() {
        pauseTimer()
        isBreak = false
        timeRemaining = workDuration
        LifeTrackHaptics.lightImpact()
    }

    private func skipPhase() {
        pauseTimer()
        isBreak.toggle()
        timeRemaining = isBreak ? breakDuration : workDuration
        LifeTrackHaptics.lightImpact()
    }

    private func circleButton(icon: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            LifeTrackHaptics.lightImpact()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 26 : 20, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : BetaPalette.secondaryText)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isPrimary ? AnyShapeStyle(BetaPalette.primaryGradient) : AnyShapeStyle(Color.white))
                        .shadow(
                            color: isPrimary ? BetaPalette.accent.opacity(0.4) : Color.black.opacity(0.06),
                            radius: isPrimary ? 12 : 8,
                            y: isPrimary ? 6 : 3
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func sessionLabel(value: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(BetaPalette.primaryText)
            Text(caption)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BetaPalette.secondaryText)
        }
    }
}

// MARK: - Quick Actions Customize Sheet

private struct QuickActionsCustomizeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showPlanMyDay: Bool
    @Binding var showHabits: Bool
    @Binding var showReview: Bool
    @Binding var showFocusTimer: Bool
    @Binding var showNewTask: Bool
    @Binding var showTemplates: Bool
    @Binding var showAvailability: Bool
    @Binding var showCalendar: Bool
    @Binding var showStatistics: Bool
    @Binding var showDocuments: Bool
    @Binding var showImport: Bool
    @Binding var showExport: Bool
    @Binding var showEmail: Bool
    @Binding var showBill: Bool
    @Binding var showMedication: Bool
    @Binding var showBudget: Bool
    @Binding var showCheckup: Bool
    @Binding var showAISuggestions: Bool
    @Binding var showSmartSchedule: Bool

    var body: some View {
        NavigationView {
            List {
                Section("Rituals & focus") {
                    actionRow(title: "Plan My Day", subtitle: "Daily ritual",
                              icon: "sun.max.fill", iconBg: BetaPalette.qaPlanBg, iconTint: BetaPalette.qaPlanTint,
                              isOn: $showPlanMyDay)
                    actionRow(title: "Habits", subtitle: "Streaks",
                              icon: "flame.fill", iconBg: BetaPalette.qaHabitsBg, iconTint: BetaPalette.qaHabitsTint,
                              isOn: $showHabits)
                    actionRow(title: "Review", subtitle: "Progress",
                              icon: "chart.bar.fill", iconBg: BetaPalette.qaReviewBg, iconTint: BetaPalette.qaReviewTint,
                              isOn: $showReview)
                    actionRow(title: "Focus Timer", subtitle: "Deep work",
                              icon: "timer", iconBg: BetaPalette.qaFocusBg, iconTint: BetaPalette.qaFocusTint,
                              isOn: $showFocusTimer)
                    actionRow(title: "AI Suggestions", subtitle: "Smart focus",
                              icon: "sparkles", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                              isOn: $showAISuggestions)
                    actionRow(title: "Schedule", subtitle: "Optimize day",
                              icon: "brain.head.profile", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                              isOn: $showSmartSchedule)
                }

                Section("Capture") {
                    actionRow(title: "New Task", subtitle: "Start fresh",
                              icon: "plus", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint,
                              isOn: $showNewTask)
                    actionRow(title: "Templates", subtitle: "Smart shortcuts",
                              icon: "sparkles", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint,
                              isOn: $showTemplates)
                    actionRow(title: "Availability", subtitle: "Share times",
                              icon: "calendar.badge.clock", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint,
                              isOn: $showAvailability)
                    actionRow(title: "Email follow-up", subtitle: "Use template",
                              icon: "envelope.badge", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint,
                              isOn: $showEmail)
                    actionRow(title: "Pay bill", subtitle: "Monthly",
                              icon: "creditcard", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint,
                              isOn: $showBill)
                    actionRow(title: "Medication", subtitle: "Daily routine",
                              icon: "cross.case", iconBg: BetaPalette.qaDangerBg, iconTint: BetaPalette.qaDangerTint,
                              isOn: $showMedication)
                    actionRow(title: "Money", subtitle: "Budget & actuals",
                              icon: "chart.pie", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint,
                              isOn: $showBudget)
                    actionRow(title: "Health check", subtitle: "Book visit",
                              icon: "heart.text.square", iconBg: BetaPalette.qaDangerBg, iconTint: BetaPalette.qaDangerTint,
                              isOn: $showCheckup)
                }

                Section("Navigate") {
                    actionRow(title: "Calendar", subtitle: "See dates",
                              icon: "calendar", iconBg: BetaPalette.qaInfoBg, iconTint: BetaPalette.qaInfoTint,
                              isOn: $showCalendar)
                    actionRow(title: "Statistics", subtitle: "See trends",
                              icon: "chart.bar.xaxis", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint,
                              isOn: $showStatistics)
                    actionRow(title: "Documents", subtitle: "Search files",
                              icon: "doc.text.magnifyingglass", iconBg: BetaPalette.qaWarningBg, iconTint: BetaPalette.qaWarningTint,
                              isOn: $showDocuments)
                    actionRow(title: "Import", subtitle: "From file",
                              icon: "tray.and.arrow.down", iconBg: BetaPalette.qaAccentBg, iconTint: BetaPalette.qaAccentTint,
                              isOn: $showImport)
                    actionRow(title: "Export", subtitle: "Share/AirDrop",
                              icon: "square.and.arrow.up", iconBg: BetaPalette.qaSuccessBg, iconTint: BetaPalette.qaSuccessTint,
                              isOn: $showExport)
                }
            }
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BetaPalette.accent)
                }
            }
        }
    }

    private func actionRow(title: String, subtitle: String, icon: String, iconBg: Color, iconTint: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconBg).frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(iconTint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(BetaPalette.accent)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tab Bar

private struct BetaDashboardTabBar: View {
    @Binding var selectedTab: BetaTab

    private struct Item {
        let tab: BetaTab
        let icon: String
        let selectedIcon: String
        let label: String
    }

    private let items: [Item] = [
        Item(tab: .home, icon: "house", selectedIcon: "house.fill", label: "Home"),
        Item(tab: .tasks, icon: "list.bullet", selectedIcon: "list.bullet", label: "Tasks"),
        Item(tab: .focus, icon: "scope", selectedIcon: "scope", label: "Focus"),
        Item(tab: .habits, icon: "flame", selectedIcon: "flame.fill", label: "Habits"),
        Item(tab: .more, icon: "ellipsis", selectedIcon: "ellipsis", label: "More")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                tabButton(item)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.10), radius: 20, y: 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        }
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = selectedTab == item.tab
        return Button {
            selectedTab = item.tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: isSelected ? item.selectedIcon : item.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? BetaPalette.accent : BetaPalette.tertiaryText)
                Text(item.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? BetaPalette.accent : BetaPalette.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct BetaRecentDocumentRow: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(categoryOption.tint)
                .frame(width: 42, height: 42)
                .background(categoryOption.background, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.documentDisplayName ?? "Document")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)

                Text(task.title)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }
}

private struct BetaSummaryTaskCard: View {
    let task: LifeTask
    let categoryOption: TaskCategoryOption
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.small) {
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.tertiaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 7) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(task.isCompleted ? LifeTrackTheme.ColorPalette.secondaryText : LifeTrackTheme.ColorPalette.primaryText)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)

                WrappingChipLayout(spacing: 7, rowSpacing: 6) {
                    CategoryChipView(option: categoryOption)

                    StatusPillView(
                        title: task.dueDate.dayMonthString,
                        symbolName: task.isOverdue ? "exclamationmark.circle.fill" : "clock",
                        tint: task.isOverdue ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.secondaryText
                    )

                    StatusPillView(
                        title: task.durationTitle,
                        symbolName: "timer",
                        tint: LifeTrackTheme.ColorPalette.secondaryText
                    )

                    if task.priority == .high {
                        StatusPillView(
                            title: "High",
                            symbolName: "flag.fill",
                            tint: TaskPriority.high.tint
                        )
                    }

                    if task.recurrence != .none {
                        StatusPillView(
                            title: task.recurrence.shortTitle,
                            symbolName: "repeat",
                            tint: task.recurrence.tint
                        )
                    }

                    if task.hasDocument {
                        Image(systemName: "paperclip")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .frame(width: 22, height: 22)
                            .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Move to Bin", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(LifeTrackTheme.ColorPalette.backgroundBottom.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.7)
        }
    }
}

private struct HeroPager: View {
    let pages: [AnyView]

    private let cardHeight: CGFloat = 268
    @State private var currentIndex: Int? = 0
    @State private var isDragging: Bool = false
    @State private var lastInteraction: Date = .distantPast

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        pages[index]
                            .frame(height: cardHeight)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentIndex)
            .frame(height: cardHeight + 12)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isDragging { isDragging = true }
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastInteraction = Date()
                    }
            )
            .onChange(of: currentIndex) { _, _ in
                lastInteraction = Date()
            }
            .onReceive(Timer.publish(every: 7, on: .main, in: .common).autoconnect()) { now in
                guard !isDragging else { return }
                guard !pages.isEmpty else { return }
                guard now.timeIntervalSince(lastInteraction) >= 6.5 else { return }
                let current = currentIndex ?? 0
                withAnimation(.easeInOut(duration: 0.45)) {
                    currentIndex = (current + 1) % pages.count
                }
                lastInteraction = now
            }

            HeroPagerDots(currentIndex: currentIndex ?? 0, count: pages.count)
        }
    }
}

private struct HeroPagerDots: View {
    let currentIndex: Int
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == currentIndex ? BetaPalette.accent : BetaPalette.accent.opacity(0.25))
                    .frame(width: i == currentIndex ? 20 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
    }
}
