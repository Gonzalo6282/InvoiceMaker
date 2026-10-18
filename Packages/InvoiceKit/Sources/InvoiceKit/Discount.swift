import Foundation

/// A discount on one line or on the whole document.
public enum Discount: Equatable, Hashable, Sendable, Codable {
    case percent(Decimal)
    case amount(Decimal)

    public static let none = Discount.percent(0)

    /// The amount taken off `base`. Never negative and never more than `base`.
    public func amount(on base: Decimal) -> Decimal {
        let base = base.nonNegative
        switch self {
        case .percent(let value):
            return min(base * value.nonNegative / 100, base)
        case .amount(let value):
            return min(value.nonNegative, base)
        }
    }

    public var isZero: Bool {
        switch self {
        case .percent(let value), .amount(let value): value == 0
        }
    }
}
