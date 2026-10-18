import Foundation
import InvoiceKit
import SwiftData

/// Everything that creates or changes documents, so the rules live in one
/// place and are covered by integration tests. Views call these.
@MainActor
struct DocumentActions {
    let context: ModelContext
    var calendar: Calendar = .current
    var now: () -> Date = { .now }

    /// A new draft with the next number, the client's currency and the business defaults.
    @discardableResult
    func create(_ kind: DocumentKind, business: Business, client: Client? = nil) -> Document {
        let today = now()
        let doc = Document(kind: kind, number: business.takeNumber(for: kind), issueDate: today)
        doc.client = client
        doc.currencyCode = client?.currencyCode ?? business.currencyCode
        doc.dueDate = kind == .receipt ? nil : calendar.date(byAdding: .day, value: business.dueDays, to: today)
        doc.templateID = business.templateID
        doc.brandColorHex = business.brandColorHex
        doc.notes = business.defaultNotes
        if kind == .receipt {
            doc.status = .paid
            doc.paidOn = today
        }
        context.insert(doc)
        return doc
    }

    /// Same content, new number, back to draft with today's dates. Signatures are not copied.
    @discardableResult
    func duplicate(_ source: Document, business: Business) -> Document {
        let copy = create(source.kind, business: business, client: source.client)
        copyContent(from: source, to: copy)
        copy.notes = source.notes
        return copy
    }

    /// A paid receipt for a paid invoice.
    @discardableResult
    func makeReceipt(for invoice: Document, business: Business) -> Document {
        let receipt = create(.receipt, business: business, client: invoice.client)
        copyContent(from: invoice, to: receipt)
        receipt.currencyCode = invoice.currencyCode
        receipt.paidOn = invoice.paidOn ?? now()
        receipt.notes = String(localized: "Payment received for \(invoice.number). Thank you.")
        return receipt
    }

    /// One tap: estimate → invoice. The estimate is kept and marked "Invoiced".
    @discardableResult
    func convertToInvoice(_ estimate: Document, business: Business) -> Document {
        let invoice = create(.invoice, business: business, client: estimate.client)
        copyContent(from: estimate, to: invoice)
        invoice.currencyCode = estimate.currencyCode
        invoice.fromEstimateNumber = estimate.number
        estimate.status = .converted
        estimate.convertedToNumber = invoice.number
        touch(estimate)
        return invoice
    }

    func markPaid(_ doc: Document, on date: Date? = nil) {
        doc.status = .paid
        doc.paidOn = date ?? now()
        touch(doc)
    }

    func markUnpaid(_ doc: Document) {
        doc.status = doc.sentAt == nil ? .draft : .sent
        doc.paidOn = nil
        touch(doc)
    }

    func markSent(_ doc: Document) {
        if doc.status == .draft { doc.status = .sent }
        doc.sentAt = doc.sentAt ?? now()
        touch(doc)
    }

    /// The client signed on this device. An estimate is then accepted.
    func recordClientSignature(_ doc: Document, image: Data, name: String) {
        doc.clientSignatureData = image
        doc.signedName = name
        doc.signedAt = now()
        if doc.kind == .estimate, doc.status == .draft || doc.status == .sent { doc.status = .accepted }
        touch(doc)
    }

    @discardableResult
    func addLineItem(to doc: Document, from saved: SavedItem? = nil, defaultTaxID: String? = nil) -> LineItem {
        let position = (doc.items ?? []).map(\.position).max().map { $0 + 1 } ?? 0
        let item = LineItem(position: position)
        if let saved {
            item.itemDescription = saved.itemDescription
            item.unit = saved.unit
            item.rate = saved.rate
            item.taxIDs = saved.taxID.map { [$0] } ?? []
        } else if let defaultTaxID {
            item.taxIDs = [defaultTaxID]
        }
        context.insert(item)
        item.document = doc
        touch(doc)
        return item
    }

    func deleteLineItem(_ item: LineItem) {
        let doc = item.document
        item.document = nil
        context.delete(item)
        if let doc {
            for (index, remaining) in doc.sortedItems.enumerated() { remaining.position = index }
            touch(doc)
        }
    }

    func moveLineItems(in doc: Document, from source: IndexSet, to destination: Int) {
        var ordered = doc.sortedItems
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() { item.position = index }
        touch(doc)
    }

    func delete(_ doc: Document) {
        context.delete(doc)
    }

    func touch(_ doc: Document) {
        doc.updatedAt = now()
    }

    private func copyContent(from source: Document, to target: Document) {
        for item in source.sortedItems {
            let copy = LineItem(
                position: item.position, itemDescription: item.itemDescription, quantity: item.quantity,
                rate: item.rate, taxIDs: item.taxIDs)
            copy.unit = item.unit
            copy.discount = item.discount
            context.insert(copy)
            copy.document = target
        }
        target.taxMode = source.taxMode
        target.taxPlacement = source.taxPlacement
        target.totalTaxIDs = source.totalTaxIDs
        target.discount = source.discount
        target.shipping = source.shipping
        target.fees = source.fees
        target.job = source.job
        target.templateID = source.templateID
        target.brandColorHex = source.brandColorHex
    }
}
