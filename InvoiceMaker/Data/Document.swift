import Foundation
import InvoiceKit
import SwiftData

extension SchemaV1 {
    /// An invoice, estimate (quote) or receipt.
    @Model
    final class Document {
        var kindRaw: String = DocumentKind.invoice.rawValue
        var number: String = ""
        var statusRaw: String = DocumentStatus.draft.rawValue
        var issueDate: Date = Date.now
        /// Due date (invoice) or valid-until date (estimate).
        var dueDate: Date?
        var sentAt: Date?
        var paidOn: Date?
        /// Copied from the client when the document is created.
        var currencyCode: String = "GBP"
        var taxModeRaw: String = TaxMode.added.rawValue
        var taxPlacementRaw: String = TaxPlacement.perItem.rawValue
        var totalTaxIDs: [String] = []
        var discountIsPercent: Bool = true
        var discountValue: Decimal = 0
        var shipping: Decimal = 0
        var fees: [Fee] = []
        var notes: String = ""
        var job: String = ""
        var templateID: String = "clean"
        var brandColorHex: String = "#533AFD"
        @Attribute(.externalStorage) var clientSignatureData: Data?
        var signedName: String = ""
        var signedAt: Date?
        /// Set on an invoice made from an estimate, e.g. "EST-0004".
        var fromEstimateNumber: String?
        /// Set on an estimate after it was turned into an invoice.
        var convertedToNumber: String?
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now

        var client: Client?

        @Relationship(deleteRule: .cascade, inverse: \LineItem.document)
        var items: [LineItem]? = []

        init(kind: DocumentKind, number: String, issueDate: Date = .now) {
            self.kindRaw = kind.rawValue
            self.number = number
            self.issueDate = issueDate
        }

        var kind: DocumentKind {
            get { DocumentKind(rawValue: kindRaw) ?? .invoice }
            set { kindRaw = newValue.rawValue }
        }

        var status: DocumentStatus {
            get { DocumentStatus(rawValue: statusRaw) ?? .draft }
            set { statusRaw = newValue.rawValue }
        }

        var taxMode: TaxMode {
            get { TaxMode(rawValue: taxModeRaw) ?? .added }
            set { taxModeRaw = newValue.rawValue }
        }

        var taxPlacement: TaxPlacement {
            get { TaxPlacement(rawValue: taxPlacementRaw) ?? .perItem }
            set { taxPlacementRaw = newValue.rawValue }
        }

        var discount: Discount {
            get { discountIsPercent ? .percent(discountValue) : .amount(discountValue) }
            set {
                switch newValue {
                case .percent(let v): discountIsPercent = true; discountValue = v
                case .amount(let v): discountIsPercent = false; discountValue = v
                }
            }
        }

        /// Line items in the order the user arranged them.
        var sortedItems: [LineItem] { (items ?? []).sorted { $0.position < $1.position } }
    }

    @Model
    final class LineItem {
        var position: Int = 0
        var itemDescription: String = ""
        var unit: String = ""
        var quantity: Decimal = 1
        var rate: Decimal = 0
        var discountIsPercent: Bool = true
        var discountValue: Decimal = 0
        var taxIDs: [String] = []
        var document: Document?

        init(position: Int, itemDescription: String = "", quantity: Decimal = 1, rate: Decimal = 0, taxIDs: [String] = []) {
            self.position = position
            self.itemDescription = itemDescription
            self.quantity = quantity
            self.rate = rate
            self.taxIDs = taxIDs
        }

        var discount: Discount {
            get { discountIsPercent ? .percent(discountValue) : .amount(discountValue) }
            set {
                switch newValue {
                case .percent(let v): discountIsPercent = true; discountValue = v
                case .amount(let v): discountIsPercent = false; discountValue = v
                }
            }
        }
    }
}
