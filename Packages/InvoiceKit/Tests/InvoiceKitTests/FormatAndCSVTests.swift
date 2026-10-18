import Foundation
import InvoiceKit
import Testing

/// Formatters may use no-break or narrow spaces; compare with plain spaces.
private func plain(_ s: String) -> String {
    s.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
}

struct MoneyFormatTests {
    let gb = Locale(identifier: "en_GB")

    @Test func symbol() {
        #expect(MoneyFormat.string(Decimal(string: "1234.5")!, currencyCode: "GBP", display: .symbol, locale: gb) == "£1,234.50")
        #expect(MoneyFormat.string(10, currencyCode: "USD", display: .symbol, locale: Locale(identifier: "en_US")) == "$10.00")
    }

    @Test func code() {
        let s = plain(MoneyFormat.string(Decimal(string: "1234.5")!, currencyCode: "GBP", display: .code, locale: gb))
        #expect(s.contains("GBP"))
        #expect(s.contains("1,234.50"))
        #expect(!s.contains("£"))
    }

    @Test func noCurrency() {
        #expect(MoneyFormat.string(Decimal(string: "1234.567")!, currencyCode: "GBP", display: .none, locale: gb) == "1,234.57")
    }

    @Test func roundsHalfUpBeforeFormatting() {
        #expect(MoneyFormat.string(Decimal(string: "0.125")!, currencyCode: "GBP", display: .symbol, locale: gb) == "£0.13")
    }

    @Test func allCases() {
        #expect(CurrencyDisplay.allCases == [.symbol, .code, .none])
    }
}

struct CSVTests {
    @Test func plainRows() {
        let csv = CSVWriter.string(header: ["Number", "Total"], rows: [["INV-0001", "273.00"]])
        #expect(csv == "Number,Total\r\nINV-0001,273.00\r\n")
    }

    @Test(arguments: [
        ("Smith, Jones & Co", "\"Smith, Jones & Co\""),
        ("6\" pipe", "\"6\"\" pipe\""),
        ("Unit 4\nMill Yard", "\"Unit 4\nMill Yard\""),
        ("Unit 4\r\nMill Yard", "\"Unit 4\r\nMill Yard\""),
        ("\r\nx", "\"'\r\nx\""),
        (" padded ", "\" padded \""),
        ("", ""),
        ("Café Ostara", "Café Ostara"),
    ])
    func escaping(raw: String, expected: String) {
        #expect(CSVWriter.string(header: [raw], rows: []) == expected + "\r\n")
    }

    @Test(arguments: [
        ("=SUM(A1:A9)", "'=SUM(A1:A9)"), ("+44 7700", "'+44 7700"), ("@cmd", "'@cmd"),
        ("-1+2", "'-1+2"), ("-12.50", "-12.50"), ("-", "'-"), ("\tx", "'\tx"),
    ])
    func formulaInjectionIsDefused(raw: String, expected: String) {
        #expect(CSVWriter.string(header: [raw], rows: []) == expected + "\r\n")
    }

    @Test func formulaWithCommaIsDefusedAndQuoted() {
        #expect(CSVWriter.string(header: ["=1,2"], rows: []) == "\"'=1,2\"\r\n")
    }

    @Test func amountsAndDates() {
        #expect(CSVWriter.amount(Decimal(string: "1234.5")!) == "1234.50")
        #expect(CSVWriter.amount(Decimal(string: "-0.005")!) == "-0.01")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        #expect(CSVWriter.date(date, calendar: cal) == "2026-03-07")
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(CSVWriter.date(cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 20))!, calendar: tokyo) == "2026-03-08")
        #expect(CSVWriter.date(nil) == "")
    }
}
