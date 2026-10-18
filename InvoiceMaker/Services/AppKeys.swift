import Foundation

/// Public SDK keys from Info.plist (filled from Config/Secrets.xcconfig).
/// Empty or unexpanded values mean "not set up yet": that service stays off.
enum AppKeys {
    static var revenueCat: String? { value("RevenueCatAPIKey", prefix: "appl_") }
    static var superwall: String? { value("SuperwallAPIKey", prefix: "pk_") }
    /// Firebase is set up when GoogleService-Info.plist is in the bundle.
    static var hasFirebase: Bool { Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil }

    private static func value(_ key: String, prefix: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let v = raw.trimmingCharacters(in: .whitespaces)
        return v.hasPrefix(prefix) && v.count > prefix.count + 4 ? v : nil
    }
}
