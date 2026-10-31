import Contacts
import Foundation
import InvoiceKit
import SwiftData
import Testing

@testable import InvoiceMaker

struct ServicesTests {
    @Test func legalTextsShipInTheApp() {
        let terms = LegalDocument.terms.blocks(language: "en")
        let privacy = LegalDocument.privacy.blocks(language: "en")
        #expect(terms.first == .title("Terms of Use"))
        #expect(terms.contains(.heading("Subscriptions, Free Trials and Payments")))
        #expect(privacy.first == .title("Privacy Policy"))
        #expect(privacy.contains(.subheading("Analytics and Crash Reports (only with your permission)")))
    }

    @Test func frenchLegalTextsShipInTheApp() {
        let terms = LegalDocument.terms.blocks(language: "fr")
        let privacy = LegalDocument.privacy.blocks(language: "fr")
        #expect(terms.first == .title("Conditions d'utilisation"))
        #expect(terms.contains(.heading("Abonnements, essais gratuits et paiements")))
        #expect(privacy.first == .title("Politique de confidentialité"))
        // Same structure as the English originals.
        let headings = { (b: [LegalBlock]) in b.filter { if case .heading = $0 { true } else { false } }.count }
        #expect(headings(terms) == headings(LegalDocument.terms.blocks(language: "en")))
        #expect(headings(privacy) == headings(LegalDocument.privacy.blocks(language: "en")))
    }

    @Test @MainActor func reviewIsAskedAtSpacedHappyMoments() throws {
        let defaults = try #require(UserDefaults(suiteName: "review-\(UUID().uuidString)"))
        let day0 = Date(timeIntervalSince1970: 1_800_000_000)
        func day(_ n: Double) -> Date { day0.addingTimeInterval(n * 86_400) }
        func ask(_ m: ReviewPrompt.Moment, _ d: Double, _ v: String) -> Bool {
            ReviewPrompt.shouldAsk(after: m, now: day(d), version: v, defaults: defaults)
        }
        #expect(!ask(.markedPaid, 0, "1.0.1"))  // ask 1 is the first send
        #expect(ask(.sent, 0, "1.0.1"))  // 1st sent
        #expect(!ask(.sent, 1, "1.0.1"))
        #expect(!ask(.markedPaid, 40, "1.0.1"))  // same version
        #expect(!ask(.markedPaid, 20, "1.0.2"))  // under 30 days
        #expect(!ask(.sent, 40, "1.0.2"))  // ask 2 is marked paid
        #expect(ask(.markedPaid, 40, "1.0.2"))
        for d in 0..<6 { #expect(!ask(.sent, 50 + Double(d), "1.1")) }  // 4th–9th sent, under 90 days
        #expect(!ask(.sent, 100, "1.1"))  // 10th sent but only 60 days after ask 2
        #expect(ask(.sent, 140, "1.1"))  // 11th sent, 100 days
        #expect(!ask(.sent, 400, "1.2"))  // three asks is the limit
        #expect(!ask(.markedPaid, 400, "1.2"))
    }

    @Test @MainActor func reviewCountsTheV1FirstSendAsk() throws {
        let defaults = try #require(UserDefaults(suiteName: "review-\(UUID().uuidString)"))
        defaults.set(true, forKey: ReviewPrompt.legacyAskedKey)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(!ReviewPrompt.shouldAsk(after: .sent, now: now, version: "1.0.1", defaults: defaults))
        #expect(!ReviewPrompt.shouldAsk(after: .markedPaid, now: now.addingTimeInterval(10 * 86_400), version: "1.0.1", defaults: defaults))
        #expect(ReviewPrompt.shouldAsk(after: .markedPaid, now: now.addingTimeInterval(31 * 86_400), version: "1.0.1", defaults: defaults))
    }

    @Test func legalTextParsing() {
        #expect(LegalBlock.parse("# T\n\n## H\n### S\n- b\ntext\n") == [.title("T"), .heading("H"), .subheading("S"), .bullet("b"), .paragraph("text")])
    }

    @Test func eventNamesMatchTheBuildDoc() {
        #expect(AnalyticsEvent.allCases.map(\.rawValue) == [
            "onboarding_step", "onboarding_complete", "invoice_created", "estimate_created", "paywall_view",
            "invoice_sent", "pdf_exported", "share_app_tap", "share_app_completed", "made_with_duly_changed", "recurring_set", "reports_viewed",
            "report_exported", "reminders_changed", "photo_added",
        ])
    }

    @Test func shareDulyMessageHasTheAppStoreLink() {
        #expect(ShareDuly.message == "I send my invoices with Duly. Try it: https://apps.apple.com/app/id6824285908")
    }

    @Test @MainActor func appleSignInErrorsReadClearly() throws {
        let domain = "com.apple.AuthenticationServices.AuthorizationError"
        #expect(AccountService.report(NSError(domain: domain, code: 1001), step: "test") == nil)
        let reset = try #require(AccountService.report(NSError(domain: domain, code: 1000), step: "test"))
        #expect(reset.hasPrefix(AccountService.appleResetHelp))
        #expect(reset.contains("Stop Using Apple ID"))
    }

    @Test func pickedAddressesDropTheHomeCountry() {
        let address = CNMutablePostalAddress()
        address.street = "22 Queen Square"
        address.city = "Bristol"
        address.postalCode = "BS1 4ND"
        address.country = "United Kingdom"
        address.isoCountryCode = "gb"
        let home = AddressCompleter.format(address, homeCountry: "GB")
        #expect(!home.contains("United Kingdom"))
        #expect(home.hasPrefix("22 Queen Square\n"))
        #expect(!home.contains("\n\n"))
        #expect(AddressCompleter.format(address, homeCountry: "US").hasSuffix("United Kingdom"))
    }

    // v1.1 ships English and French; German is switched off (docs/i18n/README.md).
    @Test func germanIsSwitchedOff() {
        #expect(!Bundle.main.localizations.contains("de"))
    }

    @Test(arguments: [("fr", "Nouvelle facture", "Devis")])
    func frenchShipsInTheApp(language: String, newInvoice: String, quote: String) throws {
        let path = try #require(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language))
        let table = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
        #expect(table["New invoice"] == newInvoice)
        #expect(table["Quote"] == quote)  // looked up at run time from InvoiceKit
        #expect(table.count > 400)
    }

    @Test func usEnglishUsesUSSpelling() throws {
        let path = try #require(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en-US"))
        let us = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
        #expect(us["Brand colour"] == "Brand color")
        #expect(us["Template and colour"] == "Template and color")
        #expect(us["Labour"] == "Labor")
        #expect(us["Street, town, postcode"] == "Street, city, ZIP code")
        // UK, Australia, Canada and others keep the source (UK) spelling.
        for other in ["en-GB", "en-AU", "en-CA", "en-IE"] {
            #expect(Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: [other]).first == "en", "\(other) in \(Bundle.main.localizations)")
        }
        #expect(Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: ["en-US"]).first == "en-US")
    }

    @Test func placementsMatchTheSpec() {
        #expect(PaywallPlacement.allCases.map(\.rawValue) == [
            "onboarding_end", "invoice_send", "invoice_export_pdf", "estimate_send", "template_premium", "settings_upgrade",
            "recurring_invoice", "reports",
        ])
    }

    @Test func noncesAreRandomAndHashed() {
        let a = AccountService.randomNonce()
        #expect(a.count == 32)
        #expect(a != AccountService.randomNonce())
        #expect(AccountService.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test @MainActor func keysAreOffWithoutSecrets() {
        // CI has no Secrets.xcconfig: the app must run with these services off.
        #expect(AppKeys.revenueCat == nil)
        #expect(AppKeys.superwall == nil)
        #expect(!AppKeys.hasFirebase)
    }
}

@MainActor
struct BusinessChoiceTests {
    /// After a reinstall, onboarding may have made an empty business before
    /// iCloud delivered the real one: the named one (then with a logo) wins.
    @Test func namedBusinessWinsOverAnEmptyDuplicate() throws {
        let container = try ModelContainerFactory.makeForTests()
        let context = container.mainContext
        let empty = Business()
        let logoOnly = Business()
        logoOnly.logoData = Data([1, 2, 3])
        let named = Business(name: "Kestrel Joinery")
        [empty, logoOnly, named].forEach(context.insert)
        #expect(BusinessSetup.primary([empty, logoOnly, named]) === named)
        #expect(BusinessSetup.primary([empty, logoOnly]) === logoOnly)
        #expect(BusinessSetup.primary([empty]) === empty)
        #expect(BusinessSetup.primary([]) == nil)
    }

    @Test func backupTimesReadNaturally() {
        let now = Date(timeIntervalSince1970: 1_792_000_000)
        let calendar = Calendar(identifier: .gregorian)
        #expect(SyncStatusSection.when(now.addingTimeInterval(-60), now: now, calendar: calendar).hasPrefix("Today at "))
        #expect(SyncStatusSection.when(now.addingTimeInterval(-86_400), now: now, calendar: calendar).hasPrefix("Yesterday at "))
        #expect(!SyncStatusSection.when(now.addingTimeInterval(-5 * 86_400), now: now, calendar: calendar).hasPrefix("Today"))
    }

    @Test func sampleInvoiceUsesALocalBusinessAndYourName() {
        #expect(OnboardingRole.sampleClient(for: .us) == "Oakridge Landscaping")
        #expect(OnboardingRole.sampleClient(for: .uk) == "Marlow & Finch Ltd")
        #expect(Region.allCases.allSatisfy { !OnboardingRole.sampleClient(for: $0).isEmpty })
        #expect(InvoicePDFModelBuilder.displayName(Business(name: "  ")) == "Your Business")
        #expect(InvoicePDFModelBuilder.displayName(Business(name: "Summit Electric Co.")) == "Summit Electric Co.")
    }
}
