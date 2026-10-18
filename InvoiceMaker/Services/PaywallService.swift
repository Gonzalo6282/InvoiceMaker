import Foundation
import Observation
import RevenueCat
import StoreKit
import SuperwallKit

/// Where paywalls can appear (Superwall placements, spec).
enum PaywallPlacement: String, CaseIterable, Sendable {
    case onboardingEnd = "onboarding_end"
    case invoiceSend = "invoice_send"
    case invoiceExportPDF = "invoice_export_pdf"
    case estimateSend = "estimate_send"
    case templatePremium = "template_premium"
    case settingsUpgrade = "settings_upgrade"

    /// The native paywall's headline for this placement (mockup).
    var headline: String {
        switch self {
        case .invoiceSend: String(localized: "Send this invoice")
        case .estimateSend: String(localized: "Send this estimate")
        case .invoiceExportPDF: String(localized: "Save and print your PDFs")
        case .templatePremium: String(localized: "Unlock every template")
        case .onboardingEnd, .settingsUpgrade: String(localized: "Send invoices that get paid")
        }
    }
}

/// Superwall paywalls (designed in Superwall's editor) with a native fallback
/// so a Premium action never dead-ends: no key, no connection, or an error
/// shows `NativePaywallView` instead.
@MainActor
@Observable
final class PaywallService {
    static let shared = PaywallService()

    private(set) var usesSuperwall = false
    /// Set to show the native paywall sheet (observed by the root view).
    var nativePaywall: NativePaywallRequest?

    struct NativePaywallRequest: Identifiable {
        let id = UUID()
        let placement: PaywallPlacement
        let onUnlock: () -> Void
    }

    private var purchaseController: RCPurchaseController?

    func configure() {
        guard let key = AppKeys.superwall, AppKeys.revenueCat != nil else { return }
        let controller = RCPurchaseController()
        purchaseController = controller
        Superwall.configure(apiKey: key, purchaseController: controller)
        controller.syncSubscriptionStatus()
        usesSuperwall = true
    }

    func updateSubscriptionStatus(isPremium: Bool) {
        // With Superwall on, RCPurchaseController keeps the status in sync.
    }

    /// Runs `feature` if the user has Premium; otherwise shows a paywall and
    /// runs it after a purchase. Free features never come through here.
    func gate(_ placement: PaywallPlacement, params: [String: Any] = [:], feature: @escaping () -> Void) {
        if PurchaseManager.shared.isPremium {
            feature()
            return
        }
        guard usesSuperwall else {
            showNative(placement, feature)
            return
        }
        let handler = PaywallPresentationHandler()
        handler.onPresent { info in
            let id = info.identifier
            Task { @MainActor in AppAnalytics.shared.log(.paywallView, ["placement": placement.rawValue, "paywall_id": id]) }
        }
        handler.onError { [weak self] _ in
            Task { @MainActor in self?.showNative(placement, feature) }
        }
        Superwall.shared.register(placement: placement.rawValue, params: params, handler: handler) {
            Task { @MainActor in feature() }
        }
    }

    private func showNative(_ placement: PaywallPlacement, _ feature: @escaping () -> Void) {
        AppAnalytics.shared.log(.paywallView, ["placement": placement.rawValue, "paywall_id": "native"])
        nativePaywall = NativePaywallRequest(placement: placement, onUnlock: feature)
    }
}

/// Superwall buys through RevenueCat (Superwall docs, "Using RevenueCat").
nonisolated final class RCPurchaseController: PurchaseController, @unchecked Sendable {
    enum PurchasingError: LocalizedError {
        case productNotFound
        var errorDescription: String? { "Superwall didn't pass a StoreKit 2 product." }
    }

    func syncSubscriptionStatus() {
        Task {
            for await info in Purchases.shared.customerInfoStream {
                let entitlements = info.entitlements.activeInCurrentEnvironment.keys.map { Entitlement(id: $0) }
                await MainActor.run {
                    Superwall.shared.subscriptionStatus = entitlements.isEmpty ? .inactive : .active(Set(entitlements))
                }
            }
        }
    }

    func purchase(product: SuperwallKit.StoreProduct) async -> PurchaseResult {
        do {
            guard let sk2 = product.sk2Product else { throw PurchasingError.productNotFound }
            let result = try await Purchases.shared.purchase(product: RevenueCat.StoreProduct(sk2Product: sk2))
            return result.userCancelled ? .cancelled : .purchased
        } catch let error as RevenueCat.ErrorCode {
            return error == .paymentPendingError ? .pending : .failed(error)
        } catch {
            return .failed(error)
        }
    }

    func restorePurchases() async -> RestorationResult {
        do {
            _ = try await Purchases.shared.restorePurchases()
            return .restored
        } catch {
            return .failed(error)
        }
    }
}
