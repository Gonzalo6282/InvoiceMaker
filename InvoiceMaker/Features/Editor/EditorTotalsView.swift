import InvoiceKit
import SwiftUI

/// The totals card under the tax section (mockup `.totals`).
struct EditorTotalsView: View {
    let totals: Totals
    let document: Document
    let business: Business

    var body: some View {
        VStack(spacing: 0) {
            line(document.taxMode == .included ? String(localized: "Subtotal (incl. tax)") : String(localized: "Subtotal"), totals.subtotal)
            if totals.discount != 0 { line(String(localized: "Discount"), -totals.discount) }
            ForEach(totals.taxes, id: \.taxID) { tax in
                let label = "\(tax.name) \(tax.rate.formatted())%"
                line(document.taxMode == .included ? String(localized: "Includes \(label)") : label, tax.amount)
            }
            if totals.shipping != 0 { line(String(localized: "Shipping"), totals.shipping) }
            if totals.fees != 0 { line(String(localized: "Fees"), totals.fees) }
            Rectangle().fill(Color.line).frame(height: 1).padding(.top, 6)
            HStack(alignment: .firstTextBaseline) {
                Text("Total").font(.body.weight(.bold)).foregroundStyle(Color.ink)
                Spacer()
                Text(business.money(totals.total, currency: document.currencyCode))
                    .textStyle(.total)
                    .foregroundStyle(Color.ink)
                    .accessibilityIdentifier("documentTotal")
            }
            .padding(.top, 11)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func line(_ label: String, _ amount: Decimal) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(business.money(amount, currency: document.currencyCode)).monospacedDigit()
        }
        .font(.subheadline)
        .foregroundStyle(Color.ink2)
        .padding(.vertical, 5)
    }
}
