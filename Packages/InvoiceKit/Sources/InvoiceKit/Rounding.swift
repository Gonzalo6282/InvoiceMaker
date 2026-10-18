import Foundation

extension Decimal {
    /// Rounds half away from zero (1.005 → 1.01, -1.005 → -1.01), the way
    /// people round money by hand. Never use `Double` for money.
    public func rounded(_ scale: Int = 2) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }

    /// Clamps to zero or more.
    var nonNegative: Decimal { self < 0 ? 0 : self }
}
