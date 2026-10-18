import Foundation
import InvoiceKit

extension Document {
    /// What InvoiceKit needs. All money maths goes through InvoiceKit.
    func calculatorInput(taxes: [TaxRate]) -> DocumentInput {
        DocumentInput(
            items: sortedItems.map {
                LineItemInput(quantity: $0.quantity, rate: $0.rate, discount: $0.discount, taxIDs: $0.taxIDs)
            },
            taxMode: taxMode,
            taxPlacement: taxPlacement,
            totalTaxIDs: totalTaxIDs,
            discount: discount,
            shipping: shipping,
            fees: fees,
            taxes: taxes)
    }

    func totals(taxes: [TaxRate]) -> Totals {
        Calculator.totals(for: calculatorInput(taxes: taxes))
    }

    func displayStatus(today: Date = .now, calendar: Calendar = .current) -> DisplayStatus {
        StatusRules.display(kind: kind, status: status, due: dueDate, today: today, calendar: calendar)
    }

    func summaryInput(taxes: [TaxRate]) -> SummaryInput {
        SummaryInput(
            kind: kind, status: status, due: dueDate, paidOn: paidOn, currencyCode: currencyCode,
            total: totals(taxes: taxes).total)
    }
}
