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
            summaryGrid
            plannedVsActualCard
            overviewTwoColumn
            recentEntriesCard(limit: 5)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LifeTrackTheme.Spacing.medium) {
            MoneySummaryCard(
                title: "Income",
                value: summary.actualIncome,
                previousValue: previousSummary.actualIncome,
                currencyCode: currencyCode,
                subtitle: "This month",
                symbolName: "arrow.down.circle",
                tint: LifeTrackTheme.ColorPalette.success
            )
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

    private func shiftMonth(_ offset: Int) {
        selectedMonth = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) ?? selectedMonth
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

private struct MoneySummaryCard: View {
    let title: String
    let value: Double
    let previousValue: Double
    let currencyCode: String
    let subtitle: String
    let symbolName: String
    let tint: Color

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
        .lifeTrackCard(padding: LifeTrackTheme.Spacing.medium, backgroundColor: LifeTrackTheme.ColorPalette.cardElevated)
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
