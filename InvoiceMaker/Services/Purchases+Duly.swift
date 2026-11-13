// SlicePurchases (SliceLibrary) does purchases and paywalls; Duly supplies
// its keys, products, placements and analytics here.
@_exported import SlicePurchases
import Foundation


/// Where paywalls can appear (Superwall placements, spec).
nonisolated enum PaywallPlacement: String, CaseIterable, PaywallPlacementType {
    case onboardingEnd = "onboarding_end"
    case invoiceSend = "invoice_send"
    case invoiceExportPDF = "invoice_export_pdf"
    case estimateSend = "estimate_send"
    case templatePremium = "template_premium"
    case settingsUpgrade = "settings_upgrade"
    case recurringInvoice = "recurring_invoice"
    case reports = "reports"

    /// The native paywall's headline for this placement (mockup).
    var headline: String {
        switch self {
        case .invoiceSend: String(localized: "Send this invoice")
        case .estimateSend: String(localized: "Send this estimate")
        case .invoiceExportPDF: String(localized: "Save and print your PDFs")
        case .templatePremium: String(localized: "Unlock every template")
        case .recurringInvoice: String(localized: "Repeat invoices automatically")
        case .reports: String(localized: "See what you earn")
        case .onboardingEnd, .settingsUpgrade: String(localized: "Send invoices that get paid")
        }
    }
}


extension PurchaseManager {
    /// Premium entitlement: same identifier in RevenueCat and Superwall.
    static let entitlement = "pro"
    static let monthlyID = "im_standard_monthly"
    static let yearlyID = "im_standard_yearly"
}

extension PaywallService {
    /// `gate(.invoiceSend) { … }` with Duly's placements.
    func gate(
        _ placement: PaywallPlacement, params: [String: Any] = [:], onFinished: (() -> Void)? = nil,
        feature: @escaping () -> Void
    ) {
        gate(placement as any PaywallPlacementType, params: params, onFinished: onFinished, feature: feature)
    }
}

enum DulyPurchases {
    /// Order matters: RevenueCat, then Superwall (buys through RevenueCat).
    static func configure(arguments: [String] = ProcessInfo.processInfo.arguments) {
        PurchaseManager.shared.configure(PurchaseConfig(
            revenueCatAPIKey: AppKeys.revenueCat,
            entitlement: PurchaseManager.entitlement,
            productIDs: [PurchaseManager.yearlyID, PurchaseManager.monthlyID],
            forcePremium: arguments.contains("-premium"),
            logPrefix: "[Duly purchases]"
        ))
        PaywallService.shared.onPaywallShown = { placement, paywallID in
            AppAnalytics.shared.log(.paywallView, ["placement": placement, "paywall_id": paywallID])
        }
        PaywallService.shared.configure(superwallAPIKey: AppKeys.superwall)
    }
}
