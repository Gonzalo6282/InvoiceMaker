import SwiftUI

/// Duly's words and look for SliceUI's PaywallTemplate (shown when Superwall
/// isn't available): the headline per placement, the Free/Premium line, the
/// benefits and the navy header. Price, trial end date, Restore, Terms and
/// Privacy come from the template.
extension PaywallContent {
    static func duly(_ placement: PaywallPlacement) -> PaywallContent {
        PaywallContent(
            headline: placement.headline,
            subtitle: "**Free:** create, edit and preview as many invoices as you like. **Premium:** send, print and save PDFs.",
            benefits: [
                String(localized: "Send by email, Messages or WhatsApp"), String(localized: "No \"Preview\" mark on your PDFs"),
                String(localized: "All 7 templates with your logo"), String(localized: "Payment buttons and QR code on invoices"),
            ],
            headerBackground: .navy,
            headerForeground: .white,
            termsURL: AppLinks.terms,
            privacyURL: AppLinks.privacy)
    }
}
