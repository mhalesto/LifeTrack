import SwiftUI
import Charts

struct MoneyTrendPoint {
    var label: String
    var value: Double
    var normalized: Double
}

struct MoneyProjectionMetric: View {
    let title: String
    let value: Double
    let currencyCode: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(MoneyFormatting.currency(value, code: currencyCode))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

struct MoneyProjectionChart: View {
    let points: [MoneyProjectionPoint]
    let currencyCode: String
    let lowThreshold: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Text("Cash flow")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text("(Next 30 days)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
                Spacer()
                Text("30 days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Capsule())
            }

            if points.isEmpty {
                MoneyEmptyState(title: "No projection yet", message: "Add income, bills, or entries to build a cash-flow forecast.")
                    .frame(height: 180)
            } else {
                GeometryReader { proxy in
                let values = points.map(\.balance) + [lowThreshold]
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let padding = max((maxValue - minValue) * 0.18, max(abs(maxValue) * 0.04, 1))
                let lowerBound = minValue - padding
                let upperBound = maxValue + padding
                let range = max(upperBound - lowerBound, 1)
                let plotLeft: CGFloat = 54
                let plotTop: CGFloat = 8
                let plotRight: CGFloat = 8
                let plotBottom: CGFloat = 30
                let plotWidth = max(proxy.size.width - plotLeft - plotRight, 1)
                let plotHeight = max(proxy.size.height - plotTop - plotBottom, 1)
                let forecastStartIndex = max(points.count - 6, 1)
                let thresholdRatio = (lowThreshold - lowerBound) / range
                let thresholdY = plotTop + plotHeight - (plotHeight * CGFloat(thresholdRatio))
                let pointPosition: (Int) -> CGPoint = { index in
                    let point = points[index]
                    let x = plotLeft + (points.count <= 1 ? 0 : plotWidth * CGFloat(index) / CGFloat(points.count - 1))
                    let yRatio = (point.balance - lowerBound) / range
                    let y = plotTop + plotHeight - (plotHeight * CGFloat(yRatio))
                    return CGPoint(x: x, y: y)
                }

                ZStack(alignment: .topLeading) {
                    ForEach(0..<5, id: \.self) { index in
                        let ratio = Double(index) / 4
                        let y = plotTop + plotHeight * CGFloat(ratio)
                        let value = upperBound - (range * ratio)

                        Text(axisLabel(for: value))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .frame(width: plotLeft - 6, alignment: .leading)
                            .position(x: (plotLeft - 6) / 2, y: y)

                        Path { path in
                            path.move(to: CGPoint(x: plotLeft, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width - plotRight, y: y))
                        }
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.55), lineWidth: 0.7)
                    }

                    Path { path in
                        guard !points.isEmpty else { return }
                        let first = pointPosition(0)
                        path.move(to: first)
                        for index in points.indices.dropFirst() {
                            path.addLine(to: pointPosition(index))
                        }
                        path.addLine(to: CGPoint(x: pointPosition(points.count - 1).x, y: plotTop + plotHeight))
                        path.addLine(to: CGPoint(x: first.x, y: plotTop + plotHeight))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                LifeTrackTheme.ColorPalette.accent.opacity(0.16),
                                LifeTrackTheme.ColorPalette.accent.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        path.move(to: CGPoint(x: plotLeft, y: thresholdY))
                        path.addLine(to: CGPoint(x: proxy.size.width - plotRight, y: thresholdY))
                    }
                    .stroke(LifeTrackTheme.ColorPalette.secondaryAccent.opacity(0.42), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    Text(axisLabel(for: lowThreshold))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.86), in: Capsule())
                        .position(x: proxy.size.width - 42, y: thresholdY)

                    if points.count > 1 {
                        ForEach(1..<min(points.count, forecastStartIndex + 1), id: \.self) { index in
                            let previous = pointPosition(index - 1)
                            let current = pointPosition(index)
                            let segmentValue = (points[index - 1].balance + points[index].balance) / 2
                            let tint = segmentValue < lowThreshold ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.secondaryAccent

                            Path { path in
                                path.move(to: previous)
                                path.addLine(to: current)
                            }
                            .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        }

                        Path { path in
                            let start = max(forecastStartIndex - 1, 0)
                            path.move(to: pointPosition(start))
                            for index in forecastStartIndex..<points.count {
                                path.addLine(to: pointPosition(index))
                            }
                        }
                        .stroke(LifeTrackTheme.ColorPalette.secondaryAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [6, 6]))
                    }

                    ForEach(0..<5, id: \.self) { labelIndex in
                        let pointIndex = min(points.count - 1, Int((Double(points.count - 1) * Double(labelIndex) / 4.0).rounded()))
                        let position = pointPosition(pointIndex)
                        let label = labelIndex == 0 ? "Today" : points[pointIndex].date.dayMonthString

                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .position(x: position.x, y: proxy.size.height - 6)
                    }

                    if let lastIndex = points.indices.last {
                        let lastPosition = pointPosition(lastIndex)
                        Text(chartMoneyLabel(for: points[lastIndex].balance))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.9), in: Capsule())
                            .position(
                                x: min(max(lastPosition.x, plotLeft + 42), proxy.size.width - 48),
                                y: min(max(lastPosition.y, plotTop + 14), plotTop + plotHeight - 14)
                            )
                    }
                }
                }
                .frame(height: 206)
            }
        }
    }

    private func axisLabel(for value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 1_000 {
            return "\(sign)\(currencySymbol)\(Int((absValue / 1_000).rounded()))K"
        }
        return "\(sign)\(currencySymbol)\(Int(absValue.rounded()))"
    }

    private func chartMoneyLabel(for value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.rounded(.towardZero) == value ? 0 : 2
        formatter.minimumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "\(Int(abs(value)))"
        let sign = value < 0 ? "-" : ""
        return "\(sign)\(currencySymbol)\(formatted)"
    }

    private var currencySymbol: String {
        switch MoneyCurrency.normalized(currencyCode) {
        case "ZAR": return "R"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "AUD": return "A$"
        case "CAD": return "C$"
        case "CHF": return "CHF "
        case "CNY": return "¥"
        case "INR": return "₹"
        case "NGN": return "₦"
        case "KES": return "KSh "
        default: return "\(MoneyCurrency.normalized(currencyCode)) "
        }
    }
}
