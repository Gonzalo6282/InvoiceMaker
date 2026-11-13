import Foundation
import InvoiceKit
import Testing

struct RegionTests {
    @Test(arguments: [
        ("GB", Region.uk), ("GBR", .uk), ("uk", .uk), ("AU", .au), ("AUS", .au),
        ("CA", .ca), ("CAN", .ca), ("US", .us), ("usa", .us), ("DE", .de), ("deu", .de), ("FR", .fr), ("FRA", .fr),
        ("MX", .mx), ("mex", .mx), ("ES", .es), ("ESP", .es), ("ZA", .za), ("zaf", .za), ("NZ", .nz), ("nzl", .nz),
    ])
    func parsesCountryCodes(code: String, region: Region) {
        #expect(Region(countryCode: code) == region)
    }

    @Test func unknownCountryHasNoPresetAndResolvesToUK() {
        #expect(Region(countryCode: "IT") == nil)
        #expect(Region.resolve(countryCode: "IRL") == .uk)
        #expect(Region.resolve(countryCode: nil) == .uk)
        #expect(Region.resolve(countryCode: "CAN") == .ca)
    }

    @Test func presets() {
        #expect(Region.uk.preset.taxes.map(\.label) == ["VAT 20%", "VAT 5%", "VAT 0%"])
        #expect(Region.uk.preset.currencyCode == "GBP")
        #expect(Region.uk.preset.taxIDLabel == "VAT number")
        #expect(Region.uk.preset.defaultTax?.id == "uk-vat20")
        #expect(Region.au.preset.taxes.map(\.label) == ["GST 10%", "GST 0%"])
        #expect(Region.au.preset.defaultTax?.id == "au-gst10")
        #expect(Region.nz.preset.taxes.map(\.label) == ["GST 15%", "GST 0%"])
        #expect(Region.nz.preset.defaultTax?.id == "nz-gst15")
        #expect(Region.nz.preset.currencyCode == "NZD")
        #expect(Region.nz.preset.localeIdentifier == "en_NZ")
        #expect(Region.nz.preset.taxIDLabel == "GST No.")
        #expect(PaperSize.for(countryCode: "NZL") == .a4)
        #expect(Region.au.preset.localeIdentifier == "en_AU")
        #expect(Region.ca.preset.taxes.map(\.label) == ["GST 5%", "PST 7%", "PST 6%", "QST 9.975%", "HST 13%", "HST 14%", "HST 15%"])
        #expect(Region.ca.preset.taxes.map { Region.ca.taxName($0, french: true) } == ["TPS", "TVP", "TVP", "TVQ", "TVH", "TVH", "TVH"])
        #expect(Region.ca.taxName(Region.ca.preset.taxes[0], french: false) == "GST")
        #expect(Region.uk.taxName(Region.uk.preset.taxes[0], french: true) == "VAT")
        #expect(Region.us.preset.taxes.map(\.label) == ["Sales tax 8.875%"])
        #expect(Region.us.preset.taxIDLabel == "EIN")
        #expect(Region.de.preset.taxes.map(\.label) == ["MwSt. 19%", "MwSt. 7%", "MwSt. 0%"])
        #expect(Region.de.preset.currencyCode == "EUR")
        #expect(Region.de.preset.localeIdentifier == "de_DE")
        #expect(Region.fr.preset.taxes.map(\.label) == ["TVA 20%", "TVA 10%", "TVA 5.5%", "TVA 0%"])
        #expect(Region.fr.preset.taxIDLabel == "N° TVA")
        #expect(Region.mx.preset.taxes.map(\.label) == ["IVA 16%", "IVA 8%", "IVA 0%"])
        #expect(Region.mx.preset.currencyCode == "MXN")
        #expect(Region.mx.preset.taxIDLabel == "RFC")
        #expect(PaperSize.for(countryCode: "MEX") == .letter)
        #expect(Region.es.preset.taxes.map(\.label) == ["IVA 21%", "IVA 10%", "IVA 4%", "IVA 0%"])
        #expect(Region.es.preset.currencyCode == "EUR")
        #expect(Region.es.preset.taxIDLabel == "NIF")
        #expect(Region.za.preset.taxes.map(\.label) == ["VAT 15%", "VAT 0%"])
        #expect(Region.za.preset.defaultTax?.id == "za-vat15")
        #expect(Region.za.preset.currencyCode == "ZAR")
        #expect(Region.za.preset.localeIdentifier == "en_ZA")
        #expect(Region.za.preset.taxIDLabel == "VAT No.")
        #expect(PaperSize.for(countryCode: "ZAF") == .a4)
        for region in Region.allCases {
            let ids = region.preset.taxes.map(\.id)
            #expect(Set(ids).count == ids.count)
        }
    }

    @Test func documentTitles() {
        #expect(Region.uk.title(for: .estimate, taxRegistered: true) == "Quote")
        #expect(Region.us.title(for: .estimate, taxRegistered: false) == "Estimate")
        #expect(Region.au.title(for: .estimate, taxRegistered: false) == "Quote")
        #expect(Region.ca.title(for: .estimate, taxRegistered: false) == "Estimate")
        #expect(Region.au.title(for: .invoice, taxRegistered: true) == "Tax invoice")
        #expect(Region.au.title(for: .invoice, taxRegistered: false) == "Invoice")
        #expect(Region.uk.title(for: .invoice, taxRegistered: true) == "Invoice")
        #expect(Region.ca.title(for: .receipt, taxRegistered: true) == "Receipt")
        #expect(Region.de.title(for: .estimate, taxRegistered: true) == "Estimate")
        #expect(Region.fr.title(for: .invoice, taxRegistered: true) == "Invoice")
        #expect(Region.mx.title(for: .estimate, taxRegistered: true) == "Estimate")  // "Cotización" in Spanish
        #expect(Region.za.title(for: .invoice, taxRegistered: true) == "Tax invoice")
        #expect(Region.za.title(for: .invoice, taxRegistered: false) == "Invoice")
        #expect(Region.za.title(for: .estimate, taxRegistered: false) == "Quote")
        #expect(Region.nz.title(for: .invoice, taxRegistered: true) == "Tax invoice")
        #expect(Region.nz.title(for: .invoice, taxRegistered: false) == "Invoice")
        #expect(Region.nz.title(for: .estimate, taxRegistered: true) == "Quote")
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
