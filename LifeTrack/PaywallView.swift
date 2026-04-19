//
//  PaywallView.swift
//  LifeTrack
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    let requiredTier: SubscriptionTier
    let featureName: String

    @State private var selectedBilling: BillingPeriod = .yearly
    @State private var selectedTier: SubscriptionTier

    init(requiredTier: SubscriptionTier = .standard, featureName: String = "Pro Features") {
        self.requiredTier = requiredTier
        self.featureName = featureName
        _selectedTier = State(initialValue: requiredTier)
    }

    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly  = "Yearly"
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            LifeTrackTheme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    billingToggle
                    tierCards
                    footerLinks
                        .padding(.bottom, LifeTrackTheme.Spacing.xxLarge)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText.opacity(0.7))
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(LifeTrackTheme.Spacing.xLarge)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.07, blue: 0.24),
                    Color(red: 0.06, green: 0.04, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 14) {
                Spacer().frame(height: 48)

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 6) {
                    Text("Unlock \(featureName)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Choose a plan to access this feature and many more.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 24)
            }
        }
        .frame(height: 220)
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(BillingPeriod.allCases, id: \.self) { period in
                    Button {
                        withAnimation(.snappy(duration: 0.22)) { selectedBilling = period }
                    } label: {
                        HStack(spacing: 6) {
                            Text(period.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedBilling == period
                                    ? LifeTrackTheme.ColorPalette.primaryText
                                    : LifeTrackTheme.ColorPalette.secondaryText)

                            if period == .yearly {
                                Text("Save up to 38%")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(LifeTrackTheme.ColorPalette.accent, in: Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedBilling == period
                            ? LifeTrackTheme.ColorPalette.card
                            : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(LifeTrackTheme.ColorPalette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        .padding(.top, LifeTrackTheme.Spacing.large)
        .padding(.bottom, LifeTrackTheme.Spacing.medium)
    }

    // MARK: - Tier Cards

    private var tierCards: some View {
        VStack(spacing: LifeTrackTheme.Spacing.medium) {
            TierCard(
                tier: .standard,
                billing: selectedBilling,
                isSelected: selectedTier == .standard,
                isCurrentTier: subscriptionManager.tier == .standard,
                onSelect: { selectedTier = .standard },
                onPurchase: { await purchaseSelected(.standard) }
            )

            TierCard(
                tier: .ultimate,
                billing: selectedBilling,
                isSelected: selectedTier == .ultimate,
                isCurrentTier: subscriptionManager.tier == .ultimate,
                onSelect: { selectedTier = .ultimate },
                onPurchase: { await purchaseSelected(.ultimate) }
            )
        }
        .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 16) {
            Button {
                Task { await subscriptionManager.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LifeTrackTheme.ColorPalette.accent)
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                Text("·")
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)

                Link("Privacy Policy", destination: URL(string: "https://currenttech.app/privacy")!)
                    .font(.caption)
                    .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
            }

            Text("Subscriptions renew automatically. Cancel anytime in Settings.")
                .font(.caption2)
                .foregroundStyle(LifeTrackTheme.ColorPalette.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, LifeTrackTheme.Spacing.xLarge)
        }
        .padding(.top, LifeTrackTheme.Spacing.large)
    }

    // MARK: - Purchase

    private func purchaseSelected(_ tier: SubscriptionTier) async {
        let productID = productID(for: tier, billing: selectedBilling)
        guard let product = subscriptionManager.product(for: productID) else { return }
        await subscriptionManager.purchase(product)
        if subscriptionManager.tier >= tier { dismiss() }
    }

    private func productID(for tier: SubscriptionTier, billing: BillingPeriod) -> String {
        switch (tier, billing) {
        case (.standard, .monthly): return SubscriptionManager.ProductID.standardMonthly
        case (.standard, .yearly):  return SubscriptionManager.ProductID.standardYearly
        case (.ultimate, .monthly): return SubscriptionManager.ProductID.ultimateMonthly
        case (.ultimate, .yearly):  return SubscriptionManager.ProductID.ultimateYearly
        default: return ""
        }
    }
}

// MARK: - Tier Card

private struct TierCard: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    let tier: SubscriptionTier
    let billing: PaywallView.BillingPeriod
    let isSelected: Bool
    let isCurrentTier: Bool
    let onSelect: () -> Void
    let onPurchase: () async -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(tier.displayName)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                            if isCurrentTier {
                                Text("CURRENT")
                                    .font(.caption2.weight(.heavy))
                                    .tracking(0.5)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(tier.accentColor, in: Capsule())
                            }
                        }

                        Text(tier.tagline)
                            .font(.caption)
                            .foregroundStyle(LifeTrackTheme.ColorPalette.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(billing == .monthly ? tier.monthlyPriceLabel : tier.yearlyPriceLabel)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)

                        if billing == .yearly && !tier.yearlyMonthlyCost.isEmpty {
                            Text(tier.yearlyMonthlyCost)
                                .font(.caption2)
                                .foregroundStyle(tier.accentColor)
                        }
                    }
                }
                .padding(LifeTrackTheme.Spacing.medium)

                Divider()
                    .padding(.horizontal, LifeTrackTheme.Spacing.medium)

                // Features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tier.features) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(feature.color)
                                .frame(width: 18)
                            Text(feature.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(LifeTrackTheme.ColorPalette.primaryText)
                        }
                    }
                }
                .padding(LifeTrackTheme.Spacing.medium)

                // CTA
                if !isCurrentTier {
                    Button {
                        Task { await onPurchase() }
                    } label: {
                        Group {
                            if subscriptionManager.isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text(billing == .yearly
                                     ? "Start \(tier.displayName) · \(tier.yearlyPriceLabel)"
                                     : "Start \(tier.displayName) · \(tier.monthlyPriceLabel)")
                                    .font(.subheadline.weight(.bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(tier.badgeGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, LifeTrackTheme.Spacing.medium)
                    .padding(.bottom, LifeTrackTheme.Spacing.medium)
                    .disabled(subscriptionManager.isPurchasing)
                }
            }
            .background(LifeTrackTheme.ColorPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? tier.accentColor : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}
