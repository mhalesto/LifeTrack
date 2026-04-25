import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct BudgetPlanReviewView: View {
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

enum BudgetAutomationMode {
    case reviewMonthly
    case autoRoll
}

enum BudgetDataMethod {
    case manual
    case importStatement
}

nonisolated private enum BudgetStatementImportError: LocalizedError {
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

nonisolated private enum BudgetStatementImporter {
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

enum BudgetPlanFeature: String, CaseIterable, Identifiable {
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

struct BudgetIncomeDraft: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var amount: Double
    var symbolName: String
    var tint: Color
}

struct BudgetBillDraft: Identifiable {
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

struct BudgetSimpleMoneyDraft: Identifiable {
    let id = UUID()
    var title: String
    var amount: Double
    var symbolName: String
    var tint: Color
}

struct BudgetGoalDraft: Identifiable {
    let id = UUID()
    var title: String
    var target: Double
    var current: Double
    var contribution: Double
    var symbolName: String
    var tint: Color
}

struct BudgetDebtDraft: Identifiable {
    let id = UUID()
    var title: String
    var balance: Double
    var minimumPayment: Double
    var symbolName: String
}

struct BudgetMonthSelectorRow: View {
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

struct BudgetSegmentedOptions: View {
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

struct BudgetSelectableChip: View {
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

struct BudgetMethodCard: View {
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

struct BudgetSetupRow: View {
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

struct BudgetAmountEditor: View {
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

struct BudgetAdjustableMoneyRow: View {
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

struct BudgetAdjustableMoneyTile: View {
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

struct BudgetGoalRow: View {
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

struct BudgetSnapshotTile: View {
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

struct BudgetPlanToggleRow: View {
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

struct BudgetPreviewChart: View {
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

struct BudgetAutomationChoice: View {
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
