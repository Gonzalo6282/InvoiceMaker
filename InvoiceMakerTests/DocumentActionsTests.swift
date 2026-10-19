import Foundation
import InvoiceKit
import SwiftData
import Testing

@testable import InvoiceMaker

@MainActor
struct DocumentActionsTests {
    let container: ModelContainer
    let context: ModelContext
    let business: Business
    let actions: DocumentActions
    let today: Date
    let calendar: Calendar

    init() throws {
        container = try ModelContainerFactory.makeForTests()
        context = container.mainContext
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London")!
        calendar = cal
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12))!
        today = now
        business = BusinessSetup.create(name: "Kestrel Joinery", region: .uk, countryCode: "GB", in: context)
        actions = DocumentActions(context: context, calendar: cal, now: { now })
    }

    private func taxes() throws -> [TaxRate] { try BusinessSetup.taxes(in: context) }

    // MARK: Setup

    @Test func businessGetsRegionPresets() throws {
        #expect(business.currencyCode == "GBP")
        #expect(business.defaultTaxID == "uk-vat20")
        #expect(try taxes().map(\.label) == ["VAT 20%", "VAT 5%", "VAT 0%"])
        #expect(try BusinessSetup.current(in: context) === business)
        #expect(business.payment != nil)
    }

    // MARK: Create

    @Test func createUsesNextNumberDefaultsAndClientCurrency() throws {
        business.dueDays = 30
        business.defaultNotes = "Thanks!"
        let lund = Client(name: "Lund", currencyCode: "EUR")
        context.insert(lund)
        let first = actions.create(.invoice, business: business, client: lund)
        let second = actions.create(.invoice, business: business)
        #expect(first.number == "INV-0001")
        #expect(second.number == "INV-0002")
        #expect(business.nextInvoiceNumber == 3)
        #expect(first.currencyCode == "EUR")
        #expect(second.currencyCode == "GBP")
        #expect(first.status == .draft)
        #expect(first.notes == "Thanks!")
        #expect(first.dueDate == calendar.date(byAdding: .day, value: 30, to: today))
        #expect(actions.create(.estimate, business: business).number == "EST-0001")
    }

    @Test func receiptIsCreatedPaid() {
        let receipt = actions.create(.receipt, business: business)
        #expect(receipt.number == "REC-0001")
        #expect(receipt.status == .paid)
        #expect(receipt.paidOn == today)
        #expect(receipt.dueDate == nil)
    }

    // MARK: Line items (bug checklist: delete a line item and reopen)

    @Test func addDeleteAndReorderLineItems() throws {
        let doc = actions.create(.invoice, business: business)
        let a = actions.addLineItem(to: doc, defaultTaxID: "uk-vat20")
        let b = actions.addLineItem(to: doc)
        let c = actions.addLineItem(to: doc)
        a.itemDescription = "A"
        b.itemDescription = "B"
        c.itemDescription = "C"
        #expect(a.taxIDs == ["uk-vat20"])
        #expect(b.taxIDs.isEmpty)
        try context.save()

        actions.deleteLineItem(b)
        try context.save()
        #expect(doc.sortedItems.map(\.itemDescription) == ["A", "C"])
        #expect(doc.sortedItems.map(\.position) == [0, 1])

        // Reopen: fetch fresh from a new context.
        let reopened = try ModelContext(container).fetch(FetchDescriptor<Document>()).first
        #expect(reopened?.sortedItems.map(\.itemDescription) == ["A", "C"])
        #expect(try context.fetchCount(FetchDescriptor<LineItem>()) == 2)

        actions.moveLineItems(in: doc, from: [1], to: 0)
        #expect(doc.sortedItems.map(\.itemDescription) == ["C", "A"])
        let d = actions.addLineItem(to: doc)
        d.itemDescription = "D"
        actions.moveLineItems(in: doc, from: [0], to: 3)  // C to the end
        #expect(doc.sortedItems.map(\.itemDescription) == ["A", "D", "C"])
        actions.moveLineItems(in: doc, from: [0, 2], to: 1)  // A and C before D
        #expect(doc.sortedItems.map(\.itemDescription) == ["A", "C", "D"])
    }

    @Test func addFromSavedItem() {
        let saved = SavedItem(itemDescription: "Labour", unit: "hour", rate: 45, taxID: "uk-vat5")
        context.insert(saved)
        let doc = actions.create(.invoice, business: business)
        let item = actions.addLineItem(to: doc, from: saved, defaultTaxID: "uk-vat20")
        #expect(item.itemDescription == "Labour")
        #expect(item.unit == "hour")
        #expect(item.rate == 45)
        #expect(item.taxIDs == ["uk-vat5"])
    }

    // MARK: Totals through InvoiceKit

    @Test func totalsMatchTheMockupCase() throws {
        let doc = actions.create(.invoice, business: business)
        let a = actions.addLineItem(to: doc, defaultTaxID: "uk-vat20")
        a.quantity = 2
        a.rate = 87.5
        let b = actions.addLineItem(to: doc, defaultTaxID: "uk-vat20")
        b.rate = 52.5
        #expect(doc.totals(taxes: try taxes()).total == 273)
        doc.discount = .amount(27.5)
        doc.fees = [Fee(name: "Call-out", amount: 10)]
        #expect(doc.totals(taxes: try taxes()).total == 250)  // 200 + 40 VAT + 10
    }

    // MARK: Duplicate, receipt, convert

    @Test func duplicateCopiesContentWithNewNumberAndDates() throws {
        let client = Client(name: "Ostara")
        context.insert(client)
        let doc = actions.create(.invoice, business: business, client: client)
        let line = actions.addLineItem(to: doc, defaultTaxID: "uk-vat20")
        line.rate = 100
        line.discount = .percent(10)
        doc.taxMode = .included
        doc.shipping = 5
        doc.notes = "Note"
        actions.markSent(doc)
        actions.recordClientSignature(doc, image: Data([1]), name: "Jonas")

        let copy = actions.duplicate(doc, business: business)
        #expect(copy.number == "INV-0002")
        #expect(copy.status == .draft)
        #expect(copy.sentAt == nil)
        #expect(copy.clientSignatureData == nil)
        #expect(copy.client === client)
        #expect(copy.taxMode == .included)
        #expect(copy.shipping == 5)
        #expect(copy.notes == "Note")
        #expect(copy.sortedItems.count == 1)
        #expect(copy.sortedItems.first?.discount == .percent(10))
        #expect(copy.sortedItems.first !== line)
        #expect(copy.totals(taxes: try taxes()) == doc.totals(taxes: try taxes()))
    }

    @Test func receiptFromPaidInvoice() throws {
        let invoice = actions.create(.invoice, business: business)
        actions.addLineItem(to: invoice, defaultTaxID: "uk-vat20").rate = 50
        let paidDay = calendar.date(byAdding: .day, value: -2, to: today)!
        actions.markPaid(invoice, on: paidDay)
        let receipt = actions.makeReceipt(for: invoice, business: business)
        #expect(receipt.kind == .receipt)
        #expect(receipt.status == .paid)
        #expect(receipt.paidOn == paidDay)
        #expect(receipt.notes.contains(invoice.number))
        #expect(receipt.totals(taxes: try taxes()).total == 60)
    }

    @Test func convertEstimateToInvoice() {
        let estimate = actions.create(.estimate, business: business)
        actions.addLineItem(to: estimate).rate = 1850
        let invoice = actions.convertToInvoice(estimate, business: business)
        #expect(invoice.kind == .invoice)
        #expect(invoice.number == "INV-0001")
        #expect(invoice.fromEstimateNumber == "EST-0001")
        #expect(estimate.status == .converted)
        #expect(estimate.convertedToNumber == "INV-0001")
        #expect(invoice.sortedItems.map(\.rate) == [1850])
    }

    // MARK: Status

    @Test func sentPaidUnpaidAndOverdue() {
        let doc = actions.create(.invoice, business: business)
        doc.dueDate = calendar.date(byAdding: .day, value: -1, to: today)
        #expect(doc.displayStatus(today: today, calendar: calendar) == .draft)
        actions.markSent(doc)
        #expect(doc.sentAt == today)
        #expect(doc.displayStatus(today: today, calendar: calendar) == .overdue)
        actions.markPaid(doc)
        #expect(doc.displayStatus(today: today, calendar: calendar) == .paid)
        actions.markUnpaid(doc)
        #expect(doc.status == .sent)
        #expect(doc.paidOn == nil)
        actions.markSent(doc)  // editing a sent invoice and re-sending keeps the first sent date
        #expect(doc.sentAt == today)
    }

    @Test func clientSignatureAcceptsEstimateButNotInvoiceStatus() {
        let estimate = actions.create(.estimate, business: business)
        actions.recordClientSignature(estimate, image: Data([1, 2]), name: "Priya")
        #expect(estimate.status == .accepted)
        #expect(estimate.signedName == "Priya")
        #expect(estimate.signedAt == today)
        let invoice = actions.create(.invoice, business: business)
        actions.recordClientSignature(invoice, image: Data([1]), name: "Priya")
        #expect(invoice.status == .draft)
        #expect(invoice.clientSignatureData == Data([1]))
    }

    @Test func monthSummaryFromStoredDocuments() throws {
        let a = actions.create(.invoice, business: business)
        actions.addLineItem(to: a).rate = 100
        actions.markSent(a)
        let b = actions.create(.invoice, business: business)
        actions.addLineItem(to: b).rate = 40
        actions.markPaid(b)
        let docs = try context.fetch(FetchDescriptor<Document>())
        let summary = MoneySummary(
            documents: try docs.map { $0.summaryInput(taxes: try taxes()) }, currencyCode: "GBP", today: today,
            calendar: calendar)
        #expect(summary.owed == 100)
        #expect(summary.paidThisMonth == 40)
    }

    // MARK: Delete

    @Test func deletingDocumentDeletesItsLinesButNotTheClient() throws {
        let client = Client(name: "Ostara")
        context.insert(client)
        let doc = actions.create(.invoice, business: business, client: client)
        actions.addLineItem(to: doc)
        actions.addLineItem(to: doc)
        try context.save()
        actions.delete(doc)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Document>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<LineItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 1)
    }

    @Test func deletingClientKeepsItsDocuments() throws {
        let client = Client(name: "Ostara")
        context.insert(client)
        let doc = actions.create(.invoice, business: business, client: client)
        try context.save()
        context.delete(client)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Document>()) == 1)
        #expect(doc.client == nil)
    }

    // MARK: Wrappers

    @Test func enumWrappersFallBackSafely() {
        let doc = Document(kind: .estimate, number: "X")
        doc.kindRaw = "nonsense"
        doc.statusRaw = "nonsense"
        doc.taxModeRaw = "nonsense"
        doc.taxPlacementRaw = "nonsense"
        #expect(doc.kind == .invoice)
        #expect(doc.status == .draft)
        #expect(doc.taxMode == .added)
        #expect(doc.taxPlacement == .perItem)
        business.currencyDisplayRaw = "nonsense"
        #expect(business.currencyDisplay == .symbol)
        business.currencyDisplay = .code
        #expect(business.currencyDisplayRaw == "code")
    }

    @Test func numberingRoundTripsThroughBusiness() {
        var n = business.numbering
        n.prefixes[.invoice] = "KJ-"
        n.next[.invoice] = 42
        business.numbering = n
        #expect(business.invoicePrefix == "KJ-")
        #expect(business.takeNumber(for: .invoice) == "KJ-0042")
        #expect(business.nextInvoiceNumber == 43)
    }

    #if DEBUG
        @Test func demoDataSeeds() throws {
            let container = DemoData.container()  // keep it alive: contexts don't retain their container
            let demo = container.mainContext
            #expect(try demo.fetchCount(FetchDescriptor<Business>()) == 1)
            #expect(try demo.fetchCount(FetchDescriptor<Document>()) == 6)
            #expect(try demo.fetchCount(FetchDescriptor<Client>()) == 3)
        }
    #endif
}

@MainActor
struct FrozenTaxTests {
    let container: ModelContainer
    let context: ModelContext
    let business: Business
    let actions: DocumentActions

    init() throws {
        container = try ModelContainerFactory.makeForTests()
        context = container.mainContext
        business = BusinessSetup.create(name: "K", region: .uk, countryCode: "GB", in: context)
        actions = DocumentActions(context: context)
    }

    private func vat20() throws -> TaxRateRecord {
        try #require(try context.fetch(FetchDescriptor<TaxRateRecord>()).first { $0.taxID == "uk-vat20" })
    }

    @Test func sentInvoiceKeepsItsTaxWhenTheRateIsEdited() throws {
        let sent = actions.create(.invoice, business: business)
        actions.addLineItem(to: sent, defaultTaxID: "uk-vat20").rate = 100
        let draft = actions.create(.invoice, business: business)
        actions.addLineItem(to: draft, defaultTaxID: "uk-vat20").rate = 100
        actions.markSent(sent)
        #expect(sent.frozenTaxes.map(\.id) == ["uk-vat20"])

        try vat20().rate = 17.5
        let taxes = try BusinessSetup.taxes(in: context)
        #expect(sent.totals(taxes: taxes).total == 120)  // frozen at 20%
        #expect(draft.totals(taxes: taxes).total == Decimal(string: "117.5")!)  // drafts follow the edit
    }

    @Test func archivedTaxStillCountsButIsHiddenFromPickers() throws {
        let draft = actions.create(.invoice, business: business)
        actions.addLineItem(to: draft, defaultTaxID: "uk-vat20").rate = 100
        try vat20().isArchived = true
        #expect(try BusinessSetup.taxes(in: context, includingArchived: false).map(\.id) == ["uk-vat5", "uk-vat0"])
        #expect(draft.totals(taxes: try BusinessSetup.taxes(in: context)).total == 120)
    }

    @Test func restorePresetsArchivesCustomTaxes() throws {
        context.insert(TaxRateRecord(taxID: "custom", name: "Eco levy", rate: 2, sortIndex: 9))
        try vat20().rate = 99
        try BusinessSetup.restorePresets(for: .uk, business: business, in: context)
        #expect(try BusinessSetup.taxes(in: context, includingArchived: false).map(\.label) == ["VAT 20%", "VAT 5%", "VAT 0%"])
        #expect(try BusinessSetup.taxes(in: context).count == 4)
    }

    @Test func duplicateDoesNotCarryFrozenTaxes() {
        let sent = actions.create(.invoice, business: business)
        actions.addLineItem(to: sent, defaultTaxID: "uk-vat20")
        actions.markSent(sent)
        #expect(actions.duplicate(sent, business: business).frozenTaxes.isEmpty)
    }
}
