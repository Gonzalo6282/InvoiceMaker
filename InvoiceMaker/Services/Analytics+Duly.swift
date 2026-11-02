// SliceAnalytics (SliceLibrary) does Firebase and consent; Duly supplies its
// events (AnalyticsEvent.swift), its consent key and Remote Config defaults.
@_exported import SliceAnalytics
import Foundation

/// Remote Config keys with their in-app defaults.
enum RemoteFlags {
    static let showNativePaywallOnSuperwallError = "show_native_paywall_on_superwall_error"
    static let onboardingSoftPaywall = "onboarding_soft_paywall"

    static var defaults: [String: RemoteValue] {
        [showNativePaywallOnSuperwallError: .bool(true), onboardingSoftPaywall: .bool(true)]
    }
}

extension AppAnalytics {
    /// `log(.invoiceSent)` with Duly's events.
    func log(_ event: AnalyticsEvent, _ parameters: [String: Any] = [:]) {
        log(event as any AnalyticsEventType, parameters)
    }
}

enum DulyAnalytics {
    /// Off for everyone until they tap Allow (first-launch question or the Settings switch).
    static func configure() {
        AppAnalytics.shared.configure(AnalyticsConfig(
            consentKey: AppPreferences.analyticsKey,
            consentPolicy: .askEveryone,
            remoteDefaults: RemoteFlags.defaults,
            appVersion: AppInfo.version
        ))
    }
}
