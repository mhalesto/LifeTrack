//
//  TaskFinancialDetailsSection.swift
//  LifeTrack
//
//  Created by Codex on 2026/04/23.
//

import SwiftUI

struct TaskFinancialDetailsSection: View {
    @Binding var isEnabled: Bool
    @Binding var financialType: TaskFinancialType
    @Binding var plannedAmountText: String
    @Binding var actualAmountText: String
    @Binding var currencyCode: String
    @Binding var budgetCategory: String
    @Binding var hasPaymentDate: Bool
    @Binding var paymentDate: Date
    @Binding var linkOption: MoneyLinkOption
    @Binding var notes: String
    @Binding var includeInMonthlySpending: Bool
    @Binding var markPlannedOnCreate: Bool

    var existingTaskHasActivity: Bool

    var body: some View {
        SectionCardView {
            HStack(alignment: .center, spacing: LifeTrackTheme.Spacing.medium) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Financial Details")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                    InfoTipButton(message: "Optional money tracking for this task.")
                }

                Spacer(minLength: 0)

                Toggle("Enable financial details", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(LifeTrackTheme.ColorPalette.accent)
            }

            if isEnabled {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                    typePicker
                    amountGrid
                    categoryPicker
                    paymentDatePicker
                    linkedBudgetPicker
                    notesField
                    trackingToggles
                    impactPreview
                    if existingTaskHasActivity || plannedAmount > 0 || actualAmount != nil {
                        historyView
                    }
                }
                .padding(.top, LifeTrackTheme.Spacing.small)
            }
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                ForEach(TaskFinancialType.allCases) { type in
                    Button {
                        financialType = type
                    } label: {
                        MoneyOptionPill(
                            title: type.title,
                            symbolName: type.symbolName,
                            tint: type.tint,
                            isSelected: financialType == type
                        )
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
                }
            }
        }
    }

    private var amountGrid: some View {
        VStack(spacing: LifeTrackTheme.Spacing.medium) {
            MoneyAmountField(
                title: "Planned Amount",
                amountText: $plannedAmountText,
                currencyCode: $currencyCode,
                allowsCurrencySelection: false
            )

            MoneyAmountField(
                title: "Actual Amount",
                amountText: $actualAmountText,
                currencyCode: $currencyCode,
                placeholder: "Optional",
                allowsCurrencySelection: false
            )
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Budget Category")
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            Menu {
                ForEach(categoryShortcuts, id: \.self) { option in
                    Button(option) { budgetCategory = option }
                }
            } label: {
                MoneyValueRow(
                    title: budgetCategory.isEmpty ? "Uncategorized" : budgetCategory,
                    value: "Change",
                    symbolName: financialType.symbolName,
                    tint: financialType.tint
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var paymentDatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasPaymentDate) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Payment Date")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text(hasPaymentDate ? paymentDate.dayMonthString : "Use task due date")
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .tint(LifeTrackTheme.ColorPalette.accent)

            if hasPaymentDate {
                DatePicker("Payment Date", selection: $paymentDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
        .padding(12)
        .background(
            LifeTrackTheme.ColorPalette.backgroundTop,
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
        )
    }

    private var linkedBudgetPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Linked Budget or Goal")
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            Picker("Linked Budget or Goal", selection: $linkOption) {
                ForEach(MoneyLinkOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LifeTrackTheme.ColorPalette.backgroundTop,
                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
            )
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Financial Notes")
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            TextField("Optional payment, invoice, or budget notes", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .font(.body)
                .padding(12)
                .background(
                    LifeTrackTheme.ColorPalette.backgroundTop,
                    in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.9), lineWidth: 0.8)
                }
        }
    }

    private var trackingToggles: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $includeInMonthlySpending) {
                Text("Include in monthly spending")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }
            .tint(LifeTrackTheme.ColorPalette.accent)
            .padding(.vertical, 8)

            Divider()

            Toggle(isOn: $markPlannedOnCreate) {
                Text("Mark planned amount when task is created")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            }
            .tint(LifeTrackTheme.ColorPalette.accent)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 12)
        .background(
            LifeTrackTheme.ColorPalette.backgroundTop,
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
        )
    }

    private var impactPreview: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(title: "Impact Preview")

            HStack(spacing: 0) {
                impactColumn(
                    title: budgetCategory.isEmpty ? "Category" : budgetCategory,
                    value: financialType.title,
                    tint: financialType.tint
                )

                Divider()

                impactColumn(
                    title: impactTitle,
                    value: MoneyFormatting.currency(actualAmount ?? plannedAmount, code: currencyCode),
                    tint: financialType.tint
                )

                Divider()

                impactColumn(
                    title: "Variance",
                    value: varianceText,
                    tint: varianceTint
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                financialType.tint.opacity(0.08),
                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
            )
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            SectionHeaderView(title: "History for this task")

            HStack(spacing: 0) {
                historyColumn(title: "Planned", value: MoneyFormatting.currency(plannedAmount, code: currencyCode))
                Divider()
                historyColumn(title: "Actual", value: actualAmount.map { MoneyFormatting.currency($0, code: currencyCode) } ?? "Not logged")
                Divider()
                historyColumn(title: "Difference", value: varianceText)
            }
            .padding(.vertical, 10)
            .background(
                LifeTrackTheme.ColorPalette.backgroundTop,
                in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
            )
        }
    }

    private func impactColumn(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }

    private func historyColumn(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }

    private var plannedAmount: Double {
        parseAmount(plannedAmountText)
    }

    private var actualAmount: Double? {
        let parsed = parseAmount(actualAmountText)
        return parsed > 0 ? parsed : nil
    }

    private var impactTitle: String {
        switch financialType {
        case .expense: "Spent"
        case .income: "Income"
        case .savings: "Saved"
        case .reimbursement: "Reimbursed"
        }
    }

    private var varianceText: String {
        guard let actualAmount else {
            return MoneyFormatting.currency(0, code: currencyCode)
        }
        return MoneyFormatting.signedCurrency(actualAmount - plannedAmount, code: currencyCode)
    }

    private var varianceTint: Color {
        guard let actualAmount else { return LifeTrackTheme.ColorPalette.secondaryText }
        let variance = actualAmount - plannedAmount
        if abs(variance) < 0.01 { return LifeTrackTheme.ColorPalette.secondaryText }
        switch financialType {
        case .expense:
            return variance > 0 ? LifeTrackTheme.ColorPalette.danger : LifeTrackTheme.ColorPalette.success
        case .income, .savings, .reimbursement:
            return variance >= 0 ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.danger
        }
    }

    private var categoryShortcuts: [String] {
        switch financialType {
        case .expense:
            return ["Bills", "Groceries", "Transport", "Health", "Kids", "Lifestyle"]
        case .income:
            return ["Salary", "Freelance", "Business", "Other Income"]
        case .savings:
            return ["Emergency Fund", "Holiday", "Investments", "Debt Buffer"]
        case .reimbursement:
            return ["Claims", "Work Refund", "Medical Refund", "Travel Refund"]
        }
    }

    private func parseAmount(_ value: String) -> Double {
        let normalized = value
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized) ?? 0
    }
}
