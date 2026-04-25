import Foundation
import SwiftUI

struct MoneyDeductionDraft: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amountText: String
}

struct MoneyIncomeEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let month: Date
    let summary: MoneyMonthlySummary
    let onSave: (Double, Double, String, String, Date, String) -> Void

    @State private var plannedText: String
    @State private var grossText: String
    @State private var currencyCode: String
    @State private var category = "Income"
    @State private var paymentDate: Date
    @State private var notes = "Monthly income"
    @State private var deductions: [MoneyDeductionDraft] = [
        MoneyDeductionDraft(title: "Tax", amountText: "")
    ]

    init(
        month: Date,
        currencyCode: String,
        summary: MoneyMonthlySummary,
        onSave: @escaping (Double, Double, String, String, Date, String) -> Void
    ) {
        self.month = month
        self.summary = summary
        self.onSave = onSave
        _plannedText = State(initialValue: Self.amountInputString(summary.plannedIncome))
        _grossText = State(initialValue: Self.amountInputString(summary.actualIncome))
        _currencyCode = State(initialValue: MoneyCurrency.normalized(currencyCode))
        _paymentDate = State(initialValue: month)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Edit Income")
                                .font(.lifeTrackHero)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            Text("Set planned income for forecasting and actual income for monthly reports.")
                                .font(.subheadline)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        SectionCardView {
                            MoneyAmountField(
                                title: "Planned income",
                                amountText: $plannedText,
                                currencyCode: $currencyCode,
                                allowsCurrencySelection: false
                            )
                            MoneyAmountField(
                                title: "Gross income",
                                amountText: $grossText,
                                currencyCode: $currencyCode,
                                allowsCurrencySelection: false
                            )

                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    Text("Monthly deductions")
                                        .font(.lifeTrackCaption)
                                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                    Spacer()
                                    Button {
                                        deductions.append(MoneyDeductionDraft(title: "Deduction", amountText: ""))
                                    } label: {
                                        Label("Add", systemImage: "plus")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                    }
                                    .buttonStyle(.plain)
                                }

                                VStack(spacing: 8) {
                                    ForEach($deductions) { $deduction in
                                        HStack(spacing: 8) {
                                            TextField("Name", text: $deduction.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                                .tint(LifeTrackTheme.ColorPalette.accent)
                                                .textFieldStyle(.plain)

                                            TextField("0", text: $deduction.amountText)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                                .keyboardType(.decimalPad)
                                                .multilineTextAlignment(.trailing)
                                                .tint(LifeTrackTheme.ColorPalette.accent)
                                                .textFieldStyle(.plain)
                                                .frame(width: 94)

                                            Button {
                                                deductions.removeAll { $0.id == deduction.id }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.system(size: 17, weight: .semibold))
                                                    .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                                    }
                                }
                            }

                            MoneyValueRow(
                                title: "Net actual income",
                                value: MoneyFormatting.currency(netActualIncome, code: currencyCode),
                                symbolName: "equal.circle",
                                tint: LifeTrackTheme.ColorPalette.success,
                                subtitle: "Gross minus monthly deductions"
                            )

                            VStack(alignment: .leading, spacing: 7) {
                                Text("Category")
                                    .font(.lifeTrackCaption)
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                TextField("Income", text: $category)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                    .tint(LifeTrackTheme.ColorPalette.accent)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                            }

                            DatePicker("Payment date", selection: $paymentDate, displayedComponents: .date)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                .padding(11)
                                .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))

                            VStack(alignment: .leading, spacing: 7) {
                                Text("Notes")
                                    .font(.lifeTrackCaption)
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                TextField("Optional note", text: $notes, axis: .vertical)
                                    .lineLimit(2...4)
                                    .font(.body)
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                    .tint(LifeTrackTheme.ColorPalette.accent)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                            }
                        }

                        SectionCardView {
                            SectionHeaderView(title: "Preview", subtitle: MoneyAnalytics.monthTitle(for: month))
                            MoneyValueRow(
                                title: "Forecast income",
                                value: MoneyFormatting.currency(parseAmount(plannedText), code: currencyCode),
                                symbolName: "calendar.badge.clock",
                                tint: LifeTrackTheme.ColorPalette.accent
                            )
                            MoneyValueRow(
                                title: "Actual income",
                                value: MoneyFormatting.currency(netActualIncome, code: currencyCode),
                                symbolName: "arrow.down.circle",
                                tint: LifeTrackTheme.ColorPalette.success
                            )
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(parseAmount(plannedText), netActualIncome, currencyCode, category, paymentDate, notesWithBreakdown)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func parseAmount(_ value: String) -> Double {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: #"[^0-9,.\-]"#, with: "", options: .regularExpression)
        if cleaned.filter({ $0 == "," }).count == 1, !cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        return max(Double(cleaned) ?? 0, 0)
    }

    private var totalDeductions: Double {
        deductions.reduce(0) { partial, deduction in
            partial + parseAmount(deduction.amountText)
        }
    }

    private var netActualIncome: Double {
        max(parseAmount(grossText) - totalDeductions, 0)
    }

    private var notesWithBreakdown: String {
        let cleanedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let deductionLines = deductions
            .map { (title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines), amount: parseAmount($0.amountText)) }
            .filter { !$0.title.isEmpty && $0.amount > 0 }
            .map { "\($0.title): \(MoneyFormatting.currency($0.amount, code: currencyCode))" }

        var parts: [String] = []
        if !cleanedNotes.isEmpty {
            parts.append(cleanedNotes)
        }
        if parseAmount(grossText) > 0 {
            parts.append("Gross income: \(MoneyFormatting.currency(parseAmount(grossText), code: currencyCode))")
        }
        if !deductionLines.isEmpty {
            parts.append("Deductions: \(deductionLines.joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }

    private static func amountInputString(_ amount: Double) -> String {
        guard amount > 0 else { return "" }
        if amount.rounded(.down) == amount {
            return String(Int(amount))
        }
        return String(format: "%.2f", amount)
    }
}

