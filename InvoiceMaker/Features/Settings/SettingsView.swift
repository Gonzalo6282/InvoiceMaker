import InvoiceKit
import SwiftData
import SwiftUI

enum SettingsPage: Hashable {
    case business, taxes, payment, look, signature, numbering, currency, backup
    #if DEBUG
        case designSystem
    #endif
}

/// Settings root (mockup scrSettings): Duly's own sections inside SliceUI's
/// StandardSettings (Account, Help, Privacy and legal, version line).
struct SettingsView: View {
    let business: Business
    @State private var purchases = PurchaseManager.shared
    @State private var account = AccountService.shared
    private var isPremium: Bool { purchases.isPremium }

    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]
    @AppStorage(AppPreferences.analyticsKey) private var analyticsOn = false

    var body: some View {
        StandardSettings(
            app: .duly,
            purchases: SettingsPurchases(
                isPremium: { PurchaseManager.shared.isPremium },
                restore: { await PurchaseManager.shared.restore() },
                upgrade: { PaywallService.shared.gate(.settingsUpgrade) {} },
                premiumText: "Sending, printing and PDFs are unlocked.",
                plansText: "Free: create, edit and preview unlimited invoices, estimates and receipts, back them up and export them. Premium: send, print and save PDFs.",
                cardBackground: .navy,
                diagnostics: { await PurchaseManager.shared.diagnostics() }),
            analytics: SettingsAnalytics(
                isOn: { analyticsOn },
                setOn: { analyticsOn = $0 },
                askFirst: .init(
                    title: AnalyticsConsentText.title, message: AnalyticsConsentText.message,
                    allow: AnalyticsConsentText.allow, deny: AnalyticsConsentText.deny)),
            help: SettingsHelp(
                faqs: [
                    .init("Is Duly free?", "Creating, editing and previewing is free with no limits. Sending, printing and saving PDFs needs Premium."),
                    .init("How do I cancel?", "Payments are handled by Apple. Open Settings, tap your name, then Subscriptions. Deleting the app does not cancel the subscription."),
                    .init("Where are my invoices stored?", "On your device and in your own iCloud. We never upload them to our servers."),
                    .init("How do clients pay me?", "Add your bank details or payment links in Payment details. They appear on every invoice with a QR code."),
                ],
                reportTopics: [
                    String(localized: "Sending or PDFs"), String(localized: "Subscription or billing"),
                    String(localized: "Backup and sync"), String(localized: "Something else"),
                ],
                reportFooter: "We reply within 24 hours. Your invoices are not attached."),
            share: SettingsShare(
                message: ShareDuly.message,
                onTap: { AppAnalytics.shared.log(.shareAppTapped) },
                onShared: { method in AppAnalytics.shared.log(.shareAppCompleted, ["method": method]) }),
            legalFooter: "Tax rates are set by you. This app doesn't give tax advice.",
            header: AnyView(planCard.padding(.horizontal, 16).padding(.top, 4)),
            account: AnyView(AccountRows(account: account)),
            debug: debugSection
        ) {
            GroupedSection(header: "Your business") {
                link(.business, icon: "building.2.fill", title: "Business profile", meta: business.name.isEmpty ? String(localized: "Add your details") : business.name)
                RowDivider()
                link(.taxes, icon: "percent", tint: .warn, title: "Taxes", meta: activeTaxes.map(\.label).joined(separator: ", "))
                RowDivider()
                link(.payment, icon: "qrcode", tint: .neutral, title: "Payment details", meta: business.payment?.summary ?? "")
                RowDivider()
                link(.look, icon: "paintpalette.fill", tint: .due, title: "Invoice look", meta: String(localized: "\(InvoiceTemplate(id: business.templateID).displayName) template"))
                RowDivider()
                link(.signature, icon: "signature", tint: .paid, title: "My signature", value: business.signatureData == nil ? String(localized: "None") : String(localized: "Added"))
                RowDivider()
                link(.numbering, icon: "number", tint: .neutral, title: "Numbers and defaults",
                     meta: String(localized: "Next \(business.numbering.peek(.invoice)) · due in \(business.dueDays) days"))
                RowDivider()
                link(.currency, icon: "dollarsign.circle.fill", title: "Currency display", value: business.currencyDisplay.title)
            }
            GroupedSection(header: "Reminders") {
                RemindersRow(business: business)
            }
            GroupedSection(header: "Your data") {
                link(.backup, icon: "icloud.fill", title: "iCloud backup", value: CloudStatus.isAvailable ? String(localized: "On") : String(localized: "Off"))
                RowDivider()
                ExportRow(business: business)
            }
        }
        .navigationDestination(for: SettingsPage.self) { page in destination(page) }
        .onChange(of: analyticsOn) { AppAnalytics.shared.setConsent(analyticsOn) }
    }

    private var debugSection: AnyView? {
        #if DEBUG
            AnyView(GroupedSection(header: "Debug") { link(.designSystem, icon: "swatchpalette", title: "Design system") })
        #else
            nil
        #endif
    }

    private var activeTaxes: [TaxRate] { taxRecords.filter { !$0.isArchived }.map(\.taxRate) }

    private var planCard: some View {
        Button {
            PaywallService.shared.gate(.settingsUpgrade) {}
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(isPremium ? "Premium" : "Free plan").font(.footnote).opacity(0.72)
                Text(isPremium ? "Sending, printing and PDFs unlocked." : "Create and preview free. Send with Premium.")
                    .font(.title2.weight(.heavy)).multilineTextAlignment(.leading)
                if !isPremium {
                    Text("See plans").font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.paidInk).padding(.horizontal, 14).frame(height: 36)
                        .background(Color.paid, in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.navy, in: RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
    }

    private func link(
        _ page: SettingsPage, icon: String, tint: IconChip.Tint = .brand, title: LocalizedStringKey,
        meta: String? = nil, value: String? = nil
    ) -> some View {
        NavigationLink(value: page) {
            Row(icon: icon, iconTint: tint, title: title, meta: meta, value: value, showsChevron: true)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func destination(_ page: SettingsPage) -> some View {
        switch page {
        case .business: BusinessProfileView(business: business)
        case .taxes: TaxesView(business: business)
        case .payment: PaymentDetailsView(business: business)
        case .look: InvoiceLookView(business: business)
        case .signature: MySignatureView(business: business)
        case .numbering: NumberingView(business: business)
        case .currency: CurrencyDisplayView(business: business)
        case .backup: BackupView()
        #if DEBUG
            case .designSystem: DesignGalleryView()
        #endif
        }
    }
}

extension CurrencyDisplay {
    var title: String {
        switch self {
        case .symbol: String(localized: "Symbol")
        case .code: String(localized: "Code")
        case .none: String(localized: "Hidden")
        }
    }
}

extension PaymentDetails {
    /// "Bank, PayPal, QR" or "None added".
    var summary: String {
        let parts: [String?] = [
            accountNumber.isEmpty && iban.isEmpty ? nil : String(localized: "Bank"),
            payPalMe.isEmpty ? nil : "PayPal", venmo.isEmpty ? nil : "Venmo", cashApp.isEmpty ? nil : "Cash App",
            zelle.isEmpty ? nil : "Zelle", paymentLink.isEmpty ? nil : String(localized: "Pay link"),
            showsQRCode && !(paymentLink.isEmpty && payPalMe.isEmpty) ? "QR" : nil,
        ]
        let list = parts.compactMap { $0 }
        return list.isEmpty ? String(localized: "None added") : list.joined(separator: ", ")
    }
}

enum AppPreferences {
    static let analyticsKey = "analyticsEnabled"
}

enum AppLinks {
    // Static, known-good URLs.
    static let privacy = URL(string: "https://slice-of-life.uk/duly-privacy/")!  // swiftlint:disable:this force_unwrapping
    static let terms = URL(string: "https://slice-of-life.uk/duly-terms/")!  // swiftlint:disable:this force_unwrapping
    /// App Store "Write a Review" page (App Store ID 6824285908).
    static let appStore = URL(string: "https://apps.apple.com/app/id6824285908")!  // swiftlint:disable:this force_unwrapping
    static let writeReview = URL(string: "https://apps.apple.com/app/id6824285908?action=write-review")!  // swiftlint:disable:this force_unwrapping
    static let supportEmail = "slice.of.life.ltd@gmail.com"
}

extension AppIdentity {
    static let duly = AppIdentity(
        name: "Duly", company: "Slice of Life Ltd", appStoreID: "6824285908", supportEmail: AppLinks.supportEmail,
        privacyURL: AppLinks.privacy, termsURL: AppLinks.terms, version: AppInfo.version, build: AppInfo.build)
}

enum AppInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
}

enum CloudStatus {
    /// True when the user is signed in to iCloud (the store then syncs).
    static var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }
}

/// The analytics question (first launch and the Settings switch).
enum AnalyticsConsentText {
    static var title: String { String(localized: "Help improve Duly?") }
    static var message: String {
        String(localized: "Share anonymous usage data and crash reports so we can fix problems and make Duly better. Your invoices and client details are never included. You can change this any time in Settings.")
    }
    static var allow: String { String(localized: "Allow") }
    static var deny: String { String(localized: "Don't Allow") }
}

/// "Share Duly" in Settings: the share sheet's ready-made message.
nonisolated enum ShareDuly {
    static let message = "I send my invoices with Duly. Try it: https://apps.apple.com/app/id6824285908"
}
