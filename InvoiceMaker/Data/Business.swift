import Foundation
import InvoiceKit
import SwiftData

extension SchemaV1 {
    /// The user's business. One per user in 1.0.
    @Model
    nonisolated final class Business {
        var name: String = ""
        /// "freelancer", "contractor", "shop" from onboarding.
        var role: String = ""
        /// ISO alpha-2, e.g. "GB".
        var countryCode: String = "GB"
        var email: String = ""
        var phone: String = ""
        var address: String = ""
        var taxID: String = ""
        var taxRegistered: Bool = false
        var currencyCode: String = "GBP"
        var currencyDisplayRaw: String = CurrencyDisplay.symbol.rawValue
        var defaultTaxID: String?
        @Attribute(.externalStorage) var logoData: Data?
        var brandColorHex: String = "#533AFD"
        var templateID: String = "clean"
        var dueDays: Int = 14
        var defaultNotes: String = ""
        @Attribute(.externalStorage) var signatureData: Data?

        var invoicePrefix: String = "INV-"
        var estimatePrefix: String = "EST-"
        var receiptPrefix: String = "REC-"
        var nextInvoiceNumber: Int = 1
        var nextEstimateNumber: Int = 1
        var nextReceiptNumber: Int = 1

        @Relationship(deleteRule: .cascade, inverse: \PaymentDetails.business)
        var payment: PaymentDetails?

        var createdAt: Date = Date.now

        init(name: String = "", countryCode: String = "GB") {
            self.name = name
            self.countryCode = countryCode
        }

        var region: Region { Region.resolve(countryCode: countryCode) }

        var currencyDisplay: CurrencyDisplay {
            get { CurrencyDisplay(rawValue: currencyDisplayRaw) ?? .symbol }
            set { currencyDisplayRaw = newValue.rawValue }
        }

        var numbering: DocumentNumbering {
            get {
                DocumentNumbering(
                    prefixes: [.invoice: invoicePrefix, .estimate: estimatePrefix, .receipt: receiptPrefix],
                    next: [.invoice: nextInvoiceNumber, .estimate: nextEstimateNumber, .receipt: nextReceiptNumber])
            }
            set {
                invoicePrefix = newValue.prefixes[.invoice] ?? invoicePrefix
                estimatePrefix = newValue.prefixes[.estimate] ?? estimatePrefix
                receiptPrefix = newValue.prefixes[.receipt] ?? receiptPrefix
                nextInvoiceNumber = newValue.next[.invoice] ?? nextInvoiceNumber
                nextEstimateNumber = newValue.next[.estimate] ?? nextEstimateNumber
                nextReceiptNumber = newValue.next[.receipt] ?? nextReceiptNumber
            }
        }

        /// Uses up and returns the next number for a new document.
        func takeNumber(for kind: DocumentKind) -> String {
            var n = numbering
            let value = n.take(kind)
            numbering = n
            return value
        }
    }

    /// How clients can pay: shown as buttons and a QR code on the invoice.
    @Model
    nonisolated final class PaymentDetails {
        var bankName: String = ""
        var sortCode: String = ""
        var accountNumber: String = ""
        var iban: String = ""
        var swift: String = ""
        var payPalMe: String = ""
        var venmo: String = ""
        var cashApp: String = ""
        var zelle: String = ""
        /// The user's own Stripe or Square payment link.
        var paymentLink: String = ""
        var showsQRCode: Bool = true
        var business: Business?

        init() {}
    }

    /// A tax the user has set up (seeded from the region preset).
    @Model
    nonisolated final class TaxRateRecord {
        /// Stable id referenced by line items and documents, e.g. "uk-vat20".
        var taxID: String = ""
        var name: String = ""
        var rate: Decimal = 0
        var sortIndex: Int = 0

        init(taxID: String, name: String, rate: Decimal, sortIndex: Int) {
            self.taxID = taxID
            self.name = name
            self.rate = rate
            self.sortIndex = sortIndex
        }

        var taxRate: TaxRate { TaxRate(id: taxID, name: name, rate: rate) }
    }
}
