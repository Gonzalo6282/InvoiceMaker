import Foundation
import InvoiceKit
import Testing

struct RoundingTests {
    @Test(arguments: [
        ("1.005", "1.01"), ("1.004", "1"), ("2.5", "2.5"), ("0.125", "0.13"),
        ("-1.005", "-1.01"), ("39.499999", "39.5"), ("0", "0"),
    ])
    func roundsHalfUpToTwoPlaces(input: String, expected: String) {
        #expect(Decimal(string: input)!.rounded() == Decimal(string: expected)!)
    }

    @Test func roundsToOtherScales() {
        #expect(Decimal(string: "9.975")!.rounded(1) == Decimal(string: "10")!)
        #expect(Decimal(string: "12.3456")!.rounded(3) == Decimal(string: "12.346")!)
    }
}

struct DiscountTests {
    @Test func percentDiscount() {
        #expect(Discount.percent(10).amount(on: 250) == 25)
        #expect(Discount.percent(Decimal(string: "12.5")!).amount(on: 80) == 10)
    }

    @Test func amountDiscountIsCappedAtBase() {
        #expect(Discount.amount(30).amount(on: 250) == 30)
        #expect(Discount.amount(300).amount(on: 250) == 250)
    }

    @Test func noneAndNegativeValuesGiveZero() {
        #expect(Discount.none.amount(on: 100) == 0)
        #expect(Discount.percent(-5).amount(on: 100) == 0)
        #expect(Discount.amount(-5).amount(on: 100) == 0)
        #expect(Discount.amount(5).amount(on: -10) == 0)
    }

    @Test func percentOverHundredIsCapped() {
        #expect(Discount.percent(150).amount(on: 40) == 40)
    }

    @Test func isZero() {
        #expect(Discount.none.isZero)
        #expect(Discount.amount(0).isZero)
        #expect(!Discount.percent(1).isZero)
    }

    @Test func codableRoundTrip() throws {
        let original = Discount.percent(Decimal(string: "7.5")!)
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(Discount.self, from: data) == original)
    }
}

struct LineItemTests {
    @Test func grossDiscountAndNet() {
        let line = LineItemInput(quantity: 3, rate: Decimal(string: "19.99")!, discount: .percent(10))
        #expect(line.gross == Decimal(string: "59.97")!)
        #expect(line.discountAmount == Decimal(string: "5.997")!)
        #expect(line.net == Decimal(string: "53.973")!)
    }

    @Test func fractionalQuantity() {
        let line = LineItemInput(quantity: Decimal(string: "2.5")!, rate: 40)
        #expect(line.net == 100)
    }

    @Test func amountDiscountCappedAtLineGross() {
        let line = LineItemInput(quantity: 1, rate: 20, discount: .amount(50))
        #expect(line.net == 0)
    }
}
