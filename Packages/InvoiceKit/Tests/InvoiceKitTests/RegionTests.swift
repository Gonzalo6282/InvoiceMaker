import Foundation
import InvoiceKit
import Testing

struct RegionTests {
    @Test(arguments: [
        ("GB", Region.uk), ("GBR", .uk), ("uk", .uk), ("AU", .au), ("AUS", .au),
        ("CA", .ca), ("CAN", .ca), ("US", .us), ("usa", .us),
    ])
    func parsesCountryCodes(code: String, region: Region) {
        #expect(Region(countryCode: code) == region)
    }

    @Test func unknownCountryHasNoPresetAndResolvesToUK() {
        #expect(Region(countryCode: "FR") == nil)
        #expect(Region.resolve(countryCode: "IRL") == .uk)
        #expect(Region.resolve(countryCode: nil) == .uk)
        #expect(Region.resolve(countryCode: "CAN") == .ca)
    }

    @Test func presets() {
        #expect(Region.uk.preset.taxes.map(\.label) == ["VAT 20%", "VAT 5%", "VAT 0%"])
        #expect(Region.uk.preset.currencyCode == "GBP")
        #expect(Region.uk.preset.taxIDLabel == "VAT number")
        #expect(Region.uk.preset.defaultTax?.id == "uk-vat20")
        #expect(Region.au.preset.taxes.map(\.label) == ["GST 10%"])
        #expect(Region.au.preset.localeIdentifier == "en_AU")
        #expect(Region.ca.preset.taxes.map(\.label) == ["GST 5%", "PST 7%", "QST 9.975%", "HST 13%", "HST 15%"])
        #expect(Region.us.preset.taxes.map(\.label) == ["Sales tax 8.875%"])
        #expect(Region.us.preset.taxIDLabel == "EIN")
        for region in Region.allCases {
            let ids = region.preset.taxes.map(\.id)
            #expect(Set(ids).count == ids.count)
        }
    }

    @Test func documentTitles() {
        #expect(Region.uk.title(for: .estimate, taxRegistered: true) == "Quote")
        #expect(Region.us.title(for: .estimate, taxRegistered: false) == "Estimate")
        #expect(Region.au.title(for: .invoice, taxRegistered: true) == "Tax invoice")
        #expect(Region.au.title(for: .invoice, taxRegistered: false) == "Invoice")
        #expect(Region.uk.title(for: .invoice, taxRegistered: true) == "Invoice")
        #expect(Region.ca.title(for: .receipt, taxRegistered: true) == "Receipt")
    }

    @Test func paperSizes() {
        #expect(PaperSize.for(countryCode: "USA") == .letter)
        #expect(PaperSize.for(countryCode: "ca") == .letter)
        #expect(PaperSize.for(countryCode: "GBR") == .a4)
        #expect(PaperSize.for(countryCode: "AU") == .a4)
        #expect(PaperSize.for(countryCode: nil) == .a4)
        #expect(PaperSize.letter.points.width == 612)
        #expect(PaperSize.a4.points.height == 841.89)
    }
}

struct NumberingTests {
    @Test func defaultsStartAtOne() {
        var n = DocumentNumbering()
        #expect(n.peek(.invoice) == "INV-0001")
        #expect(n.take(.invoice) == "INV-0001")
        #expect(n.take(.invoice) == "INV-0002")
        #expect(n.peek(.estimate) == "EST-0001")
        #expect(n.take(.receipt) == "REC-0001")
    }

    @Test func continuesFromStoredCounter() {
        var n = DocumentNumbering(next: [.invoice: 13])
        #expect(n.take(.invoice) == "INV-0013")
        #expect(n.next[.invoice] == 14)
    }

    @Test func customPrefixPaddingAndOverflow() {
        var n = DocumentNumbering(prefixes: [.invoice: "KJ/"], next: [.invoice: 99999], padding: 4)
        #expect(n.take(.invoice) == "KJ/99999")
        #expect(DocumentNumbering(prefixes: [:]).peek(.estimate) == "0001")
        #expect(DocumentNumbering(next: [.invoice: 0]).peek(.invoice) == "INV-0001")
        #expect(DocumentNumbering.format(prefix: "", number: 7, padding: 0) == "7")
        #expect(DocumentNumbering.format(prefix: "A", number: -3, padding: 2) == "A00")
    }

    @Test func codableRoundTrip() throws {
        let n = DocumentNumbering(next: [.invoice: 5, .estimate: 2])
        let back = try JSONDecoder().decode(DocumentNumbering.self, from: JSONEncoder().encode(n))
        #expect(back == n)
    }
}
