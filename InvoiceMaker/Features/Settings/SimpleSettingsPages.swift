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
                    FieldRow(label: business.region.usesQuote ? "Quote prefix" : "Estimate prefix") {
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

/// What the last iCloud sync did, so problems (full iCloud, not signed in,
/// server errors) can be seen without Xcode.
struct SyncStatusSection: View {
    @State private var watcher = CloudImportWatcher.shared

    var body: some View {
        GroupedSection(header: "Backup status") {
            VStack(alignment: .leading, spacing: 8) {
                line("Saved to", watcher.storeDescription, ok: watcher.storeDescription == String(localized: "iCloud"))
                // Setup is only worth showing when it failed.
                if let setup = watcher.lastResults["Setup"], let error = setup.error {
                    line("iCloud setup", error, ok: false)
                }
                result("Last backup", watcher.lastResults["Upload"])
                result("Last restore", watcher.lastResults["Download"])
            }
            .padding(14)
            .textSelection(.enabled)
        }
    }

    private func result(_ title: LocalizedStringKey, _ result: CloudImportWatcher.SyncResult?) -> some View {
        guard let result else { return line(title, String(localized: "Not yet"), ok: nil) }
        if let error = result.error { return line(title, error, ok: false) }
        return line(title, Self.when(result.date), ok: true)
    }

    /// "Today at 22:29", "Yesterday at 09:10" or "21 Oct at 22:29".
    static func when(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Today at \(time)") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Yesterday at \(time)")
        }
        return String(localized: "\(date.formatted(.dateTime.day().month(.abbreviated))) at \(time)")
    }

    private func line(_ title: LocalizedStringKey, _ value: String, ok: Bool?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Color.ink)
            Spacer()
            Text(value).font(.footnote).multilineTextAlignment(.trailing)
                .foregroundStyle(ok == false ? Color.due : Color.ink2)
        }
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
                SyncStatusSection()
            }
        }
        .background(Color.canvas)
        .navigationTitle("iCloud backup")
        .navigationBarTitleDisplayMode(.inline)
    }
}
