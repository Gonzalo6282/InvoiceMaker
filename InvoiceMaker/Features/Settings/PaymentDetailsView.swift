import InvoiceKit
import SwiftUI

/// Bank details and payment links printed on invoices as buttons and a QR code.
struct PaymentDetailsView: View {
    let business: Business

    var body: some View {
        ScrollView {
            if let p = business.payment {
                PaymentFields(payment: p, region: business.region)
            }
        }
        .background(Color.canvas)
        .navigationTitle("Payment details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if business.payment == nil { business.payment = PaymentDetails() }
        }
    }
}

private struct PaymentFields: View {
    @Bindable var payment: PaymentDetails
    let region: Region

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Banner(tone: .info, systemImage: "qrcode",
                   text: Text("These show on your invoices as buttons and a QR code. Clients pay you directly. Duly never touches the money."))
            GroupedSection(header: "Bank transfer") {
                FieldRow(label: "Account name") { TextField("Optional", text: $payment.bankName) }
                RowDivider()
                if !region.usesIBAN {  // Germany and France: IBAN and BIC only
                    FieldRow(label: sortCodeLabel) { TextField("Optional", text: $payment.sortCode).keyboardType(.numbersAndPunctuation) }
                    RowDivider()
                    FieldRow(label: "Account number") { TextField("Optional", text: $payment.accountNumber).keyboardType(.numberPad) }
                    RowDivider()
                }
                FieldRow(label: "IBAN") { TextField("Optional", text: $payment.iban).textInputAutocapitalization(.characters) }
                RowDivider()
                FieldRow(label: "SWIFT / BIC") { TextField("Optional", text: $payment.swift).textInputAutocapitalization(.characters) }
            }
            GroupedSection(header: "Links", footer: "A general payment link can't know the invoice total, so your client types the amount.") {
                linkField("PayPal.me", "paypal.me/you", $payment.payPalMe)
                RowDivider()
                linkField("Venmo", "@username", $payment.venmo)
                RowDivider()
                linkField("Cash App", "$cashtag", $payment.cashApp)
                RowDivider()
                linkField("Zelle", "Email or phone", $payment.zelle)
                RowDivider()
                linkField("Stripe or Square link", "https://", $payment.paymentLink)
            }
            GroupedSection(header: "QR code") {
                Toggle(isOn: $payment.showsQRCode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show a QR code").font(.callout)
                        Text("Opens your payment link when scanned").font(.footnote).foregroundStyle(Color.ink2)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .padding(.bottom, 24)
    }

    private var sortCodeLabel: LocalizedStringKey {
        switch region {
        case .uk: "Sort code"
        case .au: "BSB"
        case .us, .ca: "Routing number"
        case .de, .fr: "Bank code"
        }
    }

    private func linkField(_ label: LocalizedStringKey, _ placeholder: LocalizedStringKey, _ text: Binding<String>) -> some View {
        FieldRow(label: label) {
            TextField(placeholder, text: text)
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
        }
    }
}

extension Region {
    /// Euro countries: bank details are IBAN and BIC.
    var usesIBAN: Bool { self == .de || self == .fr }
}
