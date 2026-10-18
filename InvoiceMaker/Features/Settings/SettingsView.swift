import InvoiceKit
import SwiftData
import SwiftUI

enum SettingsPage: Hashable {
    case business, taxes, payment, look, signature, numbering, currency, backup, subscription, help, report
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
    @Environment(\.openURL) private var openURL

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
                }
                GroupedSection(header: "Privacy and legal", footer: "Tax rates are set by you. This app doesn't give tax advice.") {
                    Toggle(isOn: $analyticsOn) {
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
                    Button { openURL(AppLinks.privacy) } label: {
                        Row(icon: "hand.raised.fill", iconTint: .neutral, title: "Privacy Policy", meta: AppLinks.privacy.host() ?? "")
                    }.buttonStyle(.plain)
                    RowDivider()
                    Button { openURL(AppLinks.terms) } label: {
                        Row(icon: "doc.text.fill", iconTint: .neutral, title: "Terms of Use", meta: AppLinks.terms.host() ?? "")
                    }.buttonStyle(.plain)
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
        .onChange(of: analyticsOn) { AppAnalytics.shared.setConsent(analyticsOn) }
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
    static let privacy = URL(string: "https://slice-of-life.uk/invoice/privacy")!  // swiftlint:disable:this force_unwrapping
    static let terms = URL(string: "https://slice-of-life.uk/invoice/terms")!  // swiftlint:disable:this force_unwrapping
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
