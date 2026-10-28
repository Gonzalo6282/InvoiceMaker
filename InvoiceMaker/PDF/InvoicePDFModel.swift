import Foundation
import InvoiceKit

/// Everything printed on one document, already formatted. Built by
/// `InvoicePDFModelBuilder` (testable without UIKit), drawn by `PDFRenderer`.
struct InvoicePDFModel: Sendable {
    struct Party: Sendable, Equatable {
        var label: String
        var name: String
        var lines: [String]
    }

    struct DateBlock: Sendable, Equatable {
        var label: String
        var value: String
    }

    struct LineRow: Sendable, Equatable {
        var description: String
        var discountNote: String?
        var quantity: String
        var rate: String
        var tax: String?
        var amount: String
    }

    struct SummaryRow: Sendable, Equatable {
        var label: String
        var value: String
    }

    struct PayButton: Sendable, Equatable {
        var label: String
        var url: URL?
    }

    struct Signature: Sendable, Equatable {
        var label: String?
        var image: Data?
        var caption: String?
        /// Show an empty line to sign on (estimates before signing).
        var blankLine: Bool = false
    }

    var template: InvoiceTemplate
    var paper: PaperSize
    var accentHex: String
    var title: String
    var number: String
    var logo: Data?
    var initials: String
    var from: Party
    var to: Party
    var dates: [DateBlock]
    var job: String?
    var showsTaxColumn: Bool
    var rows: [LineRow]
    var emptyRowsText: String
    var summary: [SummaryRow]
    var totalLabel: String
    var totalValue: String
    /// "How to pay" block: only on invoices.
    var showsPayment: Bool
    var bankLine: String?
    var payButtons: [PayButton]
    var qrPayload: String?
    var notes: String
    var signatures: [Signature]
    var paidStamp: Bool
    var watermark: Bool
    /// "Made with Duly" at the bottom of the last page (nil when turned off).
    var madeWith: String?

    /// Column headings.
    var headings: (description: String, quantity: String, rate: String, tax: String, amount: String) {
        (
            String(localized: "Description"), String(localized: "Qty"), String(localized: "Rate"),
            String(localized: "Tax"), String(localized: "Amount")
        )
    }
}
