//
//  MoneyOverviewView.swift
//  LifeTrack
//
//  Created by Codex on 2026/04/23.
//

import SwiftData
import SwiftUI

struct MoneyOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoneyEntry.startDate, order: .reverse) private var entries: [MoneyEntry]
    @Query(sort: \LifeTask.dueDate, order: .forward) private var tasks: [LifeTask]

    @State private var selectedTab: MoneyOverviewTab = .overview
    @State private var selectedReportTab: MoneyReportTab = .overview
    @State private var selectedMonth = Date()
    @State private var currencyCode = MoneyCurrency.defaultCode
    @State private var isShowingLogMoney = false
    @State private var isShowingIncomeEditor = false
    @State private var editingTask: LifeTask?

    var body: some View {
        ZStack {
            LifeTrackTheme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                    header
                    controlsCard
                    tabSelector

                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .entries:
                        entriesContent
                    case .bills:
                        billsContent
                    case .reports:
                        reportsContent
                    }

                    Button(action: { isShowingLogMoney = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                            Text("Log Money")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LifeTrackTheme.ColorPalette.accentGradient, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.large)
                .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingLogMoney) {
            LogMoneyView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingIncomeEditor) {
            MoneyIncomeEditorView(
                month: selectedMonth,
                currencyCode: currencyCode,
                summary: summary,
                onSave: saveIncomePlan
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingTask) { task in
            NewTaskView(task: task)
        }
        .onAppear {
            MoneySeedData.seedIfNeeded(modelContext: modelContext, entries: entries, tasks: tasks)
            currencyCode = MoneyCurrency.primaryCurrencyCode(entries: entries, tasks: tasks)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedTab == .reports ? "Monthly Report" : "Money Overview")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

            Text(selectedTab == .reports ? "See how money moved this month." : "Track actual spending, stay on plan, and build your future.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controlsCard: some View {
        SectionCardView {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92))

                VStack(alignment: .leading, spacing: 2) {
                    Text(MoneyAnalytics.monthTitle(for: selectedMonth))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    if availableCurrencies.count > 1 {
                        Text("Showing \(MoneyCurrency.normalized(currencyCode)) only")
                            .font(.caption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                }

                Spacer(minLength: 0)

                MoneyCurrencyPicker(currencyCode: $currencyCode)

                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Circle())
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.92))
            }
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 6) {
            ForEach(MoneyOverviewTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(selectedTab == tab ? Color.white : LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(tabBackground(isSelected: selectedTab == tab), in: Capsule())
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97, pressedOpacity: 0.92))
            }
        }
        .padding(5)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.82), in: Capsule())
        .overlay {
            Capsule()
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            budgetProjectionCard
            summaryGrid
            plannedVsActualCard
            overviewTwoColumn
            recentEntriesCard(limit: 5)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LifeTrackTheme.Spacing.medium) {
            Button { isShowingIncomeEditor = true } label: {
                MoneySummaryCard(
                    title: "Income",
                    value: summary.actualIncome,
                    previousValue: previousSummary.actualIncome,
                    currencyCode: currencyCode,
                    subtitle: "Tap to edit",
                    symbolName: "arrow.down.circle",
                    tint: LifeTrackTheme.ColorPalette.success,
                    accessorySymbolName: "pencil"
                )
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.985, pressedOpacity: 0.96))
            MoneySummaryCard(
                title: "Spent",
                value: summary.actualSpending,
                previousValue: previousSummary.actualSpending,
                currencyCode: currencyCode,
                subtitle: "This month",
                symbolName: "arrow.up.circle",
                tint: LifeTrackTheme.ColorPalette.danger
            )
            MoneySummaryCard(
                title: "Saved",
                value: summary.actualSavings,
                previousValue: previousSummary.actualSavings,
                currencyCode: currencyCode,
                subtitle: "This month",
                symbolName: "banknote",
                tint: LifeTrackTheme.ColorPalette.accent
            )
            MoneySummaryCard(
                title: "Remaining",
                value: summary.actualRemaining,
                previousValue: previousSummary.actualRemaining,
                currencyCode: currencyCode,
                subtitle: "Left to allocate",
                symbolName: "wallet.pass",
                tint: LifeTrackTheme.ColorPalette.warning
            )
        }
    }

    private var budgetProjectionCard: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Budget Projection")
                            .font(.lifeTrackHeadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        Text("Projected month-end balance")
                            .font(.footnote)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                        Text(MoneyFormatting.currency(projectedMonthEndBalance, code: currencyCode))
                            .font(.system(.largeTitle, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text(MoneyFormatting.signedCurrency(projectedMonthEndBalance - previousSummary.actualRemaining, code: currencyCode) + " vs prev month")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.success)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(LifeTrackTheme.ColorPalette.success.opacity(0.10), in: Capsule())
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        .frame(width: 74, height: 74)
                        .background(LifeTrackTheme.ColorPalette.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Divider()

                HStack(spacing: 0) {
                    MoneyProjectionMetric(
                        title: "Income",
                        value: summary.plannedIncome > 0 ? summary.plannedIncome : summary.actualIncome,
                        currencyCode: currencyCode,
                        symbolName: "arrow.up",
                        tint: LifeTrackTheme.ColorPalette.success
                    )
                    Divider().frame(height: 46)
                    MoneyProjectionMetric(
                        title: "Planned expenses",
                        value: summary.plannedSpending,
                        currencyCode: currencyCode,
                        symbolName: "arrow.down",
                        tint: LifeTrackTheme.ColorPalette.danger
                    )
                    Divider().frame(height: 46)
                    MoneyProjectionMetric(
                        title: "Savings forecast",
                        value: summary.plannedSavings,
                        currencyCode: currencyCode,
                        symbolName: "chart.bar",
                        tint: LifeTrackTheme.ColorPalette.accent
                    )
                }

                MoneyProjectionChart(points: projectionPoints, currencyCode: currencyCode)
            }
        }
    }

    private var plannedVsActualCard: some View {
        SectionCardView {
            SectionHeaderView(
                title: "Planned vs Actual",
                subtitle: "Forecasted money compared with what actually happened."
            )

            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                MoneyComparisonBar(
                    title: "Spend",
                    planned: summary.plannedSpending,
                    actual: summary.actualSpending,
                    currencyCode: currencyCode,
                    tint: LifeTrackTheme.ColorPalette.danger
                )
                MoneyComparisonBar(
                    title: "Saved",
                    planned: summary.plannedSavings,
                    actual: summary.actualSavings,
                    currencyCode: currencyCode,
                    tint: LifeTrackTheme.ColorPalette.accent
                )
                MoneyComparisonBar(
                    title: "Income",
                    planned: summary.plannedIncome,
                    actual: summary.actualIncome,
                    currencyCode: currencyCode,
                    tint: LifeTrackTheme.ColorPalette.success
                )
            }
        }
    }

    private var overviewTwoColumn: some View {
        VStack(spacing: LifeTrackTheme.Spacing.medium) {
            spendingByCategoryCard(limit: 5)
            plannedBillsCard(limit: 4)
        }
    }

    private func spendingByCategoryCard(limit: Int? = nil) -> some View {
        SectionCardView {
            SectionHeaderView(title: "Spending by Category", subtitle: "Actual spending breakdown.")

            let rows = Array(spendingCategoryTotals.prefix(limit ?? spendingCategoryTotals.count))
            if rows.isEmpty {
                MoneyEmptyState(title: "No spending yet", message: "Log an expense to start category tracking.")
            } else {
                VStack(spacing: 9) {
                    ForEach(rows) { total in
                        MoneyCategoryRow(total: total, maxAmount: maxSpendingCategoryAmount)
                    }
                }
            }
        }
    }

    private func plannedBillsCard(limit: Int? = nil) -> some View {
        SectionCardView {
            SectionHeaderView(title: "Planned Bills", subtitle: "Upcoming and paid finance tasks.")

            let rows = Array(plannedBills.prefix(limit ?? plannedBills.count))
            if rows.isEmpty {
                MoneyEmptyState(title: "No planned bills", message: "Add financial details to a task to see bills here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { bill in
                        MoneyBillRow(bill: bill) {
                            editingTask = tasks.first { $0.id == bill.id }
                        }
                        if bill.id != rows.last?.id {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
            }
        }
    }

    private func recentEntriesCard(limit: Int? = nil) -> some View {
        SectionCardView {
            SectionHeaderView(title: "Recent Money Entries", subtitle: "Manual, task-linked, recurring, and imported activity.")

            let rows = Array(entriesForMonth.prefix(limit ?? entriesForMonth.count))
            if rows.isEmpty {
                MoneyEmptyState(title: "No entries yet", message: "Use Log Money for actual spending, income, and savings.")
            } else {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.id) { entry in
                        MoneyEntryRow(entry: entry)
                        if entry.id != rows.last?.id {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
            }
        }
    }

    private var entriesContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            recentEntriesCard()
        }
    }

    private var billsContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            billsSummaryCard
            plannedBillsCard()
        }
    }

    private var billsSummaryCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Bills This Month")

            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                MoneyBillStatusPill(title: "Paid", count: plannedBills.filter { $0.status == .paid }.count, tint: LifeTrackTheme.ColorPalette.success)
                MoneyBillStatusPill(title: "Upcoming", count: plannedBills.filter { $0.status == .upcoming }.count, tint: LifeTrackTheme.ColorPalette.accent)
                MoneyBillStatusPill(title: "At Risk", count: plannedBills.filter { $0.status == .atRisk }.count, tint: LifeTrackTheme.ColorPalette.danger)
            }

            MoneyValueRow(
                title: "Total planned",
                value: MoneyFormatting.currency(plannedBills.reduce(0) { $0 + $1.plannedAmount }, code: currencyCode),
                symbolName: "calendar.badge.clock",
                tint: LifeTrackTheme.ColorPalette.accent
            )
        }
    }

    private var reportsContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            reportTabSelector
            summaryGrid

            switch selectedReportTab {
            case .overview:
                plannedVsActualCard
                insightsCard
                recentEntriesCard(limit: 5)
            case .categories:
                spendingByCategoryCard()
            case .trends:
                trendsCard
            case .entries:
                recentEntriesCard()
            }
        }
    }

    private var reportTabSelector: some View {
        HStack(spacing: 6) {
            ForEach(MoneyReportTab.allCases) { tab in
                Button {
                    selectedReportTab = tab
                } label: {
                    Text(tab.title)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(selectedReportTab == tab ? Color.white : LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(tabBackground(isSelected: selectedReportTab == tab), in: Capsule())
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.97, pressedOpacity: 0.92))
            }
        }
        .padding(5)
        .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.82), in: Capsule())
    }

    private var insightsCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Insights")

            VStack(spacing: 9) {
                ForEach(insights, id: \.self) { insight in
                    HStack(spacing: LifeTrackTheme.Spacing.medium) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                            .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                            .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())
                        Text(insight)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(11)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                }
            }
        }
    }

    private var trendsCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Weekly Trends", subtitle: "Actual spending by week in \(MoneyAnalytics.monthTitle(for: selectedMonth)).")

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(weeklyTrendPoints, id: \.label) { point in
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(LifeTrackTheme.ColorPalette.accentGradient)
                            .frame(height: max(12, 124 * point.normalized))
                        Text(point.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 160, alignment: .bottom)
        }
    }

    private var summary: MoneyMonthlySummary {
        MoneyAnalytics.monthlySummary(for: selectedMonth, entries: entries, tasks: tasks, currencyCode: currencyCode)
    }

    private var previousSummary: MoneyMonthlySummary {
        let previous = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        return MoneyAnalytics.monthlySummary(for: previous, entries: entries, tasks: tasks, currencyCode: currencyCode)
    }

    private var availableCurrencies: [String] {
        MoneyAnalytics.availableCurrencies(entries: entries, tasks: tasks)
    }

    private var entriesForMonth: [MoneyEntry] {
        let interval = MoneyAnalytics.monthInterval(containing: selectedMonth)
        let normalizedCurrency = MoneyCurrency.normalized(currencyCode)
        return entries.filter {
            MoneyCurrency.normalized($0.currencyCode) == normalizedCurrency &&
            MoneyAnalytics.amount(for: $0, in: interval) > 0
        }
    }

    private var categoryTotals: [MoneyCategoryTotal] {
        MoneyAnalytics.categoryTotals(for: selectedMonth, entries: entries, tasks: tasks, currencyCode: currencyCode)
    }

    private var spendingCategoryTotals: [MoneyCategoryTotal] {
        categoryTotals
            .filter { $0.kind == .expense || $0.kind == .debtPayment }
            .filter { $0.actual > 0 || $0.planned > 0 }
    }

    private var maxSpendingCategoryAmount: Double {
        max(spendingCategoryTotals.map { max($0.actual, $0.planned) }.max() ?? 0, 1)
    }

    private var plannedBills: [MoneyBillSnapshot] {
        MoneyAnalytics.plannedBills(for: selectedMonth, tasks: tasks, currencyCode: currencyCode)
    }

    private var insights: [String] {
        var values: [String] = []
        if summary.spendingVariance < 0 {
            values.append("You spent \(MoneyFormatting.currency(abs(summary.spendingVariance), code: currencyCode)) less than planned.")
        } else if summary.spendingVariance > 0 {
            values.append("Spending is \(MoneyFormatting.currency(summary.spendingVariance, code: currencyCode)) over plan.")
        }
        if summary.savingsVariance > 0 {
            values.append("You saved \(MoneyFormatting.currency(summary.savingsVariance, code: currencyCode)) more than planned.")
        }
        values.append("Left over: \(MoneyFormatting.currency(summary.actualRemaining, code: currencyCode)).")
        if let biggest = spendingCategoryTotals.max(by: { $0.actual < $1.actual }) {
            values.append("Biggest spending category: \(biggest.category).")
        }
        return values
    }

    private var weeklyTrendPoints: [MoneyTrendPoint] {
        let calendar = Calendar.current
        let interval = MoneyAnalytics.monthInterval(containing: selectedMonth, calendar: calendar)
        let weeks = (0..<5).compactMap { offset -> Date? in
            calendar.date(byAdding: .weekOfYear, value: offset, to: interval.start)
        }
        let values = weeks.map {
            MoneyAnalytics.weeklySpending(for: $0, entries: entries, tasks: tasks, currencyCode: currencyCode, calendar: calendar)
        }
        let maxValue = max(values.max() ?? 0, 1)
        return values.enumerated().map { index, value in
            MoneyTrendPoint(label: "W\(index + 1)", value: value, normalized: value / maxValue)
        }
    }

    private var projectedMonthEndBalance: Double {
        projectionPoints.last?.balance ?? summary.actualRemaining
    }

    private var projectionPoints: [MoneyProjectionPoint] {
        MoneyAnalytics.projectionPoints(
            from: Date(),
            days: 30,
            entries: entries,
            tasks: tasks,
            currencyCode: currencyCode
        )
    }

    private func shiftMonth(_ offset: Int) {
        selectedMonth = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) ?? selectedMonth
    }

    private func saveIncomePlan(plannedAmount: Double, actualAmount: Double, currencyCode: String, category: String, paymentDate: Date, notes: String) {
        let cleanedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Income" : category.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let interval = MoneyAnalytics.monthInterval(containing: selectedMonth)
        let normalizedCurrency = MoneyCurrency.normalized(currencyCode)
        self.currencyCode = normalizedCurrency
        let now = Date()

        let existingPlan = tasks.first {
            $0.financialEnabled &&
            !$0.isDeleted &&
            $0.financialType == .income &&
            MoneyCurrency.normalized($0.currencyCode) == normalizedCurrency &&
            MoneyAnalytics.intervalContains(interval, $0.paymentDate ?? $0.dueDate)
        }

        if plannedAmount > 0 || existingPlan != nil {
            let task = existingPlan ?? LifeTask(
                title: "Monthly income plan",
                category: .finance,
                dueDate: paymentDate,
                notes: "Planned income for \(MoneyAnalytics.monthTitle(for: selectedMonth)).",
                recurrence: .monthly,
                estimatedDurationMinutes: 15,
                financialEnabled: true,
                financialType: .income,
                currencyCode: normalizedCurrency,
                budgetCategory: cleanedCategory,
                paymentDate: paymentDate,
                includeInMonthlySpending: false,
                markPlannedOnCreate: true,
                createdAt: now,
                updatedAt: now
            )

            task.financialEnabled = true
            task.financialType = .income
            task.plannedAmount = plannedAmount
            task.currencyCode = normalizedCurrency
            task.budgetCategory = cleanedCategory
            task.paymentDate = paymentDate
            task.dueDate = paymentDate
            task.includeInMonthlySpending = false
            task.markPlannedOnCreate = true
            task.financialNotes = cleanedNotes
            task.updatedAt = now

            if existingPlan == nil {
                modelContext.insert(task)
            }
        }

        let existingActual = entries.first {
            $0.type == .income &&
            MoneyCurrency.normalized($0.currencyCode) == normalizedCurrency &&
            MoneyAnalytics.amount(for: $0, in: interval) > 0 &&
            ($0.notes.localizedCaseInsensitiveContains("income") || $0.category.localizedCaseInsensitiveContains("income"))
        }

        if actualAmount > 0 || existingActual != nil {
            let entry = existingActual ?? MoneyEntry(
                type: .income,
                amount: actualAmount,
                currencyCode: normalizedCurrency,
                category: cleanedCategory,
                dateScope: .month,
                startDate: paymentDate,
                notes: cleanedNotes.isEmpty ? "Monthly income" : cleanedNotes,
                includeInMonthlySpending: false,
                source: .manual,
                createdAt: now,
                updatedAt: now
            )

            entry.type = .income
            entry.amount = actualAmount
            entry.currencyCode = normalizedCurrency
            entry.category = cleanedCategory
            entry.dateScope = .month
            entry.startDate = paymentDate
            entry.endDate = nil
            entry.notes = cleanedNotes.isEmpty ? "Monthly income" : cleanedNotes
            entry.includeInMonthlySpending = false
            entry.distributeAcrossPeriod = false
            entry.source = .manual
            entry.updatedAt = now

            if existingActual == nil {
                modelContext.insert(entry)
            }
        }

        try? modelContext.save()
    }

    private func tabBackground(isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(LifeTrackTheme.ColorPalette.accentGradient)
        }
        return AnyShapeStyle(Color.clear)
    }
}

private enum MoneyOverviewTab: String, CaseIterable, Identifiable {
    case overview
    case entries
    case bills
    case reports

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

private enum MoneyReportTab: String, CaseIterable, Identifiable {
    case overview
    case categories
    case trends
    case entries

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

private struct MoneyTrendPoint {
    var label: String
    var value: Double
    var normalized: Double
}

private struct MoneyProjectionMetric: View {
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

private struct MoneyProjectionChart: View {
    let points: [MoneyProjectionPoint]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cash flow")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Spacer()
                Text("Next 30 days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop, in: Capsule())
            }

            GeometryReader { proxy in
                let values = points.map(\.balance)
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let padding = max((maxValue - minValue) * 0.18, max(abs(maxValue) * 0.04, 1))
                let lowerBound = minValue - padding
                let upperBound = maxValue + padding
                let range = max(upperBound - lowerBound, 1)

                ZStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<5, id: \.self) { index in
                            let ratio = Double(index) / 4
                            HStack(spacing: 10) {
                                Text(axisLabel(for: upperBound - (range * ratio)))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                    .frame(width: 44, alignment: .leading)
                                Rectangle()
                                    .fill(LifeTrackTheme.ColorPalette.hairline.opacity(0.55))
                                    .frame(height: 0.7)
                            }
                            if index < 4 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Path { path in
                        for (index, point) in points.enumerated() {
                            let plotX = CGFloat(54)
                            let plotWidth = max(proxy.size.width - plotX, 1)
                            let x = plotX + (points.count <= 1 ? 0 : plotWidth * CGFloat(index) / CGFloat(points.count - 1))
                            let yRatio = (point.balance - lowerBound) / range
                            let y = proxy.size.height - (proxy.size.height * CGFloat(yRatio))
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(LifeTrackTheme.ColorPalette.accentGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    if let last = points.last {
                        Text(MoneyFormatting.currency(last.balance, code: currencyCode))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.86), in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
            }
            .frame(height: 150)
        }
    }

    private func axisLabel(for value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000 {
            return "\(currencyCodePrefix)\(Int(value / 1_000))K"
        }
        return "\(currencyCodePrefix)\(Int(value))"
    }

    private var currencyCodePrefix: String {
        currencyCode == "ZAR" ? "R" : "\(currencyCode) "
    }
}

private struct MoneyDeductionDraft: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amountText: String
}

private struct MoneyIncomeEditorView: View {
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
                            MoneyAmountField(title: "Planned income", amountText: $plannedText, currencyCode: $currencyCode)
                            MoneyAmountField(title: "Gross income", amountText: $grossText, currencyCode: $currencyCode)

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

private struct MoneySummaryCard: View {
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

private struct MoneyComparisonBar: View {
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

private struct MoneyCategoryRow: View {
    let total: MoneyCategoryTotal
    let maxAmount: Double

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
                    Spacer()
                    Text(MoneyFormatting.currency(total.actual, code: total.currencyCode))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
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
            }
        }
    }
}

private struct MoneyBillRow: View {
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

private struct MoneyEntryRow: View {
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

private struct MoneyBillStatusPill: View {
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
