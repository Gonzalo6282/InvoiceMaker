import Foundation

/// How amounts show the currency (Build Doc row 14).
public enum CurrencyDisplay: String, CaseIterable, Sendable, Codable {
    /// £1,234.50
    case symbol
    /// GBP 1,234.50
    case code
    /// 1,234.50
    case none
}

public enum MoneyFormat {
    /// Formats an amount for display (rounded to 2 places; the currency decides how many show).
    public static func string(
        _ amount: Decimal, currencyCode: String, display: CurrencyDisplay, locale: Locale
    ) -> String {
        let value = amount.rounded()
        switch display {
        case .symbol:
            return value.formatted(
                .currency(code: currencyCode).presentation(.narrow).locale(locale))
        case .code:
            return value.formatted(
                .currency(code: currencyCode).presentation(.isoCode).locale(locale))
        case .none:
            return value.formatted(.number.locale(locale).precision(.fractionLength(2)))
        }
    }
}

/// Every currency the user can pick: the common ones first, then the rest A–Z by code.
public enum CurrencyList {
    public static let common = ["GBP", "USD", "EUR", "ZAR", "AUD", "CAD", "NZD"]

    /// Common ones, then the rest of the ISO currencies iOS knows. `current` is
    /// kept even if iOS doesn't list it, so a saved choice never disappears.
    public static func all(keeping current: String? = nil) -> [String] {
        var rest = Set(Locale.commonISOCurrencyCodes).subtracting(common)
        if let current, !common.contains(current) { rest.insert(current) }
        return common + rest.sorted()
    }

    /// "South African Rand" in the app's language, or the code if unknown.
    public static func name(_ code: String, locale: Locale = .current) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }
}
