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
    case shareAppTapped = "share_app_tapped"
}

