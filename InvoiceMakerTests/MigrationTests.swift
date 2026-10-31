import Foundation
import InvoiceKit
import SwiftData
import Testing

@testable import InvoiceMaker

/// A store written by v1.0 (SchemaV1) must open in this version with its data.
@MainActor
struct MigrationTests {
    @Test func v1StoreOpensWithItsData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("v1-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let v1 = Schema(versionedSchema: SchemaV1.self)
            let old = try ModelContainer(for: v1, configurations: ModelConfiguration(schema: v1, url: url, cloudKitDatabase: .none))
            let context = old.mainContext
            let business = SchemaV1.Business()
            business.name = "Kestrel Joinery"
            context.insert(business)
            let doc = SchemaV1.Document()
            doc.number = "INV-0007"
            let item = SchemaV1.LineItem()
            item.itemDescription = "Shelving"
            item.rate = 87.5
            context.insert(doc)
            context.insert(item)
            item.document = doc
            try context.save()
        }
        let container = try ModelContainerFactory.make(.file(url))
        let context = container.mainContext
        let businesses = try context.fetch(FetchDescriptor<Business>())
        #expect(businesses.map(\.name) == ["Kestrel Joinery"])
        let docs = try context.fetch(FetchDescriptor<Document>())
        #expect(docs.map(\.number) == ["INV-0007"])
        #expect(docs.first?.sortedItems.map(\.itemDescription) == ["Shelving"])
        #expect(docs.first?.recurrence == nil)
        #expect(docs.first?.photos?.isEmpty ?? true)
        // New fields work after the migration.
        docs.first?.recurrence = .monthly
        context.insert(JobPhoto(position: 0, imageData: Data([1, 2, 3])))
        try context.save()
    }
}
