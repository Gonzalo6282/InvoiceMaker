import Foundation
import Testing

@testable import InvoiceMaker

struct DesignSystemTests {
    @Test(arguments: [
        ("Marlow & Finch Architects", "MF"), ("Ostara Café", "OC"), ("jonas", "J"), ("", "?"), ("  ", "?"),
        ("Ünal Öztürk", "ÜÖ"), ("4 Seasons Ltd", "4S"),
    ])
    func avatarInitials(name: String, expected: String) {
        #expect(Avatar.initials(for: name) == expected)
    }
}

struct DecimalFieldTests {
    let uk = Locale(identifier: "en_GB")
    let de = Locale(identifier: "de_DE")

    @Test func parsesTyping() {
        #expect(DecimalField.parse("", locale: uk) == 0)
        #expect(DecimalField.parse("5", locale: uk) == 5)
        #expect(DecimalField.parse("12.5", locale: uk) == Decimal(string: "12.5"))
        #expect(DecimalField.parse("1,234.50", locale: uk) == Decimal(string: "1234.5"))
        #expect(DecimalField.parse("12.", locale: uk) == 12)
        #expect(DecimalField.parse("12,5", locale: de) == Decimal(string: "12.5"))
        #expect(DecimalField.parse("1.234,5", locale: de) == Decimal(string: "1234.5"))
        #expect(DecimalField.parse("£40", locale: uk) == 40)
        #expect(DecimalField.parse("1.2.3", locale: uk) == nil)
        #expect(DecimalField.parse("abc", locale: uk) == nil)
        #expect(DecimalField.parse("-5", locale: uk) == 0)
    }

    @Test func displaysWithoutZero() {
        #expect(DecimalField.display(0) == "")
        #expect(!DecimalField.display(Decimal(string: "87.5")!).isEmpty)
    }
}
