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

    func refreshTier() async {
        var highest: SubscriptionTier = .free
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, !tx.isUpgraded {
                let t = tier(for: tx.productID)
                if t > highest { highest = t }
            }
        }
        tier = highest
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
                    await refreshTier()
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
