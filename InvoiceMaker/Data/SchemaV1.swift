import Foundation
import InvoiceKit
import SwiftData

/// Version 1 of the data model, as shipped in v1.0. FROZEN: never edit. It is
/// only here so stores made by v1.0 can be migrated to the current version
/// (`SchemaV2`). Stored properties, types, options and relationships must stay
/// exactly as in v1.0, or SwiftData won't recognise those stores.
enum SchemaV1: VersionedSchema {
    nonisolated static let versionIdentifier = Schema.Version(1, 0, 0)

    nonisolated static var models: [any PersistentModel.Type] {
        [Business.self, PaymentDetails.self, TaxRateRecord.self, Client.self, SavedItem.self, Document.self, LineItem.self]
    }

    @Model
    nonisolated final class Business {
        var name: String = ""
        var role: String = ""
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

        init() {}
    }

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
        var paymentLink: String = ""
        var showsQRCode: Bool = true
        var business: Business?

        init() {}
    }

    @Model
    nonisolated final class TaxRateRecord {
        var taxID: String = ""
        var name: String = ""
        var rate: Decimal = 0
        var sortIndex: Int = 0
        var isArchived: Bool = false

        init() {}
    }

    @Model
    nonisolated final class Client {
        var name: String = ""
        var contactName: String = ""
        var email: String = ""
        var phone: String = ""
        var address: String = ""
        var taxID: String = ""
        var currencyCode: String = "GBP"
        var notes: String = ""
        var createdAt: Date = Date.now
        @Relationship(deleteRule: .nullify, inverse: \Document.client)
        var documents: [Document]? = []

        init() {}
    }

    @Model
    nonisolated final class SavedItem {
        var itemDescription: String = ""
        var unit: String = ""
        var rate: Decimal = 0
        var taxID: String?
        var createdAt: Date = Date.now

        init() {}
    }

    @Model
    nonisolated final class Document {
        var kindRaw: String = DocumentKind.invoice.rawValue
        var number: String = ""
        var statusRaw: String = DocumentStatus.draft.rawValue
        var issueDate: Date = Date.now
        var dueDate: Date?
        var sentAt: Date?
        var paidOn: Date?
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
        var fromEstimateNumber: String?
        var convertedToNumber: String?
        var frozenTaxes: [TaxRate] = []
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var client: Client?
        @Relationship(deleteRule: .cascade, inverse: \LineItem.document)
        var items: [LineItem]? = []

        init() {}
    }

    @Model
    nonisolated final class LineItem {
        var position: Int = 0
        var itemDescription: String = ""
        var unit: String = ""
        var quantity: Decimal = 1
        var rate: Decimal = 0
        var discountIsPercent: Bool = true
        var discountValue: Decimal = 0
        var taxIDs: [String] = []
        var document: Document?

        init() {}
    }
}
