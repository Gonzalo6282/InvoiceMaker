import InvoiceKit
import SwiftUI

/// One document in the list: client initials, client name, number · due text,
/// amount and status pill (mockup `.docrow`).
struct DocumentRow: View {
    let document: Document
    let business: Business
    let total: Decimal

    var body: some View {
        let status = document.displayStatus()
        HStack(spacing: 12) {
            Avatar(name: document.client?.name ?? "")
            VStack(alignment: .leading, spacing: 2) {
                Text(document.client?.name ?? String(localized: "No client"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text("\(document.number) · \(document.dueText(business: business))")
                    .font(.footnote)
                    .foregroundStyle(status == .overdue ? Color.due : Color.ink2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 4) {
                Text(business.money(total, currency: document.currencyCode))
                    .font(.callout.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                StatusPill(status: status)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
