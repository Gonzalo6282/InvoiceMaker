import InvoiceKit
import SwiftUI

/// Default template, brand colour and logo for new documents.
struct InvoiceLookView: View {
    @Bindable var business: Business
    @State private var purchases = PurchaseManager.shared
    @AppStorage(MadeWithDuly.key) private var madeWithOn = true
    private var isPremium: Bool { purchases.isPremium }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header("Default template")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(InvoiceTemplate.allCases) { template in
                            let selected = InvoiceTemplate(id: business.templateID) == template
                            Button {
                                if template.isPremium {
                                    PaywallService.shared.gate(.templatePremium) { business.templateID = template.rawValue }
                                } else {
                                    business.templateID = template.rawValue
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    TemplateThumbnail(template: template, accentHex: business.brandColorHex, locked: template.isPremium && !isPremium)
                                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(selected ? Color.brand : Color.line, lineWidth: selected ? 2 : 1))
                                    Text(template.displayName).font(.footnote.weight(selected ? .semibold : .regular))
                                        .foregroundStyle(selected ? Color.brand : Color.ink2)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 16)
                }
                header("Brand colour")
                HStack(spacing: 12) {
                    ForEach(BrandColors.choices, id: \.self) { hex in
                        Button { business.brandColorHex = hex } label: {
                            Circle().fill(Color(uiColor: UIColor(hex: hex) ?? .systemIndigo)).frame(width: 34, height: 34)
                                .overlay(Circle().strokeBorder(Color.ink, lineWidth: business.brandColorHex == hex ? 2 : 0).padding(-4))
                        }
                        .accessibilityLabel(Text("Colour \(hex)"))
                    }
                }
                .padding(.horizontal, 20)
                Text("New invoices use this template and colour. You can change them on any invoice.")
                    .font(.caption).foregroundStyle(Color.ink2).padding(.horizontal, 16).padding(.top, 10)
                header("Logo")
                LogoPickerRow(business: business).padding(.horizontal, 16)
                header("Footer")
                Toggle(isOn: Binding(get: { madeWithOn }, set: { on in
                    madeWithOn = on
                    AppAnalytics.shared.log(.madeWithChanged, ["on": on ? "true" : "false"])
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show \"Made with Duly\" on PDFs").font(.callout).foregroundStyle(Color.ink)
                        Text("A small line at the bottom of the page. Thanks for helping others find Duly.")
                            .font(.footnote).foregroundStyle(Color.ink2)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, lineWidth: 1))
                .padding(.horizontal, 16)
                .accessibilityIdentifier("madeWithDuly")
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle("Invoice look")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.footnote.weight(.medium)).foregroundStyle(Color.ink2)
            .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 7)
    }
}

/// A small render of a sample invoice in a template.
struct TemplateThumbnail: View {
    let template: InvoiceTemplate
    let accentHex: String
    var locked = false
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image { Image(uiImage: image).resizable().scaledToFit() } else { Color.white }
            }
            .frame(width: 96, height: 136)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            if locked {
                Text("PRO").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.navy, in: Capsule()).padding(4)
            }
        }
        .task(id: accentHex) { image = SampleInvoice.thumbnail(template: template, accentHex: accentHex) }
    }
}

/// A fixed sample invoice for template thumbnails (no stored data needed).
enum SampleInvoice {
    static func thumbnail(template: InvoiceTemplate, accentHex: String) -> UIImage? {
        let model = InvoicePDFModel(
            template: template, paper: .a4, accentHex: accentHex, title: String(localized: "Invoice"), number: "INV-0012",
            logo: nil, initials: "KJ",
            from: .init(label: String(localized: "From"), name: "Kestrel Joinery", lines: ["Unit 4, Mill Yard", "Bristol BS3 4AQ"]),
            to: .init(label: String(localized: "Bill to"), name: "Marlow & Finch", lines: ["22 Queen Square"]),
            dates: [.init(label: String(localized: "Issued"), value: "18 Oct 2026"), .init(label: String(localized: "Due"), value: "1 Nov 2026")],
            job: template.jobBox ? "Queen Square office fit-out" : nil, showsTaxColumn: true,
            rows: [
                .init(description: "Bespoke shelving", discountNote: nil, quantity: "2", rate: "£87.50", tax: "20%", amount: "£175.00"),
                .init(description: "Site visit", discountNote: nil, quantity: "1", rate: "£52.50", tax: "20%", amount: "£52.50"),
            ],
            emptyRowsText: "", summary: [.init(label: "Subtotal", value: "£227.50"), .init(label: "VAT 20%", value: "£45.50")],
            totalLabel: String(localized: "Total due"), totalValue: "£273.00", showsPayment: true,
            bankLine: "Bank transfer · Sort code 04-00-04 · Account 31926819", payButtons: [.init(label: "PayPal", url: nil)],
            qrPayload: "https://paypal.me/example", notes: "Thank you for your business.", signatures: [], paidStamp: false,
            watermark: false)
        return PDFRenderer(model: model).renderFirstPageImage(width: 192)
    }
}
