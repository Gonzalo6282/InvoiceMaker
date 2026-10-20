import Foundation
import Observation
import RevenueCat
import StoreKit

/// Premium state and buying. RevenueCat when its key is set (entitlement `pro`),
/// otherwise StoreKit 2 directly (StoreKit config file / sandbox testing).
/// Premium is active when RevenueCat's entitlement OR Apple's own verified
/// transactions say so, so a purchase unlocks even if RevenueCat lags or its
/// products aren't set up yet.
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    /// Superwall's entitlement name (its products are tagged `pro`).
    static let entitlement = "pro"
    /// RevenueCat entitlement identifiers that mean Premium (the dashboard's is
    /// `duly_pro`, display name "Duly Pro"; `pro` kept for safety).
    static let revenueCatEntitlements: Set<String> = ["duly_pro", "pro"]

    static func hasPremium(_ info: CustomerInfo?) -> Bool {
        guard let info else { return false }
        return !revenueCatEntitlements.isDisjoint(with: info.entitlements.active.keys)
    }
    static let monthlyID = "im_standard_monthly"
    static let yearlyID = "im_standard_yearly"

    private(set) var isPremium = false
    private(set) var usesRevenueCat = false
    private var revenueCatPremium = false
    private var storeKitPremium = false
    /// Plans for the native paywall.
    private(set) var plans: [Plan] = []
    /// Optional override from UI tests (`-premium`).
    private var forcedPremium = false

    struct Plan: Identifiable, Equatable {
        let id: String
        let isYearly: Bool
        let price: String
        /// Price per month, for the yearly plan's "a month" line.
        let monthlyPrice: String?
        let trialDays: Int?
        let rcPackage: RevenueCat.Package?
        let skProduct: StoreKit.Product?

        static func == (a: Plan, b: Plan) -> Bool { a.id == b.id && a.price == b.price }
    }

    enum PurchaseOutcome { case purchased, cancelled, pending, failed(String) }

    func configure(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if arguments.contains("-premium") { forcedPremium = true; isPremium = true }
        if let key = AppKeys.revenueCat {
            Purchases.logLevel = .warn
            Purchases.configure(with: Configuration.Builder(withAPIKey: key).with(storeKitVersion: .storeKit2).build())
            Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()
            usesRevenueCat = true
            Task { await listenToRevenueCat() }
            // RevenueCat finishes transactions; we only read Apple's current entitlements.
            Task { await refreshStoreKitEntitlement() }
        } else {
            Task { await listenToStoreKit() }
        }
        Task { await loadPlans() }
    }

    // MARK: Entitlement

    private func listenToRevenueCat() async {
        for await info in Purchases.shared.customerInfoStream {
            revenueCatPremium = Self.hasPremium(info)
            await refreshStoreKitEntitlement()
        }
    }

    private func listenToStoreKit() async {
        await refreshStoreKitEntitlement()
        for await update in Transaction.updates {
            if case .verified(let transaction) = update { await transaction.finish() }
            await refreshStoreKitEntitlement()
        }
    }

    /// Apple's verified, unrevoked, unexpired subscriptions for our products.
    func refreshStoreKitEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, [Self.monthlyID, Self.yearlyID].contains(t.productID), t.revocationDate == nil,
                (t.expirationDate ?? .distantFuture) > .now
            {
                active = true
            }
        }
        storeKitPremium = active
        recompute()
    }

    private func recompute() {
        isPremium = revenueCatPremium || storeKitPremium || forcedPremium
        PaywallService.shared.updateSubscriptionStatus(isPremium: isPremium)
    }

    // MARK: Plans

    func loadPlans() async {
        if usesRevenueCat, let offering = try? await Purchases.shared.offerings().current {
            plans = [offering.annual, offering.monthly].compactMap { $0 }.map { package in
                let product = package.storeProduct
                let yearly = package.packageType == .annual
                return Plan(
                    id: product.productIdentifier, isYearly: yearly, price: product.localizedPriceString,
                    monthlyPrice: yearly ? product.localizedPricePerMonth : nil,
                    trialDays: product.introductoryDiscount.flatMap { $0.paymentMode == .freeTrial ? $0.subscriptionPeriod.days : nil },
                    rcPackage: package, skProduct: nil)
            }
        } else if let products = try? await Product.products(for: [Self.yearlyID, Self.monthlyID]) {
            plans = products.sorted { $0.id == Self.yearlyID && $1.id != Self.yearlyID }.map { product in
                let yearly = product.id == Self.yearlyID
                let perMonth = (product.price / 12).formatted(product.priceFormatStyle)
                let trial = product.subscription?.introductoryOffer.flatMap { offer in
                    offer.paymentMode == .freeTrial ? offer.period.days : nil
                }
                return Plan(
                    id: product.id, isYearly: yearly, price: product.displayPrice, monthlyPrice: yearly ? perMonth : nil,
                    trialDays: trial, rcPackage: nil, skProduct: product)
            }
        }
    }

    // MARK: Buy / restore

    func purchase(_ plan: Plan) async -> PurchaseOutcome {
        do {
            if let package = plan.rcPackage {
                let result = try await Purchases.shared.purchase(package: package)
                revenueCatPremium = Self.hasPremium(result.customerInfo)
                await refreshStoreKitEntitlement()
                return result.userCancelled ? .cancelled : .purchased
            }
            guard let product = plan.skProduct else { return .failed(String(localized: "This plan isn't available right now.")) }
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification { await transaction.finish() }
                await refreshStoreKitEntitlement()
                return .purchased
            case .userCancelled: return .cancelled
            case .pending: return .pending
            @unknown default: return .cancelled
            }
        } catch let error as RevenueCat.ErrorCode where error == .paymentPendingError {
            return .pending
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Returns true if Premium is active afterwards.
    func restore() async -> Bool {
        if usesRevenueCat {
            let info = try? await Purchases.shared.restorePurchases()
            revenueCatPremium = Self.hasPremium(info)
        } else {
            try? await AppStore.sync()
        }
        await refreshStoreKitEntitlement()
        return isPremium
    }

    // MARK: Diagnostics (debug builds)

    /// What each source says right now, for the debug panel and the console.
    func diagnostics() async -> [String] {
        var lines = ["Premium (app): \(isPremium)  RevenueCat: \(revenueCatPremium)  Apple: \(storeKitPremium)"]
        if usesRevenueCat, let info = try? await Purchases.shared.customerInfo() {
            lines.append("RevenueCat user: \(Purchases.shared.appUserID)")
            lines.append("RevenueCat active entitlements: \(info.entitlements.active.keys.sorted())")
            lines.append("RevenueCat all entitlements: \(info.entitlements.all.keys.sorted())")
            lines.append("RevenueCat active subscriptions: \(info.activeSubscriptions.sorted())")
            lines.append("RevenueCat purchased products: \(info.allPurchasedProductIdentifiers.sorted())")
        } else {
            lines.append("RevenueCat: \(usesRevenueCat ? "customerInfo failed" : "not configured")")
        }
        var current = 0
        for await result in Transaction.currentEntitlements {
            current += 1
            switch result {
            case .verified(let t):
                lines.append("Apple entitlement ✓ \(t.productID) env=\(t.environment.rawValue) expires=\(t.expirationDate?.formatted() ?? "-") revoked=\(t.revocationDate != nil)")
            case .unverified(let t, let error):
                lines.append("Apple entitlement ✗ UNVERIFIED \(t.productID): \(error)")
            }
        }
        var all = 0
        for await _ in Transaction.all { all += 1 }
        lines.append("Apple current entitlements: \(current), all transactions: \(all)")
        lines.append("Superwall status: \(PaywallService.shared.statusDescription)")
        for line in lines { print("[Duly purchases] \(line)") }
        return lines
    }

    // MARK: Account link

    func logIn(userID: String) async {
        guard usesRevenueCat else { return }
        _ = try? await Purchases.shared.logIn(userID)
        PaywallService.shared.identify(userID: Purchases.shared.appUserID)
    }

    func logOut() async {
        guard usesRevenueCat, !Purchases.shared.isAnonymous else { return }
        _ = try? await Purchases.shared.logOut()
        PaywallService.shared.resetIdentity()
    }
}

extension RevenueCat.SubscriptionPeriod {
    var days: Int {
        switch unit {
        case .day: value
        case .week: value * 7
        case .month: value * 30
        case .year: value * 365
        @unknown default: value
        }
    }
}

extension StoreKit.Product.SubscriptionPeriod {
    var days: Int {
        switch unit {
        case .day: value
        case .week: value * 7
        case .month: value * 30
        case .year: value * 365
        @unknown default: value
        }
    }
}
