import Testing

@testable import InvoiceMaker

struct ServicesTests {
    @Test func consentAskedInUKAndEEAOnly() {
        #expect(ConsentPolicy.mustAsk(storefrontCountry: "GBR"))
        #expect(ConsentPolicy.mustAsk(storefrontCountry: "deu"))
        #expect(ConsentPolicy.mustAsk(storefrontCountry: "NOR"))
        #expect(ConsentPolicy.mustAsk(storefrontCountry: nil))
        #expect(!ConsentPolicy.mustAsk(storefrontCountry: "USA"))
        #expect(!ConsentPolicy.mustAsk(storefrontCountry: "AUS"))
        #expect(!ConsentPolicy.mustAsk(storefrontCountry: "CAN"))
        #expect(ConsentPolicy.askCountries.count == 31)  // UK + 27 EU + Iceland, Liechtenstein, Norway
    }

    @Test func eventNamesMatchTheBuildDoc() {
        #expect(AnalyticsEvent.allCases.map(\.rawValue) == [
            "onboarding_step", "onboarding_complete", "invoice_created", "estimate_created", "paywall_view",
            "invoice_sent", "pdf_exported",
        ])
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
