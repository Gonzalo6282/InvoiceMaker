import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import FirebaseRemoteConfig
import Foundation
import StoreKit

/// Firebase Analytics + Crashlytics + Remote Config, behind the user's consent.
/// Nothing is collected until `consentGiven` is true (UK/EEA users are asked;
/// elsewhere it defaults to on with a switch in Settings). No advertising ID.
@MainActor
final class AppAnalytics {
    static let shared = AppAnalytics()

    private(set) var isConfigured = false
    private var country = ""

    /// One stored setting for the consent screen and the Settings switch; nil = never decided.
    static var stored: Bool? { UserDefaults.standard.object(forKey: AppPreferences.analyticsKey) as? Bool }
    static var isEnabled: Bool { stored ?? false }

    /// Whether to show the consent screen (UK/EEA, never answered).
    static func needsConsentPrompt() async -> Bool {
        guard stored == nil else { return false }
        return ConsentPolicy.mustAsk(storefrontCountry: await Storefront.current?.countryCode)
    }

    func setConsent(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: AppPreferences.analyticsKey)
        apply(enabled: granted)
    }

    /// Outside UK/EEA analytics is on by default, with a switch in Settings.
    func enableByDefaultIfNotAsked() async {
        guard Self.stored == nil, !(await Self.needsConsentPrompt()) else { return }
        setConsent(true)
    }

    func apply(enabled: Bool) {
        guard isConfigured else { return }
        Analytics.setConsent([
            .analyticsStorage: enabled ? .granted : .denied,
            .adStorage: .denied, .adUserData: .denied, .adPersonalization: .denied,
        ])
        Analytics.setAnalyticsCollectionEnabled(enabled)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    }

    /// Logs an event with app version and store country attached.
    func log(_ event: AnalyticsEvent, _ parameters: [String: Any] = [:]) {
        guard isConfigured, Self.isEnabled else { return }
        var params = parameters
        params["app_version"] = AppInfo.version
        if !country.isEmpty { params["country"] = country }
        Analytics.logEvent(event.rawValue, parameters: params)
    }
}

/// Remote Config keys with their in-app defaults.
enum RemoteFlags {
    static let showNativePaywallOnSuperwallError = "show_native_paywall_on_superwall_error"
    static let onboardingSoftPaywall = "onboarding_soft_paywall"

    static var defaults: [String: NSObject] {
        [showNativePaywallOnSuperwallError: true as NSNumber, onboardingSoftPaywall: true as NSNumber]
    }
}
