//
//  SubscriptionManager.swift
//  LifeTrack
//

import Combine
import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var tier: SubscriptionTier = .free
    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var purchaseError: String?

    private var listenerTask: Task<Void, Never>?

    // MARK: - Product IDs

    enum ProductID {
        static let standardMonthly = "com.currenttech.lifetrack.standard.monthly"
        static let standardYearly  = "com.currenttech.lifetrack.standard.yearly"
        static let ultimateMonthly = "com.currenttech.lifetrack.ultimate.monthly"
        static let ultimateYearly  = "com.currenttech.lifetrack.ultimate.yearly"

        static let all: [String] = [standardMonthly, standardYearly, ultimateMonthly, ultimateYearly]
    }

    // MARK: - Init

    init() {
        startTransactionListener()
        Task { await bootstrap() }
    }

    deinit {
        listenerTask?.cancel()
    }

    // MARK: - Public API

    func bootstrap() async {
        async let p: () = loadProducts()
        async let t: () = refreshTier()
        _ = await (p, t)
    }

    func loadProducts() async {
        guard let loaded = try? await Product.products(for: ProductID.all) else { return }
        products = loaded.sorted { $0.price < $1.price }
    }

    func refreshTier(floor: SubscriptionTier = .free) async {
        var highest: SubscriptionTier = .free
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, !tx.isUpgraded {
                let t = tier(for: tx.productID)
                if t > highest { highest = t }
            }
        }
        // `floor` lets callers preserve an eagerly-set tier when
        // Transaction.currentEntitlements hasn't caught up yet (StoreKit
        // Testing / sandbox occasionally lag by a brief moment).
        tier = max(highest, floor)
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    // Set tier eagerly from the just-verified transaction so the
                    // UI reflects the purchase without waiting for
                    // Transaction.currentEntitlements to catch up (which can
                    // lag briefly in StoreKit Testing and sandbox).
                    let purchasedTier = tier(for: tx.productID)
                    if purchasedTier > self.tier {
                        self.tier = purchasedTier
                    }
                    // Reconcile shortly after so a revoked / upgraded
                    // entitlement correctly downgrades the tier.
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        await self.refreshTier(floor: purchasedTier)
                    }
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
        await refreshTier()
    }

    // MARK: - Helpers

    func product(for productID: String) -> Product? {
        products.first { $0.id == productID }
    }

    func standardMonthlyProduct() -> Product? { product(for: ProductID.standardMonthly) }
    func standardYearlyProduct()  -> Product? { product(for: ProductID.standardYearly)  }
    func ultimateMonthlyProduct() -> Product? { product(for: ProductID.ultimateMonthly) }
    func ultimateYearlyProduct()  -> Product? { product(for: ProductID.ultimateYearly)  }

    // MARK: - Private

    private func startTransactionListener() {
        listenerTask = Task { @MainActor in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await refreshTier()
                }
            }
        }
    }

    private func tier(for productID: String) -> SubscriptionTier {
        switch productID {
        case ProductID.ultimateMonthly, ProductID.ultimateYearly: return .ultimate
        case ProductID.standardMonthly, ProductID.standardYearly: return .standard
        default: return .free
        }
    }
}

// MARK: - Daily API Budget

/// Tracks Claude API call count per day and enforces a tier-based cap.
/// Persists across launches in UserDefaults. Resets at local midnight.
@MainActor
final class APIBudgetTracker: ObservableObject {
    static let shared = APIBudgetTracker()

    @Published private(set) var usedToday: Int = 0

    private enum Key {
        static let count = "LifeTrack.api.budget.countToday"
        static let date  = "LifeTrack.api.budget.date"
    }

    private init() {
        rollIfNewDay()
        usedToday = UserDefaults.standard.integer(forKey: Key.count)
    }

    /// Calls allowed per day for the current subscription tier.
    /// The user provides their own Claude API key, so this is a safety cap
    /// against runaway loops rather than a commercial meter.
    var capToday: Int {
        switch SubscriptionManager.shared.tier {
        case .free:     return 10
        case .standard: return 50
        case .ultimate: return 250
        }
    }

    var remainingToday: Int {
        max(0, capToday - usedToday)
    }

    /// Increment the daily counter by one. Throws if the cap is reached.
    func consumeOne() throws {
        rollIfNewDay()
        let current = UserDefaults.standard.integer(forKey: Key.count)
        let cap = capToday
        if current >= cap {
            throw ClaudeAPIClient.ClientError.budgetExceeded(used: current, cap: cap)
        }
        let next = current + 1
        UserDefaults.standard.set(next, forKey: Key.count)
        usedToday = next
    }

    /// Reset the counter manually (e.g. from a Settings debug button).
    func reset() {
        UserDefaults.standard.set(0, forKey: Key.count)
        UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: Key.date)
        usedToday = 0
    }

    private func rollIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let saved = (UserDefaults.standard.object(forKey: Key.date) as? Date)
            .map { Calendar.current.startOfDay(for: $0) }
        if saved != today {
            UserDefaults.standard.set(today, forKey: Key.date)
            UserDefaults.standard.set(0, forKey: Key.count)
            usedToday = 0
        }
    }
}
