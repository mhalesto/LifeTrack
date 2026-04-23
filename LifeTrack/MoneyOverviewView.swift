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
                            .font(.system(.largeTitle, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
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
                        MoneyCategoryRow(total: total, maxAmount: maxSpendingCategoryAmount)
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

private struct MoneyDeductionDraft: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amountText: String
}

private struct MoneyCurrencySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrencyCode: String
    let onLock: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose Money Currency")
                            .font(.lifeTrackHeadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        Text("This currency will be used across entries, task financial details, bills, forecasts, and reports.")
                            .font(.subheadline)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    SectionCardView {
                        HStack(spacing: LifeTrackTheme.Spacing.medium) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                .frame(width: 44, height: 44)
                                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Global currency")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                Text("Pick carefully. It locks after setup so reports stay consistent.")
                                    .font(.caption)
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: LifeTrackTheme.Spacing.small)
                            MoneyCurrencyPicker(currencyCode: $selectedCurrencyCode)
                        }
                    }

                    Button {
                        selectedCurrencyCode = MoneyCurrency.normalized(selectedCurrencyCode)
                        onLock()
                        dismiss()
                        LifeTrackHaptics.lightImpact()
                    } label: {
                        Label("Use \(MoneyCurrency.normalized(selectedCurrencyCode))", systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LifeTrackTheme.ColorPalette.accentGradient, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                    }
                    .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                .padding(.top, LifeTrackTheme.Spacing.xLarge)
                .padding(.bottom, LifeTrackTheme.Spacing.xLarge)
            }
        }
        .tint(LifeTrackTheme.ColorPalette.accent)
    }
}

private struct BudgetPlanReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let month: Date
    let summary: MoneyMonthlySummary
    let plannedBills: [MoneyBillSnapshot]
    let categoryTotals: [MoneyCategoryTotal]
    let currencyCode: String

    @State private var step = 1
    @State private var buildsProjection = true
    @State private var showsVariableCases = true
    @State private var suggestsSavings = true
    @State private var automationMode: BudgetAutomationMode = .reviewMonthly
    @State private var paySchedule = "Monthly"
    @State private var incomeStability = "Stable"
    @State private var billRemindersEnabled = true
    @State private var reminderLeadTime = "3 days"
    @State private var debtStrategy = "Minimums"
    @State private var planPriority = "Save more"
    @State private var baseMonth: Date
    @State private var baseFrequency = "Monthly"
    @State private var dataMethod: BudgetDataMethod = .manual
    @State private var planFeatures: Set<BudgetPlanFeature> = [.budget, .bills, .savingsGoals, .cashProjection]
    @State private var incomeSources: [BudgetIncomeDraft]
    @State private var billDrafts: [BudgetBillDraft]
    @State private var essentialDrafts: [BudgetSimpleMoneyDraft]
    @State private var goalDrafts: [BudgetGoalDraft]
    @State private var debtDrafts: [BudgetDebtDraft]
    @State private var isShowingStatementImporter = false
    @State private var statementImportMessage: String?

    init(
        month: Date,
        summary: MoneyMonthlySummary,
        plannedBills: [MoneyBillSnapshot],
        categoryTotals: [MoneyCategoryTotal],
        currencyCode: String
    ) {
        self.month = month
        self.summary = summary
        self.plannedBills = plannedBills
        self.categoryTotals = categoryTotals
        self.currencyCode = currencyCode

        let income = summary.plannedIncome > 0 ? summary.plannedIncome : summary.actualIncome
        let bills = plannedBills.isEmpty
            ? BudgetBillDraft.sampleRows(incomeValue: income)
            : plannedBills.prefix(4).map {
                BudgetBillDraft(
                    title: $0.title,
                    date: $0.dueDate.dayMonthString,
                    amount: $0.plannedAmount,
                    symbolName: $0.status == .paid ? "checkmark.circle.fill" : "house.fill"
                )
            }
        let fixedBills = bills.reduce(0) { $0 + $1.amount }
        let debtsTotal = categoryTotals
            .filter { $0.kind == .debtPayment }
            .reduce(0) { $0 + max($1.planned, $1.actual) }
        let essentials = max(summary.plannedSpending - fixedBills - debtsTotal, income * 0.30, 0)
        let savings = max(summary.plannedSavings, summary.actualSavings, income * 0.08, 0)

        _baseMonth = State(initialValue: month)
        _incomeSources = State(initialValue: [
            BudgetIncomeDraft(title: "Salary", subtitle: "Work · Monthly", amount: max(income, 0), symbolName: "briefcase.fill", tint: LifeTrackTheme.ColorPalette.success),
            BudgetIncomeDraft(title: "Freelance / Side Hustle", subtitle: "Variable", amount: max(income * 0.10, 0), symbolName: "star.circle", tint: LifeTrackTheme.ColorPalette.warning),
            BudgetIncomeDraft(title: "Other Income", subtitle: "Optional", amount: max(income * 0.04, 0), symbolName: "ellipsis", tint: LifeTrackTheme.ColorPalette.accent)
        ])
        _billDrafts = State(initialValue: bills)
        _essentialDrafts = State(initialValue: [
            BudgetSimpleMoneyDraft(title: "Groceries", amount: essentials * 0.38, symbolName: "cart.fill", tint: LifeTrackTheme.ColorPalette.success),
            BudgetSimpleMoneyDraft(title: "Transport", amount: essentials * 0.20, symbolName: "car.fill", tint: LifeTrackTheme.ColorPalette.accent),
            BudgetSimpleMoneyDraft(title: "Health", amount: essentials * 0.12, symbolName: "heart.fill", tint: LifeTrackTheme.ColorPalette.danger),
            BudgetSimpleMoneyDraft(title: "Kids / School", amount: essentials * 0.22, symbolName: "backpack.fill", tint: LifeTrackTheme.ColorPalette.warning)
        ])
        _goalDrafts = State(initialValue: [
            BudgetGoalDraft(title: "Emergency Fund", target: max(income * 0.60, 15_000), current: max(summary.actualSavings, income * 0.20), contribution: max(savings * 0.50, 0), symbolName: "shield.fill", tint: LifeTrackTheme.ColorPalette.success),
            BudgetGoalDraft(title: "December Holiday", target: max(income * 0.35, 10_000), current: max(income * 0.10, 0), contribution: max(savings * 0.30, 0), symbolName: "beach.umbrella.fill", tint: LifeTrackTheme.ColorPalette.accent),
            BudgetGoalDraft(title: "New Laptop", target: max(income * 0.40, 18_000), current: max(income * 0.12, 0), contribution: max(savings * 0.20, 0), symbolName: "laptopcomputer", tint: LifeTrackTheme.ColorPalette.warning)
        ])
        _debtDrafts = State(initialValue: [
            BudgetDebtDraft(title: "Credit Card", balance: max(debtsTotal, income * 0.20), minimumPayment: max(debtsTotal * 0.08, 300), symbolName: "creditcard.fill"),
            BudgetDebtDraft(title: "Store Account", balance: max(debtsTotal * 0.32, income * 0.08), minimumPayment: max(debtsTotal * 0.04, 180), symbolName: "storefront.fill")
        ])
        if debtsTotal > 0 {
            _planFeatures = State(initialValue: [.budget, .bills, .savingsGoals, .debtPayoff, .cashProjection])
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                        progressHeader

                        VStack(alignment: .leading, spacing: 8) {
                            Text(stepTitle)
                                .font(.lifeTrackHero)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            Text(stepSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        stepContent

                        Button {
                            if step < 5 {
                                withAnimation(.snappy) {
                                    step += 1
                                }
                            } else {
                                generatePlan()
                            }
                            LifeTrackHaptics.lightImpact()
                        } label: {
                            HStack(spacing: 9) {
                                Text(step == 5 ? "Generate My Plan" : "Continue")
                                Image(systemName: "chevron.right")
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(LifeTrackTheme.ColorPalette.accentGradient, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                        }
                        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98))
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .tint(LifeTrackTheme.ColorPalette.accent)
        .fileImporter(
            isPresented: $isShowingStatementImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .json],
            allowsMultipleSelection: false,
            onCompletion: handleStatementImport
        )
    }

    private var progressHeader: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Button {
                if step > 1 {
                    withAnimation(.snappy) {
                        step -= 1
                    }
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    if step > 1 {
                        Image(systemName: "chevron.left")
                    }
                    Text(step > 1 ? "Back" : "Later")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.78), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.8), lineWidth: 0.8)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { step in
                    Text("\(step)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(step == self.step ? .white : LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(step == self.step ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.cardElevated, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(step == self.step ? 0 : 0.8), lineWidth: 0.8)
                        }
                }
            }

            Text("\(step) of 5")
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1:
            setupPlannerContent
        case 2:
            incomeSetupContent
        case 3:
            billsEssentialsContent
        case 4:
            goalsDebtContent
        default:
            snapshotCard
            forecastOptionsCard
            previewCard
            automationCard
        }
    }

    private var stepTitle: String {
        switch step {
        case 1: "Set Up Budget Planner"
        case 2: "Add Your Income"
        case 3: "Add Bills & Essentials"
        case 4: "Goals, Savings & Debt"
        default: "Review & Generate Plan"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 1: "Tell LifeTrack how money moves so we can build your monthly plan, bill forecast, and projections."
        case 2: "Tell LifeTrack what comes in each month so projections stay realistic."
        case 3: "We'll use these to forecast cash flow, due dates, and pressure points."
        case 4: "Add the goals you care about so LifeTrack can recommend better spending room."
        default: "Check the inputs below, then let LifeTrack build your monthly budget and projections."
        }
    }

    private var setupPlannerContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            SectionCardView {
                SectionHeaderView(title: "Choose Your Base Month")

                BudgetMonthSelectorRow(month: $baseMonth)

                BudgetSegmentedOptions(options: ["Monthly", "Biweekly", "Weekly"], selected: $baseFrequency)
            }

            SectionCardView {
                SectionHeaderView(title: "What do you want to plan?", subtitle: "We'll include these in your plan and projections.")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                    ForEach(BudgetPlanFeature.allCases) { feature in
                        BudgetSelectableChip(
                            title: feature.title,
                            symbolName: feature.symbolName,
                            isSelected: planFeatures.contains(feature)
                        ) {
                            toggleFeature(feature)
                        }
                    }
                }
            }

            SectionCardView {
                SectionHeaderView(title: "How do you want to add data?", subtitle: "You can change this anytime.")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    BudgetMethodCard(title: "Manual Entry", subtitle: "Add transactions yourself", symbolName: "pencil", isSelected: dataMethod == .manual) {
                        dataMethod = .manual
                    }
                    BudgetMethodCard(title: "Import Statement", subtitle: "Upload bank or card statements", symbolName: "icloud.and.arrow.up", isSelected: dataMethod == .importStatement) {
                        dataMethod = .importStatement
                        isShowingStatementImporter = true
                    }
                }

                Label(statementImportMessage ?? "You can import later too.", systemImage: statementImportMessage == nil ? "shield.checkered" : "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var incomeSetupContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            SectionCardView {
                SectionHeaderView(title: "Monthly Income")

                ForEach($incomeSources) { $source in
                    BudgetAdjustableMoneyRow(
                        title: source.title,
                        subtitle: source.subtitle,
                        amount: $source.amount,
                        currencyCode: currencyCode,
                        symbolName: source.symbolName,
                        tint: source.tint,
                        step: suggestedAdjustmentStep(for: source.amount)
                    )
                }

                Button {
                    addIncomeSource()
                } label: {
                    Label("Add income source", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .overlay {
                            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                                .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        }
                }
                .buttonStyle(.plain)
            }

            SectionCardView {
                SectionHeaderView(title: "Pay Schedule")
                BudgetSegmentedOptions(options: ["Monthly", "Twice a month", "Weekly"], selected: $paySchedule)
                MoneyValueRow(title: "Next payday estimate", value: nextPaydayEstimate, symbolName: "calendar", tint: LifeTrackTheme.ColorPalette.accent)
            }

            SectionCardView {
                SectionHeaderView(title: "Income Stability")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    BudgetMethodCard(title: "Stable", subtitle: "Predictable", symbolName: "shield.fill", isSelected: incomeStability == "Stable") { incomeStability = "Stable" }
                    BudgetMethodCard(title: "Mixed", subtitle: "Some variable", symbolName: "waveform.path.ecg", isSelected: incomeStability == "Mixed") { incomeStability = "Mixed" }
                    BudgetMethodCard(title: "Irregular", subtitle: "Varies often", symbolName: "waveform", isSelected: incomeStability == "Irregular") { incomeStability = "Irregular" }
                }
            }
        }
    }

    private var billsEssentialsContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            SectionCardView {
                SectionHeaderView(title: "Recurring Bills", subtitle: "Add your monthly fixed bills.")

                ForEach($billDrafts) { $bill in
                    BudgetAdjustableMoneyRow(
                        title: bill.title,
                        subtitle: "\(bill.date) · Monthly",
                        amount: $bill.amount,
                        currencyCode: currencyCode,
                        symbolName: bill.symbolName,
                        tint: LifeTrackTheme.ColorPalette.accent,
                        step: suggestedAdjustmentStep(for: bill.amount)
                    )
                }

                Button {
                    addBill()
                } label: {
                    Label("Add recurring bill", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .overlay {
                            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                                .stroke(LifeTrackTheme.ColorPalette.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        }
                }
                .buttonStyle(.plain)
            }

            SectionCardView {
                SectionHeaderView(title: "Flexible Essentials", subtitle: "Set your average monthly spend.")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach($essentialDrafts) { $essential in
                        BudgetAdjustableMoneyTile(
                            title: essential.title,
                            amount: $essential.amount,
                            currencyCode: currencyCode,
                            symbolName: essential.symbolName,
                            tint: essential.tint,
                            step: suggestedAdjustmentStep(for: essential.amount)
                        )
                    }
                }
            }

            SectionCardView {
                Toggle(isOn: $billRemindersEnabled) {
                    SectionHeaderView(title: "Bill Reminders", subtitle: "Never miss a payment.")
                }
                .tint(LifeTrackTheme.ColorPalette.accent)
                BudgetSegmentedOptions(options: ["1 day", "3 days", "1 week"], selected: $reminderLeadTime)
            }
        }
    }

    private var goalsDebtContent: some View {
        VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
            SectionCardView {
                SectionHeaderView(title: "Savings Goals")
                ForEach($goalDrafts) { $goal in
                    BudgetGoalRow(
                        title: goal.title,
                        target: goal.target,
                        current: goal.current,
                        contribution: $goal.contribution,
                        currencyCode: currencyCode,
                        symbolName: goal.symbolName,
                        tint: goal.tint,
                        step: suggestedAdjustmentStep(for: goal.contribution)
                    )
                }
            }

            SectionCardView {
                SectionHeaderView(title: "Debt Payoff")
                ForEach($debtDrafts) { $debt in
                    BudgetAdjustableMoneyRow(
                        title: debt.title,
                        subtitle: "Balance \(MoneyFormatting.currency(debt.balance, code: currencyCode))",
                        amount: $debt.minimumPayment,
                        currencyCode: currencyCode,
                        symbolName: debt.symbolName,
                        tint: LifeTrackTheme.ColorPalette.accent,
                        step: suggestedAdjustmentStep(for: debt.minimumPayment)
                    )
                }
                BudgetSegmentedOptions(options: ["Minimums", "Snowball", "Avalanche"], selected: $debtStrategy)
            }

            SectionCardView {
                SectionHeaderView(title: "Priority")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    BudgetMethodCard(title: "Save more", subtitle: "", symbolName: "banknote", isSelected: planPriority == "Save more") { planPriority = "Save more" }
                    BudgetMethodCard(title: "Pay off debt", subtitle: "", symbolName: "creditcard", isSelected: planPriority == "Pay off debt") { planPriority = "Pay off debt" }
                    BudgetMethodCard(title: "Balanced", subtitle: "", symbolName: "scalemass", isSelected: planPriority == "Balanced") { planPriority = "Balanced" }
                }
            }
        }
    }

    private var snapshotCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Your Snapshot")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                BudgetSnapshotTile(title: "Income", value: incomeValue, currencyCode: currencyCode, symbolName: "arrow.up", tint: LifeTrackTheme.ColorPalette.success)
                BudgetSnapshotTile(title: "Fixed Bills", value: fixedBillsValue, currencyCode: currencyCode, symbolName: "list.bullet.rectangle", tint: LifeTrackTheme.ColorPalette.accent)
                BudgetSnapshotTile(title: "Essentials", value: essentialsValue, currencyCode: currencyCode, symbolName: "cart.fill", tint: LifeTrackTheme.ColorPalette.warning)
                BudgetSnapshotTile(title: "Goals & Debt", value: goalsDebtValue, currencyCode: currencyCode, symbolName: "target", tint: LifeTrackTheme.ColorPalette.danger)
                BudgetSnapshotTile(title: "Free to Allocate", value: freeToAllocateValue, currencyCode: currencyCode, symbolName: "wallet.pass.fill", tint: LifeTrackTheme.ColorPalette.success)
            }
        }
    }

    private var forecastOptionsCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Forecast Options")

            BudgetPlanToggleRow(title: "Build 30-day cash projection", symbolName: "chart.line.uptrend.xyaxis", isOn: $buildsProjection)
            BudgetPlanToggleRow(title: "Show best / worst case for variable income", symbolName: "sparkles", isOn: $showsVariableCases)
            BudgetPlanToggleRow(title: "Suggest safe savings amount", symbolName: "shield.checkered", isOn: $suggestsSavings)
        }
    }

    private var previewCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Preview This Month")

            VStack(spacing: LifeTrackTheme.Spacing.medium) {
                VStack(spacing: 0) {
                    MoneyValueRow(title: "Expected leftover", value: MoneyFormatting.currency(freeToAllocateValue, code: currencyCode), symbolName: "circle.fill", tint: LifeTrackTheme.ColorPalette.success)
                    Divider().padding(.leading, 46)
                    MoneyValueRow(title: "Bills covered", value: "\(billDrafts.filter { $0.amount > 0 }.count)", symbolName: "list.bullet", tint: LifeTrackTheme.ColorPalette.accent)
                    Divider().padding(.leading, 46)
                    MoneyValueRow(title: "Goal contributions", value: "\(goalContributionCount)", symbolName: "target", tint: LifeTrackTheme.ColorPalette.warning)
                }

                BudgetPreviewChart(
                    currencyCode: currencyCode,
                    values: [
                        BudgetPreviewChart.Value(label: "Income", amount: incomeValue, tint: LifeTrackTheme.ColorPalette.success, isOutline: false),
                        BudgetPreviewChart.Value(label: "Bills", amount: fixedBillsValue, tint: LifeTrackTheme.ColorPalette.danger, isOutline: false),
                        BudgetPreviewChart.Value(label: "Essentials", amount: essentialsValue, tint: LifeTrackTheme.ColorPalette.warning, isOutline: false),
                        BudgetPreviewChart.Value(label: "Goals", amount: goalsDebtValue, tint: LifeTrackTheme.ColorPalette.danger.opacity(0.72), isOutline: false),
                        BudgetPreviewChart.Value(label: "Leftover", amount: freeToAllocateValue, tint: LifeTrackTheme.ColorPalette.success, isOutline: true)
                    ]
                )
            }
        }
    }

    private var automationCard: some View {
        SectionCardView {
            SectionHeaderView(title: "Automation")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                BudgetAutomationChoice(
                    title: "Review monthly",
                    subtitle: "I'll review and approve my plan each month.",
                    symbolName: "calendar",
                    isSelected: automationMode == .reviewMonthly
                ) {
                    automationMode = .reviewMonthly
                }

                BudgetAutomationChoice(
                    title: "Auto-roll forward",
                    subtitle: "LifeTrack will roll my plan forward automatically.",
                    symbolName: "calendar.badge.clock",
                    isSelected: automationMode == .autoRoll
                ) {
                    automationMode = .autoRoll
                }
            }

            Label("You can edit any of this after setup.", systemImage: "shield.checkered")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .frame(maxWidth: .infinity)
        }
    }

    private var incomeValue: Double {
        incomeSources.reduce(0) { $0 + $1.amount }
    }

    private var fixedBillsValue: Double {
        guard planFeatures.contains(.bills) else { return 0 }
        return billDrafts.reduce(0) { $0 + $1.amount }
    }

    private var debtValue: Double {
        guard planFeatures.contains(.debtPayoff) else { return 0 }
        return debtDrafts.reduce(0) { $0 + $1.balance }
    }

    private var essentialsValue: Double {
        guard planFeatures.contains(.budget) else { return 0 }
        return essentialDrafts.reduce(0) { $0 + $1.amount }
    }

    private var goalsDebtValue: Double {
        let goals = planFeatures.contains(.savingsGoals) ? goalDrafts.reduce(0) { $0 + $1.contribution } : 0
        let debtPayments = planFeatures.contains(.debtPayoff) ? debtDrafts.reduce(0) { $0 + $1.minimumPayment } : 0
        return goals + debtPayments
    }

    private var freeToAllocateValue: Double {
        max(incomeValue - fixedBillsValue - essentialsValue - goalsDebtValue, 0)
    }

    private var goalContributionCount: Int {
        let goals = planFeatures.contains(.savingsGoals) ? goalDrafts.filter { $0.contribution > 0 }.count : 0
        let debts = planFeatures.contains(.debtPayoff) ? debtDrafts.filter { $0.minimumPayment > 0 }.count : 0
        return goals + debts
    }

    private var nextPaydayEstimate: String {
        switch paySchedule {
        case "Weekly":
            return "Every Friday"
        case "Twice a month":
            return "15th and 30th"
        default:
            return dayMonthLabel(day: paydayDay)
        }
    }

    private func suggestedAdjustmentStep(for amount: Double) -> Double {
        max((amount / 10).rounded(.toNearestOrAwayFromZero), 50)
    }

    private func toggleFeature(_ feature: BudgetPlanFeature) {
        if planFeatures.contains(feature) {
            planFeatures.remove(feature)
        } else {
            planFeatures.insert(feature)
        }
    }

    private func addIncomeSource() {
        incomeSources.append(
            BudgetIncomeDraft(
                title: "Income source \(incomeSources.count + 1)",
                subtitle: "Optional",
                amount: 0,
                symbolName: "plus.circle",
                tint: LifeTrackTheme.ColorPalette.accent
            )
        )
    }

    private func addBill() {
        billDrafts.append(
            BudgetBillDraft(
                title: "New bill \(billDrafts.count + 1)",
                date: dayMonthLabel(day: 15),
                amount: 0,
                symbolName: "calendar"
            )
        )
    }

    private func generatePlan() {
        let now = Date()
        if planFeatures.contains(.budget) || planFeatures.contains(.cashProjection) {
            for source in incomeSources where source.amount > 0 {
                modelContext.insert(financeTask(
                    title: source.title,
                    type: .income,
                    amount: source.amount,
                    category: "Income",
                    dueDay: paydayDay,
                    recurrence: recurrenceForSchedule,
                    notes: "Generated by Budget Planner. Base plan: \(baseFrequency). Data: \(dataMethodTitle). Stability: \(incomeStability). Schedule: \(paySchedule).",
                    includeInMonthlySpending: false,
                    now: now
                ))
            }
        }

        if planFeatures.contains(.bills) {
            for bill in billDrafts where bill.amount > 0 {
                modelContext.insert(financeTask(
                    title: bill.title,
                    type: .expense,
                    amount: bill.amount,
                    category: "Bills",
                    dueDay: dayNumber(from: bill.date) ?? 5,
                    recurrence: .monthly,
                    notes: "Generated by Budget Planner. Base plan: \(baseFrequency). Reminder: \(billRemindersEnabled ? reminderLeadTime : "off").",
                    includeInMonthlySpending: true,
                    now: now
                ))
            }
        }

        if planFeatures.contains(.budget) {
            for essential in essentialDrafts where essential.amount > 0 {
                modelContext.insert(financeTask(
                    title: "\(essential.title) budget",
                    type: .expense,
                    amount: essential.amount,
                    category: essential.title,
                    dueDay: 1,
                    recurrence: recurrenceForBaseFrequency,
                    notes: "Generated by Budget Planner flexible essentials. Base plan: \(baseFrequency).",
                    includeInMonthlySpending: true,
                    now: now
                ))
            }
        }

        if planFeatures.contains(.savingsGoals) {
            for goal in goalDrafts where goal.contribution > 0 {
                modelContext.insert(financeTask(
                    title: "\(goal.title) contribution",
                    type: .savings,
                    amount: goal.contribution,
                    category: goal.title,
                    dueDay: paydayDay,
                    recurrence: recurrenceForBaseFrequency,
                    notes: "Generated by Budget Planner. Base plan: \(baseFrequency). Target: \(MoneyFormatting.currency(goal.target, code: currencyCode)). Priority: \(planPriority).",
                    includeInMonthlySpending: false,
                    now: now
                ))
            }
        }

        if planFeatures.contains(.debtPayoff) {
            for debt in debtDrafts where debt.minimumPayment > 0 {
                modelContext.insert(financeTask(
                    title: "\(debt.title) payment",
                    type: .expense,
                    amount: debt.minimumPayment,
                    category: "Debt",
                    dueDay: 20,
                    recurrence: recurrenceForBaseFrequency,
                    notes: "Generated by Budget Planner. Base plan: \(baseFrequency). Strategy: \(debtStrategy). Balance: \(MoneyFormatting.currency(debt.balance, code: currencyCode)).",
                    includeInMonthlySpending: true,
                    now: now
                ))
            }
        }

        try? modelContext.save()
        dismiss()
    }

    private func handleStatementImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                statementImportMessage = "No statement selected."
                return
            }
            do {
                let entries = try BudgetStatementImporter.entries(from: url, currencyCode: currencyCode, fallbackDate: dateInBaseMonth(day: 1))
                for entry in entries {
                    modelContext.insert(entry)
                }
                try modelContext.save()
                statementImportMessage = "Imported \(entries.count.formatted()) money entr\(entries.count == 1 ? "y" : "ies")."
            } catch {
                statementImportMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            statementImportMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private var paydayDay: Int {
        paySchedule == "Weekly" ? 7 : 25
    }

    private var recurrenceForSchedule: TaskRecurrence {
        paySchedule == "Weekly" ? .weekly : .monthly
    }

    private var recurrenceForBaseFrequency: TaskRecurrence {
        baseFrequency == "Monthly" ? .monthly : .weekly
    }

    private var dataMethodTitle: String {
        dataMethod == .manual ? "Manual entry" : "Imported statement"
    }

    private func financeTask(
        title: String,
        type: TaskFinancialType,
        amount: Double,
        category: String,
        dueDay: Int,
        recurrence: TaskRecurrence,
        notes: String,
        includeInMonthlySpending: Bool,
        now: Date
    ) -> LifeTask {
        let dueDate = dateInBaseMonth(day: dueDay)
        return LifeTask(
            title: title,
            category: .finance,
            dueDate: dueDate,
            notes: notes,
            recurrence: recurrence,
            estimatedDurationMinutes: 15,
            financialEnabled: true,
            financialType: type,
            plannedAmount: amount,
            currencyCode: currencyCode,
            budgetCategory: category,
            paymentDate: dueDate,
            includeInMonthlySpending: includeInMonthlySpending,
            markPlannedOnCreate: true,
            financialNotes: notes,
            createdAt: now,
            updatedAt: now
        )
    }

    private func dateInBaseMonth(day: Int) -> Date {
        let calendar = Calendar.current
        let interval = MoneyAnalytics.monthInterval(containing: baseMonth, calendar: calendar)
        let maxDay = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 28
        var components = calendar.dateComponents([.year, .month], from: interval.start)
        components.day = min(max(day, 1), maxDay)
        components.hour = 9
        return calendar.date(from: components) ?? interval.start
    }

    private func dayNumber(from label: String) -> Int? {
        let digits = label.prefix { $0.isNumber }
        return Int(digits)
    }

    private func dayMonthLabel(day: Int) -> String {
        dateInBaseMonth(day: day).dayMonthString
    }
}

private enum BudgetAutomationMode {
    case reviewMonthly
    case autoRoll
}

private enum BudgetDataMethod {
    case manual
    case importStatement
}

private enum BudgetStatementImportError: LocalizedError {
    case emptyFile
    case noImportableRows

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The selected statement is empty."
        case .noImportableRows:
            return "No rows with an amount could be imported."
        }
    }
}

private enum BudgetStatementImporter {
    static func entries(from url: URL, currencyCode: String, fallbackDate: Date) throws -> [MoneyEntry] {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw BudgetStatementImportError.emptyFile
        }

        if url.pathExtension.lowercased() == "json",
           let jsonEntries = try? entriesFromJSON(data, currencyCode: currencyCode, fallbackDate: fallbackDate),
           !jsonEntries.isEmpty {
            return jsonEntries
        }

        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw BudgetStatementImportError.emptyFile
        }
        let delimiter: Character = text.contains("\t") ? "\t" : ","
        let rows = CSVCodec.decode(text, delimiter: delimiter)
        return try entries(fromRows: rows, currencyCode: currencyCode, fallbackDate: fallbackDate)
    }

    private static func entriesFromJSON(_ data: Data, currencyCode: String, fallbackDate: Date) throws -> [MoneyEntry] {
        let object = try JSONSerialization.jsonObject(with: data)
        let rows: [[String: String]]
        if let array = object as? [[String: Any]] {
            rows = array.map(stringDictionary)
        } else if let package = object as? [String: Any], let array = package["entries"] as? [[String: Any]] {
            rows = array.map(stringDictionary)
        } else if let package = object as? [String: Any], let array = package["transactions"] as? [[String: Any]] {
            rows = array.map(stringDictionary)
        } else {
            rows = []
        }
        let entries = rows.compactMap { entry(from: $0, currencyCode: currencyCode, fallbackDate: fallbackDate) }
        if entries.isEmpty {
            throw BudgetStatementImportError.noImportableRows
        }
        return entries
    }

    private static func entries(fromRows rows: [[String]], currencyCode: String, fallbackDate: Date) throws -> [MoneyEntry] {
        guard !rows.isEmpty else {
            throw BudgetStatementImportError.emptyFile
        }

        let headers = rows[0].map(normalizedKey)
        let dictionaries = rows.dropFirst().map { row in
            Dictionary(uniqueKeysWithValues: headers.enumerated().map { index, header in
                (header, index < row.count ? row[index] : "")
            })
        }
        let entries = dictionaries.compactMap { entry(from: $0, currencyCode: currencyCode, fallbackDate: fallbackDate) }
        if entries.isEmpty {
            throw BudgetStatementImportError.noImportableRows
        }
        return entries
    }

    private static func entry(from row: [String: String], currencyCode: String, fallbackDate: Date) -> MoneyEntry? {
        let amountRaw = firstValue(in: row, keys: ["amount", "value", "transaction_amount", "money"])
        let debitRaw = firstValue(in: row, keys: ["debit", "withdrawal", "spent", "paid"])
        let creditRaw = firstValue(in: row, keys: ["credit", "deposit", "received", "income"])

        let amountValue = parseAmount(amountRaw)
        let debitValue = parseAmount(debitRaw)
        let creditValue = parseAmount(creditRaw)
        let signedAmount = amountValue ?? creditValue ?? debitValue.map { -abs($0) }
        guard let signedAmount, signedAmount != 0 else {
            return nil
        }

        let type = resolvedType(
            rawType: firstValue(in: row, keys: ["type", "transaction_type", "kind"]),
            signedAmount: signedAmount,
            debitValue: debitValue,
            creditValue: creditValue
        )
        let category = firstValue(in: row, keys: ["category", "budget_category", "merchant_category"])
            ?? defaultCategory(for: type)
        let note = firstValue(in: row, keys: ["notes", "note", "description", "memo", "merchant", "name"])
            ?? "Imported statement row"
        let date = parseDate(firstValue(in: row, keys: ["date", "transaction_date", "posted_date", "payment_date"])) ?? fallbackDate

        return MoneyEntry(
            type: type,
            amount: abs(signedAmount),
            currencyCode: firstValue(in: row, keys: ["currency", "currency_code", "iso_currency"]) ?? currencyCode,
            category: category,
            dateScope: .day,
            startDate: date,
            notes: note,
            includeInMonthlySpending: type == .expense || type == .debtPayment,
            source: .imported
        )
    }

    private static func resolvedType(rawType: String?, signedAmount: Double, debitValue: Double?, creditValue: Double?) -> MoneyTransactionType {
        let normalized = normalizedKey(rawType ?? "")
        if normalized.contains("saving") {
            return .savings
        }
        if normalized.contains("transfer") {
            return .transfer
        }
        if normalized.contains("debt") || normalized.contains("loan") {
            return .debtPayment
        }
        if normalized.contains("income") || normalized.contains("credit") || normalized.contains("deposit") {
            return .income
        }
        if normalized.contains("expense") || normalized.contains("debit") || normalized.contains("withdrawal") || normalized.contains("spend") {
            return .expense
        }
        if debitValue != nil {
            return .expense
        }
        if creditValue != nil {
            return .income
        }
        return signedAmount < 0 ? .expense : .income
    }

    private static func defaultCategory(for type: MoneyTransactionType) -> String {
        switch type {
        case .expense: "Imported"
        case .income: "Income"
        case .savings: "Savings"
        case .transfer: "Transfer"
        case .debtPayment: "Debt"
        }
    }

    private static func firstValue(in row: [String: String], keys: [String]) -> String? {
        for key in keys {
            let normalized = normalizedKey(key)
            if let value = row[normalized]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func parseAmount(_ raw: String?) -> Double? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        var isNegative = false
        if text.hasPrefix("("), text.hasSuffix(")") {
            isNegative = true
        }
        if text.contains("-") {
            isNegative = true
        }
        if text.contains(",") && text.contains(".") {
            text = text.replacingOccurrences(of: ",", with: "")
        } else {
            text = text.replacingOccurrences(of: ",", with: ".")
        }
        let allowed = Set("0123456789.")
        let cleaned = String(text.filter { allowed.contains($0) })
        guard let value = Double(cleaned) else {
            return nil
        }
        return isNegative ? -value : value
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        if let date = ISO8601DateFormatter().date(from: text) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd", "yyyy/MM/dd", "dd/MM/yyyy", "MM/dd/yyyy", "d MMM yyyy", "dd MMM yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }

    private static func normalizedKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func stringDictionary(_ dictionary: [String: Any]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: dictionary.map { key, value in
            (normalizedKey(key), "\(value)")
        })
    }
}

private enum BudgetPlanFeature: String, CaseIterable, Identifiable {
    case budget
    case bills
    case savingsGoals
    case debtPayoff
    case cashProjection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .budget: "Budget"
        case .bills: "Bills"
        case .savingsGoals: "Savings Goals"
        case .debtPayoff: "Debt Payoff"
        case .cashProjection: "Cash Flow"
        }
    }

    var symbolName: String {
        switch self {
        case .budget: "chart.pie.fill"
        case .bills: "list.bullet.rectangle.fill"
        case .savingsGoals: "target"
        case .debtPayoff: "creditcard.fill"
        case .cashProjection: "chart.line.uptrend.xyaxis"
        }
    }
}

private struct BudgetIncomeDraft: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var amount: Double
    var symbolName: String
    var tint: Color
}

private struct BudgetBillDraft: Identifiable {
    let id = UUID()
    var title: String
    var date: String
    var amount: Double
    var symbolName: String

    static func sampleRows(incomeValue: Double) -> [BudgetBillDraft] {
        let baseIncome = max(incomeValue, 10_000)
        return [
            BudgetBillDraft(title: "Rent", date: "05 May", amount: max(baseIncome * 0.25, 2_500), symbolName: "house.fill"),
            BudgetBillDraft(title: "Internet", date: "07 May", amount: 739, symbolName: "wifi"),
            BudgetBillDraft(title: "Medical Aid", date: "12 May", amount: 2_315, symbolName: "cross.case.fill")
        ]
    }
}

private struct BudgetSimpleMoneyDraft: Identifiable {
    let id = UUID()
    var title: String
    var amount: Double
    var symbolName: String
    var tint: Color
}

private struct BudgetGoalDraft: Identifiable {
    let id = UUID()
    var title: String
    var target: Double
    var current: Double
    var contribution: Double
    var symbolName: String
    var tint: Color
}

private struct BudgetDebtDraft: Identifiable {
    let id = UUID()
    var title: String
    var balance: Double
    var minimumPayment: Double
    var symbolName: String
}

private struct BudgetMonthSelectorRow: View {
    @Binding var month: Date

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.76), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            VStack(alignment: .leading, spacing: 4) {
                Text(MoneyAnalytics.monthTitle(for: month))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("Base month")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.76), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
    }

    private func shiftMonth(by value: Int) {
        month = Calendar.current.date(byAdding: .month, value: value, to: month) ?? month
    }
}

private struct BudgetSegmentedOptions: View {
    let options: [String]
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    selected = option
                } label: {
                    Text(option)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(selected == option ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(selected == option ? LifeTrackTheme.ColorPalette.accentSoft : Color.clear)
                }
                .buttonStyle(.plain)

                if index < options.count - 1 {
                    Divider()
                }
            }
        }
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.8)
        }
    }
}

private struct BudgetSelectableChip: View {
    let title: String
    let symbolName: String
    let isSelected: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(isSelected ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.secondaryText)
            .padding(12)
            .background(isSelected ? LifeTrackTheme.ColorPalette.accentSoft.opacity(0.55) : LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(isSelected ? LifeTrackTheme.ColorPalette.accent.opacity(0.55) : LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.8)
            }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98, pressedOpacity: 0.94))
    }
}

private struct BudgetMethodCard: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let isSelected: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.secondaryText)
                    .frame(width: 46, height: 46)
                    .background((isSelected ? LifeTrackTheme.ColorPalette.accentSoft : LifeTrackTheme.ColorPalette.backgroundTop), in: Circle())

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 116)
            .padding(12)
            .background(isSelected ? LifeTrackTheme.ColorPalette.accentSoft.opacity(0.48) : LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(isSelected ? LifeTrackTheme.ColorPalette.accent.opacity(0.65) : LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.9)
            }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98, pressedOpacity: 0.94))
    }
}

private struct BudgetSetupRow: View {
    let title: String
    let subtitle: String
    let value: String
    let symbolName: String
    let tint: Color

    var body: some View {
        HStack(spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.8)
        }
    }
}

private struct BudgetAmountEditor: View {
    @Binding var amount: Double
    let currencyCode: String
    let foregroundColor: Color
    let font: Font
    let minWidth: CGFloat
    let textAlignment: TextAlignment
    let frameAlignment: Alignment

    @State private var draftText = ""
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: frameAlignment) {
            if isEditing {
                TextField("0", text: $draftText)
                    .font(font)
                    .foregroundStyle(foregroundColor)
                    .multilineTextAlignment(textAlignment)
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit(commitAndClose)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .frame(minWidth: minWidth, alignment: frameAlignment)
                    .background(LifeTrackTheme.ColorPalette.cardElevated.opacity(0.78), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(foregroundColor.opacity(0.28), lineWidth: 0.9)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                commitAndClose()
                            }
                        }
                    }
            } else {
                Button {
                    draftText = Self.editText(for: amount)
                    isEditing = true
                } label: {
                    Text(MoneyFormatting.currency(amount, code: currencyCode))
                        .font(font)
                        .foregroundStyle(foregroundColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .frame(minWidth: minWidth, alignment: frameAlignment)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit amount")
            }
        }
        .onAppear {
            draftText = Self.editText(for: amount)
        }
        .onChange(of: amount) { _, newValue in
            guard !isEditing else { return }
            draftText = Self.editText(for: newValue)
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, isEditing {
                commit()
                isEditing = false
            }
        }
    }

    private func commitAndClose() {
        commit()
        isEditing = false
        isFocused = false
    }

    private func commit() {
        guard let value = Self.parseAmount(draftText) else {
            draftText = Self.editText(for: amount)
            return
        }
        amount = max(0, value)
        draftText = Self.editText(for: amount)
    }

    private static func editText(for amount: Double) -> String {
        if amount.rounded(.down) == amount {
            return String(Int(amount))
        }
        return String(format: "%.2f", amount)
    }

    private static func parseAmount(_ text: String) -> Double? {
        let allowed = Set("0123456789.,-")
        var cleaned = String(text.filter { allowed.contains($0) })
        if cleaned.contains(",") && cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        }
        return Double(cleaned)
    }
}

private struct BudgetAdjustableMoneyRow: View {
    let title: String
    let subtitle: String
    @Binding var amount: Double
    let currencyCode: String
    let symbolName: String
    let tint: Color
    let step: Double

    var body: some View {
        HStack(alignment: .center, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: LifeTrackTheme.Spacing.small)

            VStack(alignment: .trailing, spacing: 8) {
                BudgetAmountEditor(
                    amount: $amount,
                    currencyCode: currencyCode,
                    foregroundColor: LifeTrackTheme.ColorPalette.primaryText,
                    font: .subheadline.weight(.bold),
                    minWidth: 96,
                    textAlignment: .trailing,
                    frameAlignment: .trailing
                )

                HStack(spacing: 7) {
                    amountButton(systemName: "minus") {
                        amount = max(0, amount - step)
                    }
                    amountButton(systemName: "plus") {
                        amount += step
                    }
                }
            }
            .frame(minWidth: 96, alignment: .trailing)
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.8)
        }
    }

    private func amountButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 29, height: 29)
                .background(tint.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "plus" ? "Increase amount" : "Decrease amount")
    }
}

private struct BudgetAdjustableMoneyTile: View {
    let title: String
    @Binding var amount: Double
    let currencyCode: String
    let symbolName: String
    let tint: Color
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12), in: Circle())

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            BudgetAmountEditor(
                amount: $amount,
                currencyCode: currencyCode,
                foregroundColor: LifeTrackTheme.ColorPalette.primaryText,
                font: .headline.weight(.bold),
                minWidth: 112,
                textAlignment: .leading,
                frameAlignment: .leading
            )

            HStack(spacing: 8) {
                amountButton(systemName: "minus") {
                    amount = max(0, amount - step)
                }
                amountButton(systemName: "plus") {
                    amount += step
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.8)
        }
    }

    private func amountButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 31, height: 31)
                .background(tint.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "plus" ? "Increase amount" : "Decrease amount")
    }
}

private struct BudgetGoalRow: View {
    let title: String
    let target: Double
    let current: Double
    @Binding var contribution: Double
    let currencyCode: String
    let symbolName: String
    let tint: Color
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: LifeTrackTheme.IconSize.mediumCircle, height: LifeTrackTheme.IconSize.mediumCircle)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Text("Target \(MoneyFormatting.currency(target, code: currencyCode))")
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }

                Spacer(minLength: LifeTrackTheme.Spacing.small)

                VStack(alignment: .trailing, spacing: 4) {
                    BudgetAmountEditor(
                        amount: $contribution,
                        currencyCode: currencyCode,
                        foregroundColor: tint,
                        font: .subheadline.weight(.bold),
                        minWidth: 104,
                        textAlignment: .trailing,
                        frameAlignment: .trailing
                    )
                    Text("Monthly")
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                }
            }

            HStack(spacing: 8) {
                Button {
                    contribution = max(0, contribution - step)
                } label: {
                    Label("Decrease", systemImage: "minus")
                        .labelStyle(.iconOnly)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(width: 31, height: 31)
                        .background(tint.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    contribution += step
                } label: {
                    Label("Increase", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(width: 31, height: 31)
                        .background(tint.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LifeTrackTheme.ColorPalette.hairline.opacity(0.55))
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * min(max((current + contribution) / max(target, 1), 0), 1))
                }
            }
            .frame(height: 7)
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.8)
        }
    }
}

private struct BudgetSnapshotTile: View {
    let title: String
    let value: Double
    let currencyCode: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.13), in: Circle())

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
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.78), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.8)
        }
    }
}

private struct BudgetPlanToggleRow: View {
    let title: String
    let symbolName: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: LifeTrackTheme.Spacing.medium) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .frame(width: 38, height: 38)
                    .background(LifeTrackTheme.ColorPalette.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(LifeTrackTheme.ColorPalette.accent)
        .padding(10)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.8)
        }
    }
}

private struct BudgetPreviewChart: View {
    struct Value: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
        let tint: Color
        let isOutline: Bool
    }

    let currencyCode: String
    let values: [Value]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cash flow this month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

            GeometryReader { proxy in
                let maxAmount = max(values.map(\.amount).max() ?? 1, 1)

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(values) { value in
                        VStack(spacing: 7) {
                            Text(compactAmount(value.amount))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(value.isOutline ? Color.clear : value.tint.opacity(0.72))
                                .overlay {
                                    if value.isOutline {
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(value.tint, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                                            .background(value.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    }
                                }
                                .frame(height: max(16, (proxy.size.height - 42) * CGFloat(value.amount / maxAmount)))

                            Text(value.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 142)
        }
        .padding(12)
        .background(LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.8)
        }
    }

    private func compactAmount(_ amount: Double) -> String {
        if amount >= 1_000 {
            return "\(MoneyFormatting.currency(amount / 1_000, code: currencyCode))K"
        }
        return MoneyFormatting.currency(amount, code: currencyCode)
    }
}

private struct BudgetAutomationChoice: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 11) {
                    Image(systemName: symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? LifeTrackTheme.ColorPalette.accent : LifeTrackTheme.ColorPalette.secondaryText)
                        .frame(width: 46, height: 46)
                        .background((isSelected ? LifeTrackTheme.ColorPalette.accentSoft : LifeTrackTheme.ColorPalette.backgroundTop), in: Circle())

                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                        .lineLimit(4)
                        .minimumScaleFactor(0.76)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
            .background(isSelected ? LifeTrackTheme.ColorPalette.accentSoft.opacity(0.5) : LifeTrackTheme.ColorPalette.backgroundTop.opacity(0.72), in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous)
                    .stroke(isSelected ? LifeTrackTheme.ColorPalette.accent.opacity(0.8) : LifeTrackTheme.ColorPalette.hairline.opacity(0.75), lineWidth: 0.9)
            }
        }
        .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.98, pressedOpacity: 0.94))
    }
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

private struct MoneyCompactEmptyState: View {
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

private struct MoneyCompactBillRow: View {
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

private struct MoneyCompactCategoryRow: View {
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
