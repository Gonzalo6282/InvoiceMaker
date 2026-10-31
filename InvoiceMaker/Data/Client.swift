import Foundation
import SwiftData

extension SchemaV2 {
    @Model
    nonisolated final class Client {
        var name: String = ""
        var contactName: String = ""
        var email: String = ""
        var phone: String = ""
        var address: String = ""
        var taxID: String = ""
        /// Documents for this client use this currency.
        var currencyCode: String = "GBP"
        var notes: String = ""
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .nullify, inverse: \Document.client)
        var documents: [Document]? = []

        init(name: String = "", currencyCode: String = "GBP") {
            self.name = name
            self.currencyCode = currencyCode
        }
    }

    /// An item or service saved for reuse.
    @Model
    nonisolated final class SavedItem {
        var itemDescription: String = ""
        var unit: String = ""
        var rate: Decimal = 0
        var taxID: String?
        var createdAt: Date = Date.now

        init(itemDescription: String = "", unit: String = "", rate: Decimal = 0, taxID: String? = nil) {
            self.itemDescription = itemDescription
            self.unit = unit
            self.rate = rate
            self.taxID = taxID
        }
    }
}
