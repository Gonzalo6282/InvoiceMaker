import Foundation
import InvoiceKit
import SwiftData

@MainActor
enum BusinessSetup {
    /// Creates the business with its region's currency and tax presets.
    @discardableResult
    static func create(name: String, region: Region, countryCode: String, in context: ModelContext) -> Business {
        let preset = region.preset
        let business = Business(name: name, countryCode: countryCode)
        business.currencyCode = preset.currencyCode
        business.defaultTaxID = preset.defaultTax?.id
        business.payment = PaymentDetails()
        context.insert(business)
        for (index, tax) in preset.taxes.enumerated() {
            context.insert(TaxRateRecord(taxID: tax.id, name: tax.name, rate: tax.rate, sortIndex: index))
        }
        return business
    }

    /// The taxes as InvoiceKit values, in the user's order.
    static func taxes(in context: ModelContext) throws -> [TaxRate] {
        let records = try context.fetch(FetchDescriptor<TaxRateRecord>(sortBy: [SortDescriptor(\.sortIndex)]))
        return records.map(\.taxRate)
    }

    /// The one business (1.0 has a single business). Nil before onboarding.
    static func current(in context: ModelContext) throws -> Business? {
        var descriptor = FetchDescriptor<Business>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
