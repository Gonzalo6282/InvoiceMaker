import Foundation

/// One line on a document, as the calculator sees it.
public struct LineItemInput: Equatable, Hashable, Sendable, Codable {
    public var quantity: Decimal
    public var rate: Decimal
    public var discount: Discount
    /// Taxes applied to this line when tax is per item (ids of `TaxRate`).
    public var taxIDs: [String]

    public init(quantity: Decimal, rate: Decimal, discount: Discount = .none, taxIDs: [String] = []) {
        self.quantity = quantity
        self.rate = rate
        self.discount = discount
        self.taxIDs = taxIDs
    }

    /// Quantity × rate.
    public var gross: Decimal { quantity * rate }
    /// The line discount, capped at the gross.
    public var discountAmount: Decimal { discount.amount(on: gross) }
    /// Gross − line discount. Not rounded: rounding happens on the totals.
    public var net: Decimal { gross - discountAmount }
}
