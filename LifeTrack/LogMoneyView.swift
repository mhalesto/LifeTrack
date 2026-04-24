//
//  LogMoneyView.swift
//  LifeTrack
//
//  Created by Codex on 2026/04/23.
//

import SwiftData
import SwiftUI

struct LogMoneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LifeTask.dueDate, order: .reverse) private var tasks: [LifeTask]
    @AppStorage(LifeTrackSettings.Keys.moneyCurrencyCode) private var appMoneyCurrencyCode = MoneyCurrency.defaultCode

    @State private var entryType: MoneyTransactionType = .expense
    @State private var dateScope: MoneyDateScope = .day
    @State private var amountText = ""
    @State private var currencyCode = MoneyCurrency.defaultCode
    @State private var category = "Groceries"
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var linkedTaskID: UUID?
    @State private var notes = ""
    @State private var includeInMonthlySpending = true
    @State private var distributeAcrossPeriod = false

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                        header
                        entryTypeCard
                        timeScopeCard
                        detailsCard
                        togglesCard
                        previewCard
                        shortcutsCard
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .tint(LifeTrackTheme.ColorPalette.accent)
        .onAppear {
            currencyCode = MoneyCurrency.normalized(appMoneyCurrencyCode)
        }
        .onChange(of: entryType) { _, newType in
            if let first = categoryShortcuts(for: newType).first {
                category = first
            }
            if newType == .income || newType == .savings || newType == .transfer {
                includeInMonthlySpending = false
            } else {
                includeInMonthlySpending = true
            }
        }
        .onChange(of: dateScope) { _, _ in
            normalizeEndDate()
        }
        .onChange(of: startDate) { _, _ in
            normalizeEndDate()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Log Money")
                .font(.lifeTrack(.title, weight: .bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text("Track what you actually spent, saved, transferred, or earned.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
        }
    }

    private var entryTypeCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Entry Type")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 8)], spacing: 8) {
                ForEach(MoneyTransactionType.allCases) { type in
                    Button {
                        entryType = type
                    } label: {
                        MoneyOptionPill(
                            title: type.title,
                            symbolName: type.symbolName,
                            tint: type.tint,
                            isSelected: entryType == type
                        )
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
                }
            }
        }
    }

    private var timeScopeCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Time Scope", subtitle: "Range, week, and month entries roll up into reports.")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(MoneyDateScope.allCases) { scope in
                    Button {
                        dateScope = scope
                    } label: {
                        MoneyOptionPill(
                            title: scope.title,
                            symbolName: symbolName(for: scope),
                            tint: LifeTrackTheme.ColorPalette.accent,
                            isSelected: dateScope == scope
                        )
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
                }
            }
        }
    }

    private var detailsCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Details")

            MoneyAmountField(
                title: "Amount",
                amountText: $amountText,
                currencyCode: $currencyCode,
                allowsCurrencySelection: false
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("Category")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                Menu {
                    ForEach(categoryShortcuts(for: entryType), id: \.self) { option in
                        Button(option) { category = option }
                    }
                } label: {
                    MoneyValueRow(
                        title: category,
                        value: "Change",
                        symbolName: entryType.symbolName,
                        tint: entryType.tint
                    )
                }
                .buttonStyle(.plain)
            }

            dateControls

            linkedTaskPicker

            VStack(alignment: .leading, spacing: 7) {
                Text("Notes")
                    .font(.lifeTrackCaption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                TextField("Optional context", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.body)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
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
    }

    private var dateControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateScope == .day ? "Date" : "Date Range")
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            DatePicker("Start", selection: $startDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .font(.subheadline.weight(.semibold))

            if showsEndDate {
                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.subheadline.weight(.semibold))
            }
        }
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

    private var linkedTaskPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Linked Task")
                .font(.lifeTrackCaption)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            Picker("Linked Task", selection: $linkedTaskID) {
                Text("No linked task").tag(UUID?.none)
                ForEach(linkableTasks, id: \.id) { task in
                    Text(task.title).tag(Optional(task.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var togglesCard: some View {
        SectionCardView {
            Toggle(isOn: $includeInMonthlySpending) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Include in monthly spending")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text("Expense and debt entries count toward spending totals.")
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .tint(LifeTrackTheme.ColorPalette.accent)

            Divider()

            Toggle(isOn: $distributeAcrossPeriod) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Apply across selected period")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text("Split this amount evenly across the selected days in analytics.")
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }
            .tint(LifeTrackTheme.ColorPalette.accent)
            .disabled(dateScope == .day)
        }
    }

    private var previewCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Smart Preview")

            VStack(spacing: 8) {
                MoneyValueRow(
                    title: "This month",
                    value: MoneyFormatting.currency(preview.monthlySpendingDelta, code: currencyCode),
                    symbolName: "calendar",
                    tint: entryType.tint,
                    subtitle: preview.monthlySpendingDelta > 0 ? "Added to spending" : "No spending impact"
                )

                MoneyValueRow(
                    title: "This week",
                    value: MoneyFormatting.currency(preview.weeklySpendingDelta, code: currencyCode),
                    symbolName: "chart.bar",
                    tint: LifeTrackTheme.ColorPalette.secondaryAccent,
                    subtitle: dateScope.title
                )

                MoneyValueRow(
                    title: category,
                    value: MoneyFormatting.currency(preview.categoryDelta, code: currencyCode),
                    symbolName: entryType.symbolName,
                    tint: entryType.tint,
                    subtitle: "Category movement"
                )

                if entryType == .savings {
                    MoneyValueRow(
                        title: "Savings",
                        value: MoneyFormatting.currency(preview.savingsDelta, code: currencyCode),
                        symbolName: "banknote",
                        tint: LifeTrackTheme.ColorPalette.accent,
                        subtitle: "Savings progress"
                    )
                }
            }
        }
    }

    private var shortcutsCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Quick Shortcuts")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 8)], spacing: 8) {
                ForEach(categoryShortcuts(for: entryType), id: \.self) { option in
                    Button {
                        category = option
                    } label: {
                        MoneyOptionPill(
                            title: option,
                            symbolName: entryType.symbolName,
                            tint: option == category ? entryType.tint : LifeTrackTheme.ColorPalette.secondaryAccent,
                            isSelected: option == category
                        )
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.92))
                }
            }
        }
    }

    private var amount: Double {
        let normalized = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized) ?? 0
    }

    private var canSave: Bool {
        amount > 0 && !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsEndDate: Bool {
        dateScope == .range || dateScope == .custom
    }

    private var effectiveEndDate: Date? {
        showsEndDate ? max(startDate, endDate) : nil
    }

    private var linkableTasks: [LifeTask] {
        tasks
            .filter { !$0.isDeleted }
            .prefix(40)
            .map { $0 }
    }

    private var selectedTask: LifeTask? {
        guard let linkedTaskID else { return nil }
        return tasks.first { $0.id == linkedTaskID }
    }

    private var preview: MoneyImpactPreview {
        MoneyAnalytics.impactPreview(
            type: entryType,
            amount: amount,
            category: category,
            startDate: startDate,
            endDate: effectiveEndDate,
            dateScope: dateScope,
            includeInMonthlySpending: includeInMonthlySpending,
            distributeAcrossPeriod: distributeAcrossPeriod,
            currencyCode: currencyCode
        )
    }

    private func save() {
        guard canSave else { return }
        let cleanedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrency = MoneyCurrency.normalized(appMoneyCurrencyCode)
        currencyCode = normalizedCurrency
        let now = Date()
        let entry = MoneyEntry(
            type: entryType,
            amount: amount,
            currencyCode: normalizedCurrency,
            category: cleanedCategory,
            dateScope: dateScope,
            startDate: startDate,
            endDate: effectiveEndDate,
            linkedTaskId: linkedTaskID,
            notes: notes,
            includeInMonthlySpending: includeInMonthlySpending,
            distributeAcrossPeriod: distributeAcrossPeriod,
            source: linkedTaskID == nil ? .manual : .task,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(entry)

        if let selectedTask {
            selectedTask.financialEnabled = true
            selectedTask.financialType = taskFinancialType(for: entryType)
            selectedTask.actualAmount = amount
            selectedTask.currencyCode = normalizedCurrency
            selectedTask.budgetCategory = cleanedCategory
            selectedTask.paymentDate = startDate
            selectedTask.includeInMonthlySpending = includeInMonthlySpending
            selectedTask.financialNotes = notes
            selectedTask.updatedAt = now
        }

        try? modelContext.save()
        LifeTrackHaptics.lightImpact()
        dismiss()
    }

    private func normalizeEndDate() {
        if showsEndDate && endDate < startDate {
            endDate = startDate
        }
    }

    private func symbolName(for scope: MoneyDateScope) -> String {
        switch scope {
        case .day: "calendar"
        case .range: "calendar.badge.clock"
        case .week: "chart.bar"
        case .month: "calendar.circle"
        case .custom: "ellipsis"
        }
    }

    private func taskFinancialType(for entryType: MoneyTransactionType) -> TaskFinancialType {
        switch entryType {
        case .expense, .transfer, .debtPayment:
            return .expense
        case .income:
            return .income
        case .savings:
            return .savings
        }
    }

    private func categoryShortcuts(for type: MoneyTransactionType) -> [String] {
        switch type {
        case .expense:
            return ["Groceries", "Transport", "Bills", "Kids", "Lifestyle", "Health"]
        case .income:
            return ["Salary", "Freelance", "Business", "Reimbursement", "Other Income"]
        case .savings:
            return ["Emergency Fund", "Holiday", "Investments", "New Laptop", "Buffer"]
        case .transfer:
            return ["Bank Transfer", "Wallet", "Credit Card", "Investment Account"]
        case .debtPayment:
            return ["Credit Card", "Store Account", "Loan", "Vehicle Finance"]
        }
    }
}
