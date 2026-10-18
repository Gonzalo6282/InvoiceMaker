import Foundation

/// Every Firebase event, named as in the Build Doc (snake_case).
/// RevenueCat sends trial_start / purchase / trial_converted / cancel / refund
/// through its Firebase integration, so they aren't logged here.
nonisolated enum AnalyticsEvent: String, CaseIterable, Sendable {
    case onboardingStep = "onboarding_step"
    case onboardingComplete = "onboarding_complete"
    case invoiceCreated = "invoice_created"
    case estimateCreated = "estimate_created"
    case paywallView = "paywall_view"
    case invoiceSent = "invoice_sent"
    case pdfExported = "pdf_exported"
}

/// UK + EEA storefronts get the consent question before any analytics.
nonisolated enum ConsentPolicy {
    /// ISO 3166 alpha-3 (Storefront.countryCode) for the UK and EEA.
    static let askCountries: Set<String> = [
        "GBR", "AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "IRL",
        "ITA", "LVA", "LTU", "LUX", "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE", "ISL", "LIE", "NOR",
    ]

    nonisolated static func mustAsk(storefrontCountry: String?) -> Bool {
        guard let code = storefrontCountry?.uppercased() else { return true }  // unknown: ask, to be safe
        return askCountries.contains(code)
    }
}
