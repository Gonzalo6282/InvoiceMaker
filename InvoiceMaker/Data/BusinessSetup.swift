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

    /// The taxes as InvoiceKit values, in the user's order. Archived taxes are
    /// left out of pickers but still count for documents that use them.
    static func taxes(in context: ModelContext, includingArchived: Bool = true) throws -> [TaxRate] {
        let records = try context.fetch(FetchDescriptor<TaxRateRecord>(sortBy: [SortDescriptor(\.sortIndex)]))
        return records.filter { includingArchived || !$0.isArchived }.map(\.taxRate)
    }

    /// Replaces the user's taxes with the region preset (old ones are archived).
    static func restorePresets(for region: Region, business: Business, in context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<TaxRateRecord>())
        let presetIDs = Set(region.preset.taxes.map(\.id))
        for record in records where !presetIDs.contains(record.taxID) { record.isArchived = true }
        for (index, tax) in region.preset.taxes.enumerated() {
            if let existing = records.first(where: { $0.taxID == tax.id }) {
                existing.name = tax.name
                existing.rate = tax.rate
                existing.sortIndex = index
                existing.isArchived = false
            } else {
                context.insert(TaxRateRecord(taxID: tax.id, name: tax.name, rate: tax.rate, sortIndex: index))
            }
        }
        business.defaultTaxID = region.preset.defaultTax?.id
    }

    /// The one business (1.0 has a single business). Nil before onboarding.
    static func current(in context: ModelContext) throws -> Business? {
        primary(try context.fetch(FetchDescriptor<Business>(sortBy: [SortDescriptor(\.createdAt)])))
    }

    /// With more than one business (onboarding ran before iCloud had synced),
    /// use the one with a name, then with a logo, then the oldest.
    static func primary(_ businesses: [Business]) -> Business? {
        businesses.enumerated().min { a, b in
            func rank(_ x: (offset: Int, element: Business)) -> (Int, Int, Int) {
                (x.element.name.isEmpty ? 1 : 0, x.element.logoData == nil ? 1 : 0, x.offset)
            }
            return rank(a) < rank(b)
        }?.element
    }
}
