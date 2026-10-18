import Foundation

/// An extra charge on the document, e.g. "Call-out fee".
public struct Fee: Equatable, Hashable, Sendable, Codable {
    public var name: String
    public var amount: Decimal

    public init(name: String, amount: Decimal) {
        self.name = name
        self.amount = amount
    }
}

/// Everything the calculator needs from a document.
public struct DocumentInput: Equatable, Sendable {
    public var items: [LineItemInput]
    public var taxMode: TaxMode
    public var taxPlacement: TaxPlacement
    /// Taxes on the total, used when `taxPlacement == .onTotal`.
    public var totalTaxIDs: [String]
    /// Discount on the whole document (after line discounts).
    public var discount: Discount
    public var shipping: Decimal
    public var fees: [Fee]
    /// The taxes the ids above refer to.
    public var taxes: [TaxRate]

    public init(
        items: [LineItemInput],
        taxMode: TaxMode = .added,
        taxPlacement: TaxPlacement = .perItem,
        totalTaxIDs: [String] = [],
        discount: Discount = .none,
        shipping: Decimal = 0,
        fees: [Fee] = [],
        taxes: [TaxRate] = []
    ) {
        self.items = items
        self.taxMode = taxMode
        self.taxPlacement = taxPlacement
        self.totalTaxIDs = totalTaxIDs
        self.discount = discount
        self.shipping = shipping
        self.fees = fees
        self.taxes = taxes
    }
}

/// The totals block of a document. Money values are rounded to 2 places.
public struct Totals: Equatable, Sendable {
    /// Sum of line nets. With tax included, this includes the tax.
    public let subtotal: Decimal
    /// The document discount.
    public let discount: Decimal
    public let taxes: [TaxLine]
    public let taxTotal: Decimal
    public let shipping: Decimal
    public let fees: Decimal
    public let total: Decimal
}

public enum Calculator {
    /// Works out the totals. Matches `calc()` in the approved mockup:
    /// - the document discount is spread over the lines in proportion;
    /// - each tax is summed unrounded, then rounded once;
    /// - with tax included, the tax is the part of the price that is tax,
    ///   split between several taxes by their rates;
    /// - shipping and fees are never taxed.
    public static func totals(for doc: DocumentInput) -> Totals {
        let subtotal = doc.items.reduce(Decimal(0)) { $0 + $1.net }
        let discount = doc.discount.amount(on: subtotal)
        let afterDiscount = subtotal - discount
        let factor = subtotal == 0 ? 0 : afterDiscount / subtotal

        var buckets = TaxBuckets(mode: doc.taxMode, taxes: doc.taxes)
        switch doc.taxPlacement {
        case .perItem:
            for line in doc.items {
                buckets.add(line.taxIDs, base: line.net * factor)
            }
        case .onTotal:
            buckets.add(doc.totalTaxIDs, base: afterDiscount)
        }
        let taxLines = buckets.lines
        let taxTotal = taxLines.reduce(Decimal(0)) { $0 + $1.amount }

        let fees = doc.fees.reduce(Decimal(0)) { $0 + $1.amount }
        let roundedAfterDiscount = afterDiscount.rounded()
        let extras = doc.shipping + fees
        let total: Decimal =
            switch doc.taxMode {
            case .included: roundedAfterDiscount + extras
            case .added: roundedAfterDiscount + taxTotal + extras
            }

        return Totals(
            subtotal: subtotal.rounded(),
            discount: discount.rounded(),
            taxes: taxLines,
            taxTotal: taxTotal.rounded(),
            shipping: doc.shipping.rounded(),
            fees: fees.rounded(),
            total: total.rounded()
        )
    }
}

/// Collects tax amounts per tax id, in the order taxes first appear.
private struct TaxBuckets {
    let mode: TaxMode
    let taxes: [TaxRate]
    private var order: [String] = []
    private var amounts: [String: Decimal] = [:]
    private var bases: [String: Decimal] = [:]

    init(mode: TaxMode, taxes: [TaxRate]) {
        self.mode = mode
        self.taxes = taxes
    }

    mutating func add(_ ids: [String], base: Decimal) {
        let rates = ids.compactMap { id in taxes.first { $0.id == id } }
        let combined = rates.reduce(Decimal(0)) { $0 + $1.rate } / 100
        for tax in rates {
            let amount: Decimal =
                switch mode {
                case .added: base * tax.rate / 100
                case .included: base * (tax.rate / 100) / (1 + combined)
                }
            if amounts[tax.id] == nil { order.append(tax.id) }
            amounts[tax.id, default: 0] += amount
            bases[tax.id, default: 0] += base
        }
    }

    /// Zero-rate taxes still show (e.g. "VAT 0%") if they applied to something.
    var lines: [TaxLine] {
        order.compactMap { id in
            guard let tax = taxes.first(where: { $0.id == id }),
                let base = bases[id], let amount = amounts[id],
                tax.rate > 0 || base > 0
            else { return nil }
            return TaxLine(taxID: id, name: tax.name, rate: tax.rate, base: base, amount: amount.rounded())
        }
    }
}
