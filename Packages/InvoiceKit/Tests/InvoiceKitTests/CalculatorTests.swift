import Foundation
import InvoiceKit
import Testing

private let vat20 = TaxRate(id: "vat20", name: "VAT", rate: 20)
private let vat0 = TaxRate(id: "vat0", name: "VAT", rate: 0)
private let gst = TaxRate(id: "gst", name: "GST", rate: 5)
private let pst = TaxRate(id: "pst", name: "PST", rate: 7)
private let allTaxes = [vat20, vat0, gst, pst]

private func d(_ s: String) -> Decimal { Decimal(string: s)! }

struct MockupCases {
    @Test func ukTaxAdded273() {
        let doc = DocumentInput(
            items: [
                LineItemInput(quantity: 2, rate: d("87.50"), taxIDs: ["vat20"]),
                LineItemInput(quantity: 1, rate: d("52.50"), taxIDs: ["vat20"]),
            ],
            taxes: allTaxes)
        let t = Calculator.totals(for: doc)
        #expect(t.subtotal == d("227.50"))
        #expect(t.taxes == [TaxLine(taxID: "vat20", name: "VAT", rate: 20, base: d("227.50"), amount: d("45.50"))])
        #expect(t.total == d("273.00"))
    }

    @Test func ukTaxIncluded237() {
        let doc = DocumentInput(
            items: [LineItemInput(quantity: 1, rate: 237, taxIDs: ["vat20"])],
            taxMode: .included, taxes: allTaxes)
        let t = Calculator.totals(for: doc)
        #expect(t.subtotal == 237)
        #expect(t.taxes.map(\.amount) == [d("39.50")])
        #expect(t.taxTotal == d("39.50"))
        #expect(t.total == d("237.00"))
    }

    @Test func canadaGstPlusPst89_60() {
        let doc = DocumentInput(
            items: [LineItemInput(quantity: 1, rate: 80, taxIDs: ["gst", "pst"])],
            taxes: allTaxes)
        let t = Calculator.totals(for: doc)
        #expect(t.taxes.map(\.name) == ["GST", "PST"])
        #expect(t.taxes.map(\.amount) == [4, d("5.60")])
        #expect(t.total == d("89.60"))
    }
}

struct CalculatorTests {
    @Test func emptyDocumentIsAllZero() {
        let t = Calculator.totals(for: DocumentInput(items: [], discount: .percent(10), taxes: allTaxes))
        #expect(t.subtotal == 0)
        #expect(t.discount == 0)
        #expect(t.taxes.isEmpty)
        #expect(t.total == 0)
    }

    @Test func documentDiscountIsSpreadBeforePerItemTax() {
        let doc = DocumentInput(
            items: [
                LineItemInput(quantity: 1, rate: 150, taxIDs: ["vat20"]),
                LineItemInput(quantity: 1, rate: 50, taxIDs: ["vat0"]),
            ],
            discount: .percent(10), taxes: allTaxes)
        let t = Calculator.totals(for: doc)
        #expect(t.discount == 20)
        #expect(t.taxes.map(\.taxID) == ["vat20", "vat0"])
        #expect(t.taxes.map(\.base) == [135, 45])
        #expect(t.taxes.map(\.amount) == [27, 0])
        #expect(t.total == 207)
    }

    @Test func amountDiscountWithTaxOnTotal() {
        let doc = DocumentInput(
            items: [LineItemInput(quantity: 4, rate: 25)],
            taxPlacement: .onTotal, totalTaxIDs: ["vat20"], discount: .amount(20), taxes: allTaxes)
        let t = Calculator.totals(for: doc)
        #expect(t.taxes.map(\.base) == [80])
        #expect(t.taxTotal == 16)
        #expect(t.total == 96)
    }

    @Test func onTotalIgnoresLineTaxes() {
        let doc = DocumentInput(
            items: [LineItemInput(quantity: 1, rate: 100, taxIDs: ["vat20"])],
            taxPlacement: .onTotal, totalTaxIDs: [], taxes: allTaxes)
        #expect(Calculator.totals(for: doc).taxes.isEmpty)
        #expect(Calculator.totals(for: doc).total == 100)
    }

    @Test func includedTaxSplitBetweenTwoTaxes() {
        let doc = DocumentInput(
            items: [LineItemInput(quantity: 1, rate: 112, taxIDs: ["gst", "pst"])],
            taxMode: .included, taxes: allTaxes)
        let t = Calculator.totals(for: doc)
        #expect(t.taxes.map(\.amount) == [5, 7])
        #expect(t.total == 112)
    }

    @Test func includedTaxAfterDocumentDiscount() {
        let doc = DocumentInput(
            items: [LineItemInput(quantity: 1, rate: 120, taxIDs: ["vat20"])],
            taxMode: .included, discount: .percent(10), taxes: allTaxes)
        let t = Calculator.totals(for: doc)
        #expect(t.taxTotal == 18)
        #expect(t.total == 108)
    }

    @Test func shippingAndFeesAreNotTaxed() {
        let doc = DocumentInput(
            items: [LineItemInput(quantity: 1, rate: 100, taxIDs: ["vat20"])],
            shipping: 10, fees: [Fee(name: "Call-out", amount: 5)], taxes: allTaxes)
        let t = Calculator.totals(for: doc)
        #expect(t.taxTotal == 20)
        #expect(t.shipping == 10)
        #expect(t.fees == 5)
        #expect(t.total == 135)
    }

    @Test func shippingAndFeesAddedWithTaxIncludedToo() {
        let doc = DocumentInput(
            items: [LineItemInput(quantity: 1, rate: 120, taxIDs: ["vat20"])],
            taxMode: .included, shipping: d("4.99"),
            fees: [Fee(name: "A", amount: 1), Fee(name: "B", amount: 2)], taxes: allTaxes)
        #expect(Calculator.totals(for: doc).total == d("127.99"))
    }

    @Test func eachTaxIsSummedThenRoundedOnce() {
        let line = LineItemInput(quantity: 1, rate: d("1.11"), taxIDs: ["vat20"])
        let t = Calculator.totals(for: DocumentInput(items: [line, line, line], taxes: allTaxes))
        #expect(t.taxTotal == d("0.67"))  // 3 × 0.222 = 0.666, not 3 × 0.22
        #expect(t.total == 4)
    }

    @Test func taxesKeepOrderOfFirstAppearanceAndAggregate() {
        let doc = DocumentInput(
            items: [
                LineItemInput(quantity: 1, rate: 100, taxIDs: ["pst"]),
                LineItemInput(quantity: 1, rate: 100, taxIDs: ["gst", "pst"]),
            ],
            taxes: allTaxes)
        let t = Calculator.totals(for: doc)
        #expect(t.taxes.map(\.taxID) == ["pst", "gst"])
        #expect(t.taxes.map(\.amount) == [14, 5])
        #expect(t.taxes.map(\.base) == [200, 100])
    }

    @Test func zeroRateTaxShowsOnlyWhenItAppliedToSomething() {
        let used = DocumentInput(items: [LineItemInput(quantity: 1, rate: 2050, taxIDs: ["vat0"])], taxes: allTaxes)
        #expect(Calculator.totals(for: used).taxes.map(\.label) == ["VAT 0%"])
        let unused = DocumentInput(items: [LineItemInput(quantity: 0, rate: 10, taxIDs: ["vat0"])], taxes: allTaxes)
        #expect(Calculator.totals(for: unused).taxes.isEmpty)
    }

    @Test func unknownTaxIDsAreIgnored() {
        let doc = DocumentInput(items: [LineItemInput(quantity: 1, rate: 10, taxIDs: ["gone", "vat20"])], taxes: allTaxes)
        #expect(Calculator.totals(for: doc).taxes.map(\.taxID) == ["vat20"])
    }

    @Test func totalsAreRoundedToPence() {
        let doc = DocumentInput(items: [LineItemInput(quantity: 3, rate: d("19.99"), discount: .percent(10))])
        let t = Calculator.totals(for: doc)
        #expect(t.subtotal == d("53.97"))
        #expect(t.total == d("53.97"))
    }
}

extension TaxLine {
    fileprivate var label: String { TaxRate(id: taxID, name: name, rate: rate).label }
}

struct TaxRateTests {
    @Test func labels() {
        #expect(TaxRate(id: "q", name: "QST", rate: d("9.975")).label == "QST 9.975%")
        #expect(vat20.label == "VAT 20%")
    }

    @Test func enumsCoverAllCases() {
        #expect(TaxMode.allCases == [.added, .included])
        #expect(TaxPlacement.allCases == [.perItem, .onTotal])
    }
}
