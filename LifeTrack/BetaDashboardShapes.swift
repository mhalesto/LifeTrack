//
//  BetaDashboardShapes.swift
//  LifeTrack
//
//  Pure `Shape` and data types extracted from BetaDashboardView.
//

import SwiftUI

struct BetaMetricTrends {
    var dueToday: [Double]
    var upcoming: [Double]
    var completed: [Double]
    var overdue: [Double]
}

struct StatSparkline: Shape {
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

struct StatWave: Shape {
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
            let envelope = sin(relative * .pi)
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

struct PedestalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
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
            control1: CGPoint(x: w * -0.02, y: h * 0.86),
            control2: CGPoint(x: w * 0.02, y: h * 0.68)
        )
        path.closeSubpath()
        return path
    }
}

struct FlameShape: Shape {
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

struct MountainShape: Shape {
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

struct BetaLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

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
