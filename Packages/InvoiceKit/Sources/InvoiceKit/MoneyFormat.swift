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
