//
//  MoneyOverviewView.swift
//  LifeTrack
//
//  Created by Codex on 2026/04/23.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MoneyOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \MoneyEntry.startDate, order: .reverse) private var entries: [MoneyEntry]
    @Query(sort: \LifeTask.dueDate, order: .forward) private var tasks: [LifeTask]
    @AppStorage(LifeTrackSettings.Keys.moneyCurrencyCode) private var appMoneyCurrencyCode = MoneyCurrency.defaultCode
    @AppStorage(LifeTrackSettings.Keys.moneyCurrencyLocked) private var isMoneyCurrencyLocked = false

    @StateObject private var moneyAdvisor = MoneyAIAdvisor()

    @State private var selectedTab: MoneyOverviewTab = .overview
    @State private var selectedReportTab: MoneyReportTab = .overview
    @State private var selectedMonth = Date()
    @State private var isShowingLogMoney = false
    @State private var isShowingIncomeEditor = false
    @State private var isShowingCurrencySetup = false
    @State private var isShowingBudgetPlanReview = false
    @State private var isShowingAIInsights = false
    @State private var isShowingStatementImport = false
    @State private var isShowingRecurring = false
    @State private var editingTask: LifeTask?

    private var currencyCode: String {
        MoneyCurrency.normalized(appMoneyCurrencyCode)
    }

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

                    Button(action: { isShowingStatementImport = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Import Bank Statement")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                                .stroke(LifeTrackTheme.ColorPalette.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))

                    Button(action: { isShowingRecurring = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Recurring Transactions")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                                .stroke(LifeTrackTheme.ColorPalette.hairline, lineWidth: 1)
                        )
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
        .sheet(isPresented: $isShowingStatementImport) {
            BankStatementImportView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingRecurring) {
            RecurringTransactionsView()
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
        .sheet(isPresented: $isShowingBudgetPlanReview) {
            BudgetPlanReviewView(
                month: selectedMonth,
                summary: summary,
                plannedBills: plannedBills,
                categoryTotals: spendingCategoryTotals,
                currencyCode: currencyCode
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingAIInsights) {
            MoneyAIInsightsDetailView(
                summary: summary,
                categoryTotals: categoryTotals,
                spendingCategoryTotals: spendingCategoryTotals,
                plannedBills: plannedBills,
                projectionPoints: projectionPoints,
                projectedBalance: projectedMonthEndBalance,
                daysLeft: daysLeftInMonth,
                currencyCode: currencyCode,
                lowBalanceThreshold: lowBalanceThreshold,
                month: selectedMonth,
                isPremium: subscriptionManager.tier >= .standard
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingCurrencySetup) {
            MoneyCurrencySetupView(
                selectedCurrencyCode: $appMoneyCurrencyCode,
                onLock: {
                    appMoneyCurrencyCode = MoneyCurrency.normalized(appMoneyCurrencyCode)
                    isMoneyCurrencyLocked = true
                    MoneySeedData.seedIfNeeded(
                        modelContext: modelContext,
                        entries: entries,
                        tasks: tasks,
                        currencyCode: currencyCode
                    )
                    isShowingCurrencySetup = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(!isMoneyCurrencyLocked)
        }
        .onAppear {
            appMoneyCurrencyCode = MoneyCurrency.normalized(appMoneyCurrencyCode)
            if !isMoneyCurrencyLocked {
                isShowingCurrencySetup = true
            } else {
                MoneySeedData.seedIfNeeded(
                    modelContext: modelContext,
                    entries: entries,
                    tasks: tasks,
                    currencyCode: currencyCode
                )
                triggerAIInsightIfEligible()
            }
        }
        .onChange(of: selectedMonth) { _, _ in
            triggerAIInsightIfEligible()
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
                    Text("Money currency: \(MoneyCurrency.normalized(currencyCode))")
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer(minLength: 0)

                MoneyCurrencyBadge(currencyCode: currencyCode, showsLock: isMoneyCurrencyLocked)

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
            projectionHeroCard
            cashFlowCard
            overviewTwoColumn
            moneyInsightBanner
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

    private var projectionHeroCard: some View {
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
                            .font(.lifeTrack(.largeTitle, weight: .bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text(MoneyFormatting.signedCurrency(projectedMonthEndBalance - monthOpeningBalance, code: currencyCode) + " vs start month")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(projectedMonthEndBalance >= monthOpeningBalance ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.danger)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background((projectedMonthEndBalance >= monthOpeningBalance ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.danger).opacity(0.10), in: Capsule())
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
            }
        }
    }

    private var cashFlowCard: some View {
        SectionCardView {
            MoneyProjectionChart(
                points: projectionPoints,
                currencyCode: currencyCode,
                lowThreshold: lowBalanceThreshold
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
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            compactUpcomingBillsCard
            compactSpendingBucketsCard
        }
    }

    private var compactUpcomingBillsCard: some View {
        SectionCardView {
            HStack {
                Text("Upcoming bills")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 4)

                Button("View all") {
                    selectedTab = .bills
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
            }

            let rows = Array(plannedBills.prefix(3))
            if rows.isEmpty {
                MoneyCompactEmptyState(title: "No bills")
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { bill in
                        MoneyCompactBillRow(bill: bill) {
                            editingTask = tasks.first { $0.id == bill.id }
                        }
                        if bill.id != rows.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var compactSpendingBucketsCard: some View {
        SectionCardView {
            HStack {
                Text("Spending buckets")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 4)

                Text("This month")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            let rows = Array(spendingCategoryTotals.prefix(4))
            if rows.isEmpty {
                MoneyCompactEmptyState(title: "No spend")
            } else {
                VStack(spacing: 11) {
                    ForEach(rows) { total in
                        MoneyCompactCategoryRow(total: total, maxAmount: maxSpendingCategoryAmount)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func spendingByCategoryCard(limit: Int? = nil) -> some View {
        SectionCardView {
            SectionHeaderView(title: "Spending buckets", subtitle: "This month")

            let rows = Array(spendingCategoryTotals.prefix(limit ?? spendingCategoryTotals.count))
            if rows.isEmpty {
                MoneyEmptyState(title: "No spending yet", message: "Log an expense to start category tracking.")
            } else {
                VStack(spacing: 9) {
                    ForEach(rows) { total in
                        MoneyCategoryRow(
                            total: total,
                            maxAmount: maxSpendingCategoryAmount,
                            carryIn: carryIn(for: total.category)
                        )
                    }
                }
            }
        }
    }

    private func plannedBillsCard(limit: Int? = nil) -> some View {
        SectionCardView {
            SectionHeaderView(title: "Upcoming bills", subtitle: "Planned, paid, or at-risk finance tasks.")

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

    private var moneyInsightBanner: some View {
        let isPremium = subscriptionManager.tier >= .standard
        let insightText: String = {
            if isPremium, let ai = moneyAdvisor.result { return ai.insight }
            if isPremium, moneyAdvisor.isLoading { return "Analysing your finances…" }
            if isPremium, let err = moneyAdvisor.error { return err }
            return primaryMoneyInsight
        }()
        let actionLabel: String = {
            if isPremium, let ai = moneyAdvisor.result { return ai.actionLabel }
            return "Build Plan"
        }()
        let urgency: MoneyAIInsight.Urgency = isPremium ? (moneyAdvisor.result?.urgency ?? .info) : .info
        let bannerColors: [Color] = {
            switch urgency {
            case .critical:
                return [Color(red: 0.72, green: 0.12, blue: 0.12).opacity(0.96), Color(red: 0.55, green: 0.08, blue: 0.08).opacity(0.90)]
            case .warning:
                return [Color(red: 0.75, green: 0.45, blue: 0.05).opacity(0.96), Color(red: 0.6, green: 0.32, blue: 0.02).opacity(0.90)]
            case .info:
                return [LifeTrackTheme.ColorPalette.primaryText.opacity(0.96), LifeTrackTheme.ColorPalette.secondaryText.opacity(0.90)]
            }
        }()

        return VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                ZStack {
                    if isPremium && moneyAdvisor.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.16), in: Circle())
                    } else {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.16), in: Circle())
                            .overlay { Circle().stroke(Color.white.opacity(0.18), lineWidth: 1) }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(isPremium ? "LifeTrack AI" : "Smart Insight")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.80))
                            .tracking(0.4)
                        if isPremium {
                            Text("AI")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.18), in: Capsule())
                        }
                    }
                    Text(isPremium ? "Personal finance advisor" : "Based on your numbers")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                if isPremium && !moneyAdvisor.isLoading {
                    Button {
                        triggerAIInsightIfEligible(force: true)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.9))
                    .accessibilityLabel("Refresh AI insight")
                }
            }

            Text(insightText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: LifeTrackTheme.Spacing.small) {
                Button {
                    handleInsightAction(isPremium: isPremium)
                } label: {
                    HStack(spacing: 6) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LifeTrackTheme.ColorPalette.accent, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96, pressedOpacity: 0.9))

                Spacer(minLength: 0)

                if isPremium {
                    Button {
                        isShowingAIInsights = true
                    } label: {
                        HStack(spacing: 5) {
                            Text("View more insights")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.94))
                }
            }
        }
        .padding(LifeTrackTheme.Spacing.large)
        .background(
            LinearGradient(colors: bannerColors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
        )
        .shadow(color: LifeTrackTheme.ColorPalette.shadow.opacity(0.75), radius: 12, x: 0, y: 8)
        .animation(.easeInOut(duration: 0.4), value: urgency)
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

    private var carryInsByCategory: [String: Double] {
        let rollovers = BudgetRollover.carryOver(
            intoMonth: selectedMonth,
            entries: entries,
            tasks: tasks,
            currencyCode: currencyCode
        )
        var map: [String: Double] = [:]
        for r in rollovers where r.carryOver > 0 {
            map[r.category.lowercased()] = r.carryOver
        }
        return map
    }

    private func carryIn(for category: String) -> Double {
        carryInsByCategory[category.lowercased()] ?? 0
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

    private var primaryMoneyInsight: String {
        if summary.spendingVariance > 0 {
            return "Trim \(MoneyFormatting.currency(summary.spendingVariance, code: currencyCode)) to get spending back on plan."
        }
        if summary.spendingVariance < 0 {
            return "You are \(MoneyFormatting.currency(abs(summary.spendingVariance), code: currencyCode)) under planned spend this month."
        }
        if summary.actualSavings > 0 {
            return "You saved \(MoneyFormatting.currency(summary.actualSavings, code: currencyCode)) so far this month."
        }
        return "Log income and bills to build a smarter monthly plan."
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

    private var monthOpeningBalance: Double {
        projectionPoints.first?.balance ?? previousSummary.actualRemaining
    }

    private var lowBalanceThreshold: Double {
        if summary.plannedIncome > 0 {
            return summary.plannedIncome * 0.38
        }
        if projectedMonthEndBalance < 0 || monthOpeningBalance < 0 {
            return 0
        }
        return max(projectedMonthEndBalance * 0.65, monthOpeningBalance * 0.45, 1)
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

    private var daysLeftInMonth: Int {
        let calendar = Calendar.current
        let interval = MoneyAnalytics.monthInterval(containing: selectedMonth, calendar: calendar)
        let today = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: interval.end)
        return max(0, calendar.dateComponents([.day], from: today, to: end).day ?? 0)
    }

    private func triggerAIInsightIfEligible(force: Bool = false) {
        guard subscriptionManager.tier >= .standard else { return }
        guard moneyAdvisor.isConfigured else { return }
        guard force || moneyAdvisor.result == nil else { return }
        Task {
            await moneyAdvisor.analyze(
                summary: summary,
                categoryTotals: categoryTotals,
                plannedBills: plannedBills,
                projectedBalance: projectedMonthEndBalance,
                daysLeft: daysLeftInMonth,
                currencyCode: currencyCode
            )
        }
    }

    private func handleInsightAction(isPremium: Bool) {
        guard isPremium, let ai = moneyAdvisor.result else {
            isShowingBudgetPlanReview = true
            return
        }
        switch ai.actionType {
        case .buildPlan:
            isShowingBudgetPlanReview = true
        case .viewCategory:
            selectedTab = .reports
        case .addIncome:
            isShowingIncomeEditor = true
        case .logEntry:
            isShowingLogMoney = true
        }
    }

    private func shiftMonth(_ offset: Int) {
        selectedMonth = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) ?? selectedMonth
    }

    private func saveIncomePlan(plannedAmount: Double, actualAmount: Double, currencyCode: String, category: String, paymentDate: Date, notes: String) {
        let cleanedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Income" : category.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let interval = MoneyAnalytics.monthInterval(containing: selectedMonth)
        let normalizedCurrency = MoneyCurrency.normalized(currencyCode)
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


