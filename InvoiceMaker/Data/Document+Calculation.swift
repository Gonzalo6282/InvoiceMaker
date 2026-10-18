import Foundation
import InvoiceKit

extension Document {
    /// Frozen rates win; current rates fill in anything not frozen.
    func effectiveTaxes(_ current: [TaxRate]) -> [TaxRate] {
        guard !frozenTaxes.isEmpty else { return current }
        let frozenIDs = Set(frozenTaxes.map(\.id))
        return frozenTaxes + current.filter { !frozenIDs.contains($0.id) }
    }

    /// Records the rates this document uses (called when it's sent or paid).
    func freezeTaxes(_ current: [TaxRate]) {
        guard frozenTaxes.isEmpty else { return }
        let used = Set((items ?? []).flatMap(\.taxIDs) + totalTaxIDs)
        frozenTaxes = current.filter { used.contains($0.id) }
    }

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
            taxes: effectiveTaxes(taxes))
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
