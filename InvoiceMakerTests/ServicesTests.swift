import Foundation
import InvoiceKit
import SwiftData
import Testing

@testable import InvoiceMaker

struct ServicesTests {
    @Test func legalTextsShipInTheApp() {
        let terms = LegalDocument.terms.blocks
        let privacy = LegalDocument.privacy.blocks
        #expect(terms.first == .title("Terms of Use"))
        #expect(terms.contains(.heading("Subscriptions, Free Trials and Payments")))
        #expect(privacy.first == .title("Privacy Policy"))
        #expect(privacy.contains(.subheading("Analytics and Crash Reports (only with your permission)")))
    }

    @Test @MainActor func reviewIsAskedOnlyAfterTheFirstSend() throws {
        let defaults = try #require(UserDefaults(suiteName: "review-\(UUID().uuidString)"))
        #expect(ReviewPrompt.shouldAskAfterSend(defaults: defaults))
        #expect(!ReviewPrompt.shouldAskAfterSend(defaults: defaults))
    }

    @Test func legalTextParsing() {
        #expect(LegalBlock.parse("# T\n\n## H\n### S\n- b\ntext\n") == [.title("T"), .heading("H"), .subheading("S"), .bullet("b"), .paragraph("text")])
    }

    @Test func eventNamesMatchTheBuildDoc() {
        #expect(AnalyticsEvent.allCases.map(\.rawValue) == [
            "onboarding_step", "onboarding_complete", "invoice_created", "estimate_created", "paywall_view",
            "invoice_sent", "pdf_exported", "share_app_tapped",
        ])
    }

    @Test func shareDulyMessageHasTheAppStoreLink() {
        #expect(ShareDuly.message == "I send my invoices with Duly. Try it: https://apps.apple.com/app/id6824285908")
    }

    @Test func placementsMatchTheSpec() {
        #expect(PaywallPlacement.allCases.map(\.rawValue) == [
            "onboarding_end", "invoice_send", "invoice_export_pdf", "estimate_send", "template_premium", "settings_upgrade",
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
