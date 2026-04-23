//
//  MoneyAIInsightsDetailView.swift
//  LifeTrack
//

import SwiftUI

struct MoneyAIInsightsDetailView: View {
    let summary: MoneyMonthlySummary
    let categoryTotals: [MoneyCategoryTotal]
    let spendingCategoryTotals: [MoneyCategoryTotal]
    let plannedBills: [MoneyBillSnapshot]
    let projectionPoints: [MoneyProjectionPoint]
    let projectedBalance: Double
    let daysLeft: Int
    let currencyCode: String
    let lowBalanceThreshold: Double
    let month: Date
    let isPremium: Bool

    @Environment(\.dismiss) private var dismiss
    @StateObject private var advisor = MoneyAIAdvisor()

    @State private var currentFingerprint: String = ""
    @State private var cachedFingerprint: String?
    @State private var cacheDate: Date?
    @State private var showingRefreshConfirm = false
    @State private var didInitialLoad = false

    private var isStale: Bool {
        guard let cached = cachedFingerprint else { return false }
        return cached != currentFingerprint
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LifeTrackTheme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.xLarge) {
                        header

                        if isPremium && advisor.isConfigured && isStale && advisor.deepResult != nil {
                            staleBanner
                        }

                        if !isPremium {
                            paywallCard
                        } else if !advisor.isConfigured {
                            configNoticeCard
                        } else if advisor.isLoadingDeep && advisor.deepResult == nil {
                            loadingCard
                        } else if let result = advisor.deepResult {
                            healthScoreCard(result)
                            if !result.strengths.isEmpty {
                                findingsCard(
                                    title: "What you're doing well",
                                    symbol: "checkmark.seal.fill",
                                    tint: LifeTrackTheme.ColorPalette.success,
                                    findings: result.strengths
                                )
                            }
                            if !result.risks.isEmpty {
                                findingsCard(
                                    title: "Keep an eye on",
                                    symbol: "exclamationmark.triangle.fill",
                                    tint: LifeTrackTheme.ColorPalette.warning,
                                    findings: result.risks
                                )
                            }
                            if !result.improvements.isEmpty {
                                findingsCard(
                                    title: "Ways to improve",
                                    symbol: "lightbulb.fill",
                                    tint: LifeTrackTheme.ColorPalette.accent,
                                    findings: result.improvements
                                )
                            }
                            if !spendingCategoryTotals.isEmpty {
                                planVsActualCard
                            }
                            if !projectionPoints.isEmpty {
                                cashFlowCard
                            }
                            if !result.categoryCommentary.isEmpty {
                                categoryCommentaryCard(result)
                            }
                            closingNoteCard(result)
                        } else if let err = advisor.deepError {
                            errorCard(message: err)
                        } else {
                            loadingCard
                        }
                    }
                    .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
                    .padding(.top, LifeTrackTheme.Spacing.large)
                    .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    }
                }
                if isPremium && advisor.isConfigured {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if advisor.deepResult == nil {
                                performRefresh()
                            } else {
                                showingRefreshConfirm = true
                            }
                        } label: {
                            if advisor.isLoadingDeep {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(LifeTrackTheme.ColorPalette.accent)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(isStale ? LifeTrackTheme.ColorPalette.warning : LifeTrackTheme.ColorPalette.accent)
                            }
                        }
                        .disabled(advisor.isLoadingDeep)
                        .accessibilityLabel("Refresh AI analysis")
                    }
                }
            }
            .confirmationDialog(
                "Refresh AI analysis?",
                isPresented: $showingRefreshConfirm,
                titleVisibility: .visible
            ) {
                Button("Refresh now") { performRefresh() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This uses your Claude API quota. Only refresh if your finance data has changed.")
            }
        }
        .onAppear(perform: handleAppear)
    }

    // MARK: - Stale banner

    private var staleBanner: some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(LifeTrackTheme.ColorPalette.warning, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Your finance data has changed")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text(stalenessSubtitle)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                showingRefreshConfirm = true
            } label: {
                Text("Refresh")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LifeTrackTheme.ColorPalette.accent, in: Capsule())
            }
            .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.94))
            .disabled(advisor.isLoadingDeep)
        }
        .padding(LifeTrackTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .fill(LifeTrackTheme.ColorPalette.warning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
                .stroke(LifeTrackTheme.ColorPalette.warning.opacity(0.35), lineWidth: 1)
        )
    }

    private var stalenessSubtitle: String {
        if let cacheDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let rel = formatter.localizedString(for: cacheDate, relativeTo: Date())
            return "This review was generated \(rel). Refresh to reflect your latest entries."
        }
        return "Refresh to reflect your latest entries."
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                Text("LifeTrack AI")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    .tracking(0.6)
                    .textCase(.uppercase)
            }
            Text("Your financial review")
                .font(.lifeTrackHero)
                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
            Text("A deeper look at \(MoneyAnalytics.monthTitle(for: month)) — what's working, what's at risk, and how to improve.")
                .font(.subheadline)
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Health score

    private func healthScoreCard(_ result: MoneyAIDeepInsight) -> some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.large) {
                HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.large) {
                    MoneyAIHealthRing(score: result.healthScore, tint: ratingTint(result.rating))
                        .frame(width: 104, height: 104)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.rating.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(ratingTint(result.rating), in: Capsule())

                        Text(result.headline)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Based on income, planned spend, savings, bills, and \(daysLeft) days remaining.")
                            .font(.caption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }
                    Spacer(minLength: 0)
                }

                Divider()

                HStack(spacing: 0) {
                    MoneyAIStat(
                        title: "Projected balance",
                        value: MoneyFormatting.currency(projectedBalance, code: currencyCode),
                        tint: projectedBalance >= 0 ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.danger
                    )
                    Divider().frame(height: 42)
                    MoneyAIStat(
                        title: "Spend variance",
                        value: MoneyFormatting.signedCurrency(summary.spendingVariance, code: currencyCode),
                        tint: summary.spendingVariance <= 0 ? LifeTrackTheme.ColorPalette.success : LifeTrackTheme.ColorPalette.danger
                    )
                    Divider().frame(height: 42)
                    MoneyAIStat(
                        title: "Saved",
                        value: MoneyFormatting.currency(summary.actualSavings, code: currencyCode),
                        tint: LifeTrackTheme.ColorPalette.accent
                    )
                }
            }
        }
    }

    private func ratingTint(_ rating: MoneyAIDeepInsight.Rating) -> Color {
        switch rating {
        case .excellent: return LifeTrackTheme.ColorPalette.success
        case .good: return LifeTrackTheme.ColorPalette.accent
        case .watch: return LifeTrackTheme.ColorPalette.warning
        case .atRisk: return LifeTrackTheme.ColorPalette.danger
        }
    }

    // MARK: - Findings

    private func findingsCard(title: String, symbol: String, tint: Color, findings: [MoneyAIDeepInsight.Finding]) -> some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                HStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(tint, in: Circle())
                    Text(title)
                        .font(.lifeTrackHeadline)
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    ForEach(Array(findings.enumerated()), id: \.element.id) { index, finding in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(finding.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                            Text(finding.detail)
                                .font(.footnote)
                                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)

                        if index != findings.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Plan vs Actual

    private var planVsActualCard: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                SectionHeaderView(
                    title: "Plan vs Actual",
                    subtitle: "Top spending categories this month."
                )

                VStack(spacing: 14) {
                    ForEach(Array(spendingCategoryTotals.prefix(6))) { total in
                        MoneyComparisonBar(
                            title: total.category,
                            planned: total.planned,
                            actual: total.actual,
                            currencyCode: currencyCode,
                            tint: barTint(for: total)
                        )
                    }
                }
            }
        }
    }

    private func barTint(for total: MoneyCategoryTotal) -> Color {
        if total.planned > 0 && total.actual > total.planned {
            return LifeTrackTheme.ColorPalette.danger
        }
        if total.planned > 0 && total.actual >= total.planned * 0.8 {
            return LifeTrackTheme.ColorPalette.warning
        }
        return LifeTrackTheme.ColorPalette.accent
    }

    // MARK: - Cash flow

    private var cashFlowCard: some View {
        SectionCardView {
            MoneyProjectionChart(
                points: projectionPoints,
                currencyCode: currencyCode,
                lowThreshold: lowBalanceThreshold
            )
        }
    }

    // MARK: - Category commentary

    private func categoryCommentaryCard(_ result: MoneyAIDeepInsight) -> some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                SectionHeaderView(
                    title: "Category notes",
                    subtitle: "AI commentary on your biggest spending areas."
                )

                VStack(spacing: 0) {
                    ForEach(Array(result.categoryCommentary.enumerated()), id: \.offset) { index, entry in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "text.quote")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                                .frame(width: 28, height: 28)
                                .background(LifeTrackTheme.ColorPalette.accentSoft, in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.category)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                                Text(entry.comment)
                                    .font(.footnote)
                                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)

                        if index != result.categoryCommentary.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Closing note

    private func closingNoteCard(_ result: MoneyAIDeepInsight) -> some View {
        HStack(alignment: .top, spacing: LifeTrackTheme.Spacing.medium) {
            Image(systemName: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.16), in: Circle())

            Text(result.closingNote)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(LifeTrackTheme.Spacing.large)
        .background(
            LinearGradient(
                colors: [
                    LifeTrackTheme.ColorPalette.primaryText.opacity(0.96),
                    LifeTrackTheme.ColorPalette.secondaryText.opacity(0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.card, style: .continuous)
        )
    }

    // MARK: - Loading / error / paywall / config

    private var loadingCard: some View {
        SectionCardView {
            VStack(spacing: LifeTrackTheme.Spacing.medium) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(LifeTrackTheme.ColorPalette.accent)
                Text("Analysing your finances…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text("This usually takes a few seconds.")
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func errorCard(message: String) -> some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(LifeTrackTheme.ColorPalette.warning)
                    Text("Couldn't load AI review")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                }
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button { performRefresh() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try again")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(LifeTrackTheme.ColorPalette.accent, in: RoundedRectangle(cornerRadius: LifeTrackTheme.Radius.control, style: .continuous))
                }
                .buttonStyle(LifeTrackPressableButtonStyle(scale: 0.96))
            }
        }
    }

    private var paywallCard: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: LifeTrackTheme.Spacing.medium) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
                    Text("Premium feature")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                }
                Text("AI financial reviews are part of LifeTrack Standard. Upgrade to unlock deep monthly analysis, health scores, and tailored improvement tips.")
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var configNoticeCard: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add your Claude API key")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text("Set your Claude API key in Settings to enable the AI financial review.")
                    .font(.footnote)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actions

    private func handleAppear() {
        currentFingerprint = MoneyAIInsightsCache.fingerprint(
            summary: summary,
            categoryTotals: categoryTotals,
            plannedBills: plannedBills,
            projectedBalance: projectedBalance
        )

        if !didInitialLoad {
            didInitialLoad = true
            if let cached = MoneyAIInsightsCache.load(month: month, currencyCode: currencyCode) {
                advisor.deepResult = cached.insight
                cachedFingerprint = cached.fingerprint
                cacheDate = cached.createdAt
                return
            }
            performRefresh()
        }
    }

    private func performRefresh() {
        guard isPremium else { return }
        guard advisor.isConfigured else { return }
        guard !advisor.isLoadingDeep else { return }

        let fingerprintAtStart = currentFingerprint
        Task {
            await advisor.deepAnalyze(
                summary: summary,
                categoryTotals: categoryTotals,
                plannedBills: plannedBills,
                projectedBalance: projectedBalance,
                daysLeft: daysLeft,
                currencyCode: currencyCode,
                month: month
            )
            if let result = advisor.deepResult {
                let entry = MoneyAIInsightsCache.Entry(
                    insight: result,
                    fingerprint: fingerprintAtStart,
                    createdAt: Date()
                )
                MoneyAIInsightsCache.save(entry, month: month, currencyCode: currencyCode)
                cachedFingerprint = fingerprintAtStart
                cacheDate = entry.createdAt
            }
        }
    }
}

// MARK: - Health ring

private struct MoneyAIHealthRing: View {
    let score: Int
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(LifeTrackTheme.ColorPalette.hairline.opacity(0.6), lineWidth: 10)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: score)

            VStack(spacing: 0) {
                Text("\(max(0, min(100, score)))")
                    .font(.system(.title, design: LifeTrackAppTheme.current.fontDesign, weight: .bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                Text("Score")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    .tracking(0.4)
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Stat column

private struct MoneyAIStat: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                .tracking(0.4)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}
