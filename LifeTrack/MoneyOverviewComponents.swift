//
//  MoneyOverviewComponents.swift
//  LifeTrack
//
//  Small reusable views for MoneyOverviewView: summary cards, bill rows,
//  category rows, entry rows, and the comparison bar. Extracted to keep
//  MoneyOverviewView focused on layout and state.
//

import SwiftUI

struct MoneySummaryCard: View {
    let title: String
    let value: Double
    let previousValue: Double
    let currencyCode: String
    let subtitle: String
    let symbolName: String
    let tint: Color
    var accessorySymbolName: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                    .background(tint.opacity(0.12), in: Circle())
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let accessorySymbolName {
                    Image(systemName: accessorySymbolName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                }
            }

            Text(MoneyFormatting.currency(value, code: currencyCode))
                .font(.title3.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            Text(deltaText)
                .font(.caption.weight(.bold))
                .foregroundStyle(deltaTint)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(deltaTint.opacity(0.10), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LifeTrackTheme.Spacing.medium)
        .background(LifeTrackTheme.ColorPalette.cardElevated, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous))
        .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(0.8), radius: 10, x: 0, y: 6)
    }

    private var deltaText: String {
        MoneyFormatting.signedCurrency(value - previousValue, code: currencyCode) + " vs prev"
    }

    private var deltaTint: Color {
        value - previousValue >= 0 ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.warning
    }
}

struct MoneyComparisonBar: View {
    let title: String
    let planned: Double
    let actual: Double
    let currencyCode: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Spacer()
                Text("Plan \(MoneyFormatting.currency(planned, code: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                Text("Actual \(MoneyFormatting.currency(actual, code: currencyCode))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let maxValue = max(planned, actual, 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LifeTrackTheme.ColorPalette.hairline.opacity(0.55))
                        .frame(height: 9)
                    Capsule()
                        .fill(tint.opacity(0.30))
                        .frame(width: width * (planned / maxValue), height: 9)
                    Capsule()
                        .fill(tint)
                        .frame(width: width * (actual / maxValue), height: 5)
                }
            }
            .frame(height: 10)
        }
    }
}

struct MoneyCategoryRow: View {
    let total: MoneyCategoryTotal
    let maxAmount: Double
    var carryIn: Double = 0

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: total.kind.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(total.kind.tint)
                .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                .background(total.kind.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(total.category)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    if carryIn > 0 {
                        Text("+\(MoneyFormatting.currency(carryIn, code: total.currencyCode)) rolled over")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LifeTrackTheme.ColorPalette.success.opacity(0.12), in: Capsule())
                    }
                    Spacer()
                    Text(MoneyFormatting.currency(total.actual, code: total.currencyCode))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                }

                GeometryReader { proxy in
                    let adjustedPlanned = max(total.planned + carryIn, 0)
                    let denominator = max(adjustedPlanned, max(total.actual, maxAmount))
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(LifeTrackTheme.ColorPalette.hairline.opacity(0.5))
                        if adjustedPlanned > 0 {
                            Capsule()
                                .fill(total.kind.tint.opacity(0.25))
                                .frame(width: proxy.size.width * min(max(adjustedPlanned / denominator, 0), 1))
                        }
                        Capsule()
                            .fill(total.kind.tint)
                            .frame(width: proxy.size.width * min(max(total.actual / denominator, 0), 1))
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

struct MoneyCompactEmptyState: View {
    let title: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "tray")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 118)
    }
}

struct MoneyCompactBillRow: View {
    let bill: MoneyBillSnapshot
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 8) {
                Image(systemName: bill.status == .paid ? "checkmark.circle.fill" : "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: 32, height: 32)
                    .background(statusTint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                    Text(bill.dueDate.dayMonthString)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(MoneyFormatting.currency(bill.actualAmount ?? bill.plannedAmount, code: bill.currencyCode))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var statusTint: Color {
        switch bill.status {
        case .paid: LifeTrackTheme.ColorPalette.success
        case .upcoming: LifeTrackTheme.ColorPalette.accent
        case .atRisk: LifeTrackTheme.ColorPalette.danger
        }
    }
}

struct MoneyCompactCategoryRow: View {
    let total: MoneyCategoryTotal
    let maxAmount: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: total.kind.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(total.kind.tint)
                .frame(width: 32, height: 32)
                .background(total.kind.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(total.category)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Spacer(minLength: 0)

                    Text(percentText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(1)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(LifeTrackTheme.ColorPalette.hairline.opacity(0.5))
                        Capsule()
                            .fill(total.kind.tint)
                            .frame(width: proxy.size.width * min(max(total.actual / maxAmount, 0), 1))
                    }
                }
                .frame(height: 6)

                Text(MoneyFormatting.currency(total.actual, code: total.currencyCode))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var percentText: String {
        let percent = Int((total.actual / max(maxAmount, 1) * 100).rounded())
        return "\(percent)%"
    }
}

struct MoneyBillRow: View {
    let bill: MoneyBillSnapshot
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: bill.status == .paid ? "checkmark.circle.fill" : "calendar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                    .background(statusTint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(bill.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text("Due \(bill.dueDate.dayMonthString) · \(bill.category)")
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(MoneyFormatting.currency(bill.actualAmount ?? bill.plannedAmount, code: bill.currencyCode))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text(bill.status.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(statusTint.opacity(0.12), in: Capsule())
                }
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private var statusTint: Color {
        switch bill.status {
        case .paid: LifeTrackTheme.ColorPalette.success
        case .upcoming: LifeTrackTheme.ColorPalette.accent
        case .atRisk: LifeTrackTheme.ColorPalette.danger
        }
    }
}

struct MoneyEntryRow: View {
    let entry: MoneyEntry

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: entry.type.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(entry.type.tint)
                .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                .background(entry.type.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.notes.isEmpty ? entry.category : entry.notes)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                Text("\(entry.category) · \(entry.source.title)")
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                Text(signedAmount)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(amountTint)
                Text(entry.startDate.dayMonthString)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
        }
        .padding(.vertical, 9)
    }

    private var signedAmount: String {
        let sign: Double
        switch entry.type {
        case .expense, .debtPayment:
            sign = -entry.amount
        case .income, .savings, .transfer:
            sign = entry.amount
        }
        return MoneyFormatting.signedCurrency(sign, code: entry.currencyCode)
    }

    private var amountTint: Color {
        switch entry.type {
        case .expense, .debtPayment:
            LifeTrackTheme.ColorPalette.danger
        case .income, .savings:
            LifeTrackTheme.ColorPalette.success
        case .transfer:
            LifeTrackTheme.ColorPalette.secondaryText
        }
    }
}

struct MoneySubscriptionRow: View {
    let suggestion: MoneySubscriptionSuggestion
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "repeat.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryAccent)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(suggestion.cadence.title) · seen \(suggestion.occurrences)×")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                Text(MoneyFormatting.currency(suggestion.averageAmount, code: suggestion.currencyCode))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                HStack(spacing: 8) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .frame(width: 28, height: 28)
                            .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text("Track")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(LifeTrackTheme.ColorPalette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

struct MoneyBillStatusPill: View {
    let title: String
    let count: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Text("\(count)")
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
    }
}
