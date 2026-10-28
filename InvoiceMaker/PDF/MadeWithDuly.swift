import Foundation

/// The small "Made with Duly" line at the bottom of every PDF (Build Doc,
/// "Sharing and referrals"): every invoice a user sends reaches another
/// business owner. On by default; anyone can turn it off in Invoice look.
enum MadeWithDuly {
    static let key = "pdfMadeWithDuly"

    /// On unless the user turned it off.
    static func isOn(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    static var text: String { String(localized: "Made with Duly") }
    /// Tapping the line on the PDF opens Duly's App Store page.
    static var url: URL { AppLinks.appStore }
}
