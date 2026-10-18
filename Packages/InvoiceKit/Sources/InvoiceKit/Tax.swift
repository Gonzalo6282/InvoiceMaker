import Foundation

/// A named tax the user has set up, e.g. "VAT 20%". Tax is arithmetic only:
/// the user sets the rate, we apply it.
public struct TaxRate: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    /// Percent, e.g. 20 for 20%, 9.975 for Québec QST.
    public var rate: Decimal

    public init(id: String, name: String, rate: Decimal) {
        self.id = id
        self.name = name
        self.rate = rate
    }

    /// "VAT 20%", "QST 9.975%".
    public var label: String { "\(name) \(rate)%" }
}

/// Whether prices already include tax or tax is added on top.
public enum TaxMode: String, Sendable, Codable, CaseIterable {
    case added
    case included
}

/// Whether each line picks its own taxes or one set of taxes applies to the total.
public enum TaxPlacement: String, Sendable, Codable, CaseIterable {
    case perItem
    case onTotal
}

/// One tax as it appears in the totals block.
public struct TaxLine: Equatable, Sendable {
    public let taxID: String
    public let name: String
    public let rate: Decimal
    /// What the tax was worked out on (after discounts), not rounded.
    public let base: Decimal
    /// The tax, rounded to 2 places.
    public let amount: Decimal

    public init(taxID: String, name: String, rate: Decimal, base: Decimal, amount: Decimal) {
        self.taxID = taxID
        self.name = name
        self.rate = rate
        self.base = base
        self.amount = amount
    }
}
