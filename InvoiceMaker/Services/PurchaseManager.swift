import Foundation
import Observation
import RevenueCat
import StoreKit

/// Premium state and buying. RevenueCat when its key is set (entitlement `pro`),
/// otherwise StoreKit 2 directly (StoreKit config file / sandbox testing).
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    static let entitlement = "pro"
    static let monthlyID = "im_standard_monthly"
    static let yearlyID = "im_standard_yearly"

    private(set) var isPremium = false
    private(set) var usesRevenueCat = false
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
        } else {
            Task { await listenToStoreKit() }
        }
        Task { await loadPlans() }
    }

    // MARK: Entitlement

    private func listenToRevenueCat() async {
        for await info in Purchases.shared.customerInfoStream {
            update(premium: info.entitlements[Self.entitlement]?.isActive == true)
        }
    }

    private func listenToStoreKit() async {
        await refreshStoreKitEntitlement()
        for await update in Transaction.updates {
            if case .verified(let transaction) = update { await transaction.finish() }
            await refreshStoreKitEntitlement()
        }
    }

    private func refreshStoreKitEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, [Self.monthlyID, Self.yearlyID].contains(t.productID), t.revocationDate == nil {
                active = true
            }
        }
        update(premium: active)
    }

    private func update(premium: Bool) {
        isPremium = premium || forcedPremium
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
            update(premium: info?.entitlements[Self.entitlement]?.isActive == true)
        } else {
            try? await AppStore.sync()
            await refreshStoreKitEntitlement()
        }
        return isPremium
    }

    // MARK: Account link

    func logIn(userID: String) async {
        guard usesRevenueCat else { return }
        _ = try? await Purchases.shared.logIn(userID)
    }

    func logOut() async {
        guard usesRevenueCat, !Purchases.shared.isAnonymous else { return }
        _ = try? await Purchases.shared.logOut()
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
