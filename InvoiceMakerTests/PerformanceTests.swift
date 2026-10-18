import Foundation
import InvoiceKit
import SwiftData
import Testing

@testable import InvoiceMaker

/// Spec: open an invoice in under 0.5 s with 1,000 invoices stored.
@MainActor
struct PerformanceTests {
    @Test func thousandInvoices() throws {
        let container = try ModelContainerFactory.make(.inMemory)
        let context = container.mainContext
        let business = BusinessSetup.create(name: "Kestrel Joinery", region: .uk, countryCode: "GB", in: context)
        let actions = DocumentActions(context: context)
        let clients = (0..<50).map { i -> Client in
            let c = Client(name: "Client \(i)")
            context.insert(c)
            return c
        }
        for i in 0..<1_000 {
            let doc = actions.create(.invoice, business: business, client: clients[i % clients.count])
            for j in 0..<3 {
                let line = actions.addLineItem(to: doc, defaultTaxID: "uk-vat20")
                line.itemDescription = "Item \(j)"
                line.quantity = Decimal(j + 1)
                line.rate = Decimal(10 * (i % 30 + 1))
            }
            if i % 3 == 0 { actions.markSent(doc) }
            if i % 7 == 0 { actions.markPaid(doc) }
        }
        try context.save()

        let clock = ContinuousClock()
        let taxes = try BusinessSetup.taxes(in: context)

        // The list: fetch everything and total it (what DocumentListView does).
        let listTime = try clock.measure {
            let docs = try context.fetch(FetchDescriptor<Document>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            let summary = MoneySummary(
                documents: docs.map { $0.summaryInput(taxes: taxes) }, currencyCode: "GBP", today: .now)
            #expect(docs.count == 1_000)
            #expect(summary.owed > 0)
        }

        // Opening one: totals + PDF model + render (the editor's live preview).
        let doc = try #require(try context.fetch(FetchDescriptor<Document>()).last)
        let openTime = clock.measure {
            _ = doc.totals(taxes: taxes)
            let model = InvoicePDFModelBuilder().build(document: doc, business: business, taxes: taxes)
            _ = PDFRenderer(model: model).render()
        }

        print("1,000 invoices: list \(listTime), open \(openTime)")
        #expect(openTime < .milliseconds(500), "Opening took \(openTime)")
        #expect(listTime < .seconds(5), "List took \(listTime)")  // CI simulators are slow; this is a smoke check
    }
}
