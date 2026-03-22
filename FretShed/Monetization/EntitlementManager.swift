// EntitlementManager.swift
// FretShed — Monetization Layer
//
// Central authority for premium entitlement status.
// Uses StoreKit 2 to check subscriptions and lifetime purchase.
//
// Free tier (isPremium = false):
//   - Focus modes: Full Fretboard + Single String only
//   - Strings: 4–6 only
//   - Frets: 0–12
//   - Audio detection: ON
//   - Adaptive scoring: ON
//   - Full stats access
//   - Calibration (all input sources): ON
//   - Single calibration profile
//
// Premium (isPremium = true):
//   - All focus modes (adds Same Note, Fretboard Position, Natural Notes, Sharps & Flats)
//   - All 6 strings, all frets (0–24)
//   - Multiple saved calibration profiles
//   - Phase 2+ (Expansion, Connection, Fluency)

import Foundation
import StoreKit
import TelemetryDeck
import OSLog

private let logger = Logger(subsystem: "com.jpm.fretshed", category: "EntitlementManager")

// MARK: - EntitlementManager

@MainActor
@Observable
public final class EntitlementManager {

    // MARK: Product IDs

    static let monthlyID  = "com.jpm.fretshed.subscription.monthly"
    static let annualID   = "com.jpm.fretshed.subscription.annual"
    static let lifetimeID = "com.jpm.fretshed.lifetime"

    private static let allProductIDs: Set<String> = [monthlyID, annualID, lifetimeID]
    private static let subscriptionIDs: Set<String> = [monthlyID, annualID]

    // MARK: Public State

    /// True when the user has an active subscription or lifetime purchase.
    public private(set) var isPremium: Bool = false

    /// StoreKit products loaded from the App Store, sorted for display.
    public private(set) var products: [Product] = []

    /// User-facing error message from the last failed purchase attempt.
    public private(set) var purchaseError: String?

    /// Returns true if the given learning phase requires premium.
    /// Free tier: Phases 1 (Foundation) and 2 (Expansion) only.
    /// Premium: Phases 3 (Connection) and 4 (Fluency).
    func requiresPremium(for phase: LearningPhase) -> Bool {
        guard !isPremium else { return false }
        return phase == .connection || phase == .fluency
    }

    // MARK: Private

    private var updateTask: Task<Void, Never>?

    // MARK: Init

    public init() {
        // Listen for transaction updates (renewals, revocations, etc.)
        updateTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if case .verified = result {
                    await self.checkEntitlement()
                }
            }
        }

        // Load products and check entitlement on startup
        Task {
            await loadProducts()
            await checkEntitlement()
        }
    }


    // MARK: - Load Products

    /// Fetches the 3 IAP products from StoreKit.
    public func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)
            // Sort: monthly first, annual, lifetime last
            products = storeProducts.sorted { a, b in
                let order: [String: Int] = [
                    Self.monthlyID: 0,
                    Self.annualID: 1,
                    Self.lifetimeID: 2
                ]
                return (order[a.id] ?? 3) < (order[b.id] ?? 3)
            }
            logger.info("Loaded \(self.products.count) products from StoreKit")
        } catch {
            logger.error("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    /// Initiates a purchase for the given product.
    public func purchase(_ product: Product) async throws {
        purchaseError = nil

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                TelemetryDeck.signal(AnalyticsEvent.subscriptionStarted)
                await checkEntitlement()
                logger.info("Purchase successful: \(product.id)")
            case .unverified(_, let error):
                purchaseError = "Purchase could not be verified."
                logger.error("Unverified transaction: \(error)")
            }
        case .userCancelled:
            logger.info("User cancelled purchase")
        case .pending:
            purchaseError = "Purchase is pending approval."
            logger.info("Purchase pending (Ask to Buy)")
        @unknown default:
            purchaseError = "An unexpected error occurred."
            logger.warning("Unknown purchase result")
        }
    }

    // MARK: - Restore

    /// Restores previous purchases by syncing with the App Store.
    public func restorePurchases() async {
        TelemetryDeck.signal(AnalyticsEvent.restoreTapped)
        do {
            try await AppStore.sync()
            await checkEntitlement()
            logger.info("Purchases restored")
        } catch {
            purchaseError = "Could not restore purchases. Check your internet connection."
            logger.error("Restore failed: \(error)")
        }
    }

    // MARK: - Entitlement Check

    /// Verifies current entitlement by iterating all verified transactions.
    public func checkEntitlement() async {
        var hasEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            // Check for active subscription
            if Self.subscriptionIDs.contains(transaction.productID) {
                if transaction.revocationDate == nil {
                    hasEntitlement = true
                }
            }

            // Check for lifetime purchase (non-consumable)
            if transaction.productID == Self.lifetimeID {
                if transaction.revocationDate == nil {
                    hasEntitlement = true
                }
            }
        }

        isPremium = hasEntitlement
        logger.info("Entitlement check: isPremium = \(self.isPremium)")
    }
}
