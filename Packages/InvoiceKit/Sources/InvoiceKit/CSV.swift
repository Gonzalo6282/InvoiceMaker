import Foundation

/// Writes RFC 4180 CSV (comma-separated, CRLF line ends, double quotes).
/// Text that a spreadsheet would run as a formula (=, +, -, @, tab, CR at the
/// start) gets a leading apostrophe; plain numbers like -12.50 are left alone.
public enum CSVWriter {
    public static func string(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(field).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    static func field(_ raw: String) -> String {
        var value = raw
        if let first = value.first, "=+-@\t\r".contains(first), !isPlainNumber(value) {
            value = "'" + value
        }
        let needsQuotes = value.contains { ",\"\r\n".contains($0) } || value.first == " " || value.last == " "
        return needsQuotes ? "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : value
    }

    /// "-12.50", "3" — digits with an optional leading minus and one dot.
    static func isPlainNumber(_ value: String) -> Bool {
        value.wholeMatch(of: /-?[0-9]+(\.[0-9]+)?/) != nil
    }

    /// Money for CSV: dot decimal, 2 places, no grouping or symbol ("1234.50").
    public static func amount(_ value: Decimal) -> String {
        value.rounded().formatted(.number.locale(posix).grouping(.never).precision(.fractionLength(2)))
    }

    /// Dates for CSV: ISO 8601 day, e.g. 2026-10-18.
    public static func date(_ value: Date?, calendar: Calendar = .current) -> String {
        guard let value else { return "" }
        let c = calendar.dateComponents([.year, .month, .day], from: value)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static let posix = Locale(identifier: "en_US_POSIX")
}
