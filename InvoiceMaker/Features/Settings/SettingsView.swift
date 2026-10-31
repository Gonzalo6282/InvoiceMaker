import InvoiceKit
import SwiftData
import SwiftUI

enum SettingsPage: Hashable {
    case business, taxes, payment, look, signature, numbering, currency, backup, subscription, help, report, terms, privacy
    #if DEBUG
        case designSystem
    #endif
}

/// Settings root (mockup scrSettings). Account rows arrive with Sign in with Apple (M6).
struct SettingsView: View {
    let business: Business
    @State private var purchases = PurchaseManager.shared
    @State private var account = AccountService.shared
    private var isPremium: Bool { purchases.isPremium }

    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]
    @AppStorage(AppPreferences.analyticsKey) private var analyticsOn = false
    @State private var askingAnalytics = false
    @State private var sharingApp = false
    @Environment(\.openURL) private var openURL

    /// Turning analytics on asks first; turning it off doesn't.
    private var analyticsToggle: Binding<Bool> {
        Binding(get: { analyticsOn }, set: { on in if on { askingAnalytics = true } else { analyticsOn = false } })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                planCard.padding(.horizontal, 16).padding(.top, 4)
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
                GroupedSection(header: "Account") {
                    AccountRows(account: account)
                    RowDivider()
                    link(.subscription, icon: "lock.fill", tint: .neutral, title: "Subscription", value: isPremium ? String(localized: "Premium") : String(localized: "Free"))
                }
                GroupedSection(header: "Help") {
                    link(.help, icon: "questionmark.circle.fill", title: "Help and support", meta: String(localized: "Replies within 24 hours"))
                    RowDivider()
                    link(.report, icon: "envelope.fill", tint: .paid, title: "Report a problem")
                    RowDivider()
                    Button { openURL(AppLinks.writeReview) } label: {
                        Row(icon: "star.fill", iconTint: .warn, title: "Rate Duly", meta: String(localized: "Leave a review on the App Store"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("rateApp")
                    RowDivider()
                    Button {
                        AppAnalytics.shared.log(.shareAppTapped)
                        sharingApp = true
                    } label: {
                        Row(icon: "square.and.arrow.up", iconTint: .brand, title: "Share Duly", meta: String(localized: "Tell a friend about the app"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("shareApp")
                }
                GroupedSection(header: "Privacy and legal", footer: "Tax rates are set by you. This app doesn't give tax advice.") {
                    Toggle(isOn: analyticsToggle) {
                        HStack(spacing: 12) {
                            IconChip(systemName: "chart.bar.fill", tint: .neutral)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Anonymous analytics").font(.callout).foregroundStyle(Color.ink)
                                Text("Helps us fix what's slow or confusing").font(.footnote).foregroundStyle(Color.ink2)
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    RowDivider()
                    link(.privacy, icon: "hand.raised.fill", tint: .neutral, title: "Privacy Policy")
                    RowDivider()
                    link(.terms, icon: "doc.text.fill", tint: .neutral, title: "Terms of Use")
                }
                #if DEBUG
                    GroupedSection(header: "Debug") { link(.designSystem, icon: "swatchpalette", title: "Design system") }
                #endif
                Text("Duly \(AppInfo.version) (\(AppInfo.build)) · Slice of Life Ltd")
                    .font(.caption).foregroundStyle(Color.ink3)
                    .frame(maxWidth: .infinity).padding(.top, 22)
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsPage.self) { page in destination(page) }
        .sheet(isPresented: $sharingApp) {
            // The share sheet reports whether a share actually went out.
            ShareSheet(items: [ShareDuly.message]) { completed, activity in
                if completed { AppAnalytics.shared.log(.shareAppCompleted, ["method": activity?.rawValue ?? "unknown"]) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: analyticsOn) { AppAnalytics.shared.setConsent(analyticsOn) }
        .alert(AnalyticsConsentText.title, isPresented: $askingAnalytics) {
            Button(AnalyticsConsentText.allow) { analyticsOn = true }
            Button(AnalyticsConsentText.deny, role: .cancel) {}
        } message: {
            Text(AnalyticsConsentText.message)
        }
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
        case .subscription: SubscriptionView()
        case .help: HelpView()
        case .report: ReportProblemView(business: business)
        case .terms: LegalView(document: .terms)
        case .privacy: LegalView(document: .privacy)
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
