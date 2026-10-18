import InvoiceKit
import StoreKit
import SwiftUI

/// Draw once; it goes on every invoice.
struct MySignatureView: View {
    @Bindable var business: Business
    @State private var drawing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Draw once. It goes on every invoice you send.").foregroundStyle(Color.ink2)
                Group {
                    if let data = business.signatureData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit().padding(20)
                    } else {
                        Text("No signature yet").foregroundStyle(Color.ink3)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line))
                HStack(spacing: 10) {
                    if business.signatureData != nil {
                        Button("Remove") { business.signatureData = nil }.buttonStyle(.ghost)
                    }
                    Button(business.signatureData == nil ? "Draw signature" : "Draw again") { drawing = true }.buttonStyle(.primary)
                }
            }
            .padding(16)
        }
        .background(Color.canvas)
        .navigationTitle("My signature")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $drawing) {
            SignatureSheet(purpose: .mine) { png, _ in business.signatureData = png }
        }
    }
}

/// Prefixes, next numbers, due days and default notes.
struct NumberingView: View {
    @Bindable var business: Business

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GroupedSection(header: "Numbering", footer: "Numbers go up by one with each new document. Next: \(business.numbering.peek(.invoice)).") {
                    FieldRow(label: "Invoice prefix") { TextField("INV-", text: $business.invoicePrefix).autocorrectionDisabled() }
                    RowDivider()
                    FieldRow(label: "Next invoice number") { IntField("1", value: positive(\.nextInvoiceNumber)) }
                    RowDivider()
                    FieldRow(label: LocalizedStringKey(String(localized: "\(business.title(for: .estimate)) prefix"))) {
                        TextField("EST-", text: $business.estimatePrefix).autocorrectionDisabled()
                    }
                    RowDivider()
                    FieldRow(label: "Receipt prefix") { TextField("REC-", text: $business.receiptPrefix).autocorrectionDisabled() }
                }
                GroupedSection(header: "Defaults") {
                    FieldRow(label: "Payment due in (days)") { IntField("14", value: positive(\.dueDays)) }
                    RowDivider()
                    TextField("Notes on new documents", text: $business.defaultNotes, axis: .vertical)
                        .lineLimit(2...6).padding(14)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle("Numbers and defaults")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func positive(_ keyPath: ReferenceWritableKeyPath<Business, Int>) -> Binding<Int> {
        Binding(get: { business[keyPath: keyPath] }, set: { business[keyPath: keyPath] = max($0, 0) })
    }
}

/// Symbol / code / hidden.
struct CurrencyDisplayView: View {
    @Bindable var business: Business

    var body: some View {
        ScrollView {
            GroupedSection(header: "Show amounts as", footer: "Applies in the app and on your PDFs. Each client can have their own currency in their details.") {
                ForEach(Array(CurrencyDisplay.allCases.enumerated()), id: \.element) { index, option in
                    if index > 0 { RowDivider() }
                    Button { business.currencyDisplay = option } label: {
                        Row(verbatim: option.title,
                            meta: MoneyFormat.string(1250, currencyCode: business.currencyCode, display: option, locale: business.locale)) {
                            if business.currencyDisplay == option {
                                Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(Color.brand)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(business.currencyDisplay == option ? .isSelected : [])
                }
            }
        }
        .background(Color.canvas)
        .navigationTitle("Currency display")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// iCloud status and what backup means.
struct BackupView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if CloudStatus.isAvailable {
                    Banner(tone: .ok, systemImage: "checkmark.icloud.fill",
                           text: Text("**Backed up to iCloud.** Your documents, clients, logo and settings sync to your own iCloud."))
                } else {
                    Banner(tone: .warn, systemImage: "icloud.slash",
                           text: Text("**iCloud is off.** Open the Settings app, tap your name, then iCloud, and sign in. Until then your invoices are only on this device."))
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.primary).padding(16)
                }
                Text("Your invoices are saved on this device and in your own iCloud, which only you can read. A new iPhone or iPad signed in to the same Apple ID gets everything back. If your subscription ends you can still open and export every invoice. Only you can delete your data.")
                    .font(.footnote).foregroundStyle(Color.ink2).padding(16)
            }
        }
        .background(Color.canvas)
        .navigationTitle("iCloud backup")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Plan status, restore, manage (Apple handles cancelling).
struct SubscriptionView: View {
    @State private var purchases = PurchaseManager.shared
    @State private var managing = false
    @State private var restoring = false
    @State private var restoreMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if purchases.isPremium {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Premium").font(.footnote).opacity(0.72)
                        Text("Sending, printing and PDFs are unlocked.").font(.title2.weight(.heavy))
                    }
                    .foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.navy, in: RoundedRectangle(cornerRadius: 28))
                    Button("Manage subscription") { managing = true }.buttonStyle(.ghost)
                } else {
                    Button("See Premium plans") { PaywallService.shared.gate(.settingsUpgrade) {} }.buttonStyle(.primary)
                }
                Button(restoring ? String(localized: "Restoring…") : String(localized: "Restore purchases")) {
                    restoring = true
                    Task {
                        let ok = await purchases.restore()
                        restoring = false
                        restoreMessage = ok ? String(localized: "Premium restored.") : String(localized: "No active subscription found for this Apple ID.")
                    }
                }
                .disabled(restoring)
                .frame(maxWidth: .infinity)
                if let restoreMessage { Text(restoreMessage).font(.subheadline).foregroundStyle(Color.ink2).frame(maxWidth: .infinity) }
                Text("Free: create, edit and preview unlimited invoices, estimates and receipts, back them up and export them. Premium: send, print and save PDFs.")
                    .font(.subheadline).foregroundStyle(Color.ink2).padding(.top, 8)
                Text("Payments are handled by Apple. To cancel, open Settings, tap your name, then Subscriptions. To ask for a refund, go to reportaproblem.apple.com. Deleting the app does not cancel the subscription. If your subscription ends you keep every document.")
                    .font(.footnote).foregroundStyle(Color.ink3)
            }
            .padding(16)
        }
        .background(Color.canvas)
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $managing)
    }
}

/// Contact, report and common questions.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GroupedSection(footer: "We reply within 24 hours, every day.") {
                    if let mail = URL(string: "mailto:\(AppLinks.supportEmail)") {
                        Link(destination: mail) { Row(icon: "envelope.fill", title: "Email us", meta: AppLinks.supportEmail) }.buttonStyle(.plain)
                    }
                    RowDivider()
                    NavigationLink(value: SettingsPage.report) {
                        Row(icon: "exclamationmark.bubble.fill", iconTint: .paid, title: "Report a problem", meta: String(localized: "Sends your message and app version"), showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                GroupedSection(header: "Common questions") {
                    faq("Is Duly free?", "Creating, editing and previewing is free with no limits. Sending, printing and saving PDFs needs Premium.")
                    RowDivider()
                    faq("How do I cancel?", "Payments are handled by Apple. Open Settings, tap your name, then Subscriptions. Deleting the app does not cancel the subscription.")
                    RowDivider()
                    faq("Where are my invoices stored?", "On your device and in your own iCloud. We never upload them to our servers.")
                    RowDivider()
                    faq("How do clients pay me?", "Add your bank details or payment links in Payment details. They appear on every invoice with a QR code.")
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle("Help and support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faq(_ question: LocalizedStringKey, _ answer: LocalizedStringKey) -> some View {
        DisclosureGroup {
            Text(answer).font(.subheadline).foregroundStyle(Color.ink2).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
        } label: {
            Text(question).font(.callout).foregroundStyle(Color.ink)
        }
        .padding(14)
        .tint(Color.ink3)
    }
}

/// Opens Mail with the report and app version (no invoices attached).
struct ReportProblemView: View {
    let business: Business
    @Environment(\.openURL) private var openURL
    @State private var topic = String(localized: "Sending or PDFs")
    @State private var message = ""
    @State private var includeDiagnostics = true

    private let topics = [
        String(localized: "Sending or PDFs"), String(localized: "Subscription or billing"),
        String(localized: "Backup and sync"), String(localized: "Something else"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GroupedSection(header: "What's it about?") {
                    Picker("Topic", selection: $topic) { ForEach(topics, id: \.self) { Text($0) } }
                        .pickerStyle(.menu).padding(.horizontal, 8).frame(minHeight: 48)
                }
                GroupedSection(header: "What happened?") {
                    TextField("Tell us what you tapped and what you expected", text: $message, axis: .vertical)
                        .lineLimit(5...12).padding(14)
                }
                GroupedSection {
                    Toggle("Include app version and device model", isOn: $includeDiagnostics).padding(.horizontal, 14).frame(minHeight: 48)
                }
                Button("Send report", action: send).buttonStyle(.primary).padding(16)
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("We reply within 24 hours. Your invoices are not attached.")
                    .font(.caption).foregroundStyle(Color.ink2).padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle("Report a problem")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() {
        var body = message
        if includeDiagnostics {
            body += "\n\n—\nDuly \(AppInfo.version) (\(AppInfo.build)) · \(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
        }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppLinks.supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Duly: \(topic)"), URLQueryItem(name: "body", value: body)]
        if let url = components.url { openURL(url) }
    }
}
