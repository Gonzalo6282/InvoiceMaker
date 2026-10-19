import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import FirebaseRemoteConfig
import Foundation
import Observation
import StoreKit

/// Firebase Analytics + Crashlytics + Remote Config, behind the user's consent.
/// Off by default for everyone: nothing is collected until the user taps
/// Allow (first-launch question or the Settings switch). No advertising ID.
@MainActor
final class AppAnalytics {
    static let shared = AppAnalytics()

    private(set) var isConfigured = false
    private var country = ""

    func configure() {
        guard AppKeys.hasFirebase, FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        isConfigured = true
        RemoteConfig.remoteConfig().setDefaults(RemoteFlags.defaults)
        RemoteConfig.remoteConfig().fetchAndActivate { _, _ in }
        Task { country = await Storefront.current?.countryCode ?? "" }
        apply(enabled: Self.isEnabled)
    }

    /// One stored setting for the consent screen and the Settings switch; nil = never decided.
    static var stored: Bool? { UserDefaults.standard.object(forKey: AppPreferences.analyticsKey) as? Bool }
    static var isEnabled: Bool { stored ?? false }

    /// Ask once, on first launch, until the user answers.
    static var needsConsentPrompt: Bool { stored == nil }

    func setConsent(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: AppPreferences.analyticsKey)
        apply(enabled: granted)
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

/// Shows the native analytics question once, when the user is in the app with
/// nothing else on screen (never during onboarding or over a paywall).
@MainActor
@Observable
final class ConsentPrompt {
    static let shared = ConsentPrompt()
    var isShowing = false

    func askIfNeeded() {
        guard AppAnalytics.needsConsentPrompt, !isShowing else { return }
        Task {
            // Let a closing paywall or sheet finish its animation first.
            try? await Task.sleep(for: .milliseconds(700))
            if AppAnalytics.needsConsentPrompt { isShowing = true }
        }
    }
}
