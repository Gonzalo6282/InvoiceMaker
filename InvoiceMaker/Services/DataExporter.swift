import Foundation
import InvoiceKit
import SwiftData

/// "Export everything": every document as a PDF plus all data as CSV, zipped.
/// Free for everyone, so data is never locked in (spec U13).
@MainActor
struct DataExporter {
    let context: ModelContext
    let business: Business
    var calendar: Calendar = .current
    var now: Date = .now

    enum ExportError: Error { case zipFailed }

    /// Builds the export folder and returns the ZIP file's URL.
    func makeZip(in baseDirectory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let folder = try makeFolder(in: baseDirectory)
        let zip = baseDirectory.appendingPathComponent(folder.lastPathComponent + ".zip")
        try? FileManager.default.removeItem(at: zip)
        try ZipFolder.zip(folder, to: zip)
        try? FileManager.default.removeItem(at: folder)
        return zip
    }

    /// The folder: PDFs/<number>.pdf, documents.csv, line-items.csv, clients.csv.
    func makeFolder(in baseDirectory: URL) throws -> URL {
        let name = "Duly export \(CSVWriter.date(now, calendar: calendar))"
        let folder = baseDirectory.appendingPathComponent(name, isDirectory: true)
        let fm = FileManager.default
        try? fm.removeItem(at: folder)
        let pdfs = folder.appendingPathComponent("PDFs", isDirectory: true)
        try fm.createDirectory(at: pdfs, withIntermediateDirectories: true)

        let taxes = try BusinessSetup.taxes(in: context)
        let documents = try context.fetch(FetchDescriptor<Document>(sortBy: [SortDescriptor(\.createdAt)]))
        var usedNames = Set<String>()
        for doc in documents {
            let model = InvoicePDFModelBuilder(today: now, calendar: calendar).build(document: doc, business: business, taxes: taxes)
            let file = uniqueFileName(for: doc, used: &usedNames)
            try PDFRenderer(model: model).render().write(to: pdfs.appendingPathComponent(file))
        }
        try documentsCSV(documents, taxes: taxes).write(to: folder.appendingPathComponent("documents.csv"), atomically: true, encoding: .utf8)
        try lineItemsCSV(documents).write(to: folder.appendingPathComponent("line-items.csv"), atomically: true, encoding: .utf8)
        let clients = try context.fetch(FetchDescriptor<Client>(sortBy: [SortDescriptor(\.name)]))
        try clientsCSV(clients).write(to: folder.appendingPathComponent("clients.csv"), atomically: true, encoding: .utf8)
        return folder
    }

    func documentsCSV(_ documents: [Document], taxes: [TaxRate]) -> String {
        let rows = documents.map { doc -> [String] in
            let t = doc.totals(taxes: taxes)
            return [
                doc.kind.rawValue, doc.number, doc.displayStatus(today: now, calendar: calendar).rawValue,
                doc.client?.name ?? "", CSVWriter.date(doc.issueDate, calendar: calendar),
                CSVWriter.date(doc.dueDate, calendar: calendar), CSVWriter.date(doc.paidOn, calendar: calendar),
                doc.currencyCode, CSVWriter.amount(t.subtotal), CSVWriter.amount(t.discount), CSVWriter.amount(t.taxTotal),
                CSVWriter.amount(t.shipping), CSVWriter.amount(t.fees), CSVWriter.amount(t.total),
                doc.taxMode.rawValue, doc.job, doc.notes,
            ]
        }
        return CSVWriter.string(
            header: ["Type", "Number", "Status", "Client", "Issued", "Due", "Paid on", "Currency", "Subtotal", "Discount",
                     "Tax", "Shipping", "Fees", "Total", "Tax mode", "Job", "Notes"],
            rows: rows)
    }

    func lineItemsCSV(_ documents: [Document]) -> String {
        let rows = documents.flatMap { doc in
            doc.sortedItems.map { line -> [String] in
                let input = LineItemInput(quantity: line.quantity, rate: line.rate, discount: line.discount)
                let discount: String =
                    switch line.discount {
                    case .percent(let v): v == 0 ? "" : "\(v)%"
                    case .amount(let v): CSVWriter.amount(v)
                    }
                return [
                    doc.number, String(line.position + 1), line.itemDescription, "\(line.quantity)", line.unit,
                    CSVWriter.amount(line.rate), discount, line.taxIDs.joined(separator: " "), CSVWriter.amount(input.net),
                ]
            }
        }
        return CSVWriter.string(
            header: ["Document", "Line", "Description", "Quantity", "Unit", "Rate", "Discount", "Taxes", "Amount"], rows: rows)
    }

    func clientsCSV(_ clients: [Client]) -> String {
        CSVWriter.string(
            header: ["Name", "Contact", "Email", "Phone", "Address", "Tax ID", "Currency"],
            rows: clients.map { [$0.name, $0.contactName, $0.email, $0.phone, $0.address, $0.taxID, $0.currencyCode] })
    }

    private func uniqueFileName(for doc: Document, used: inout Set<String>) -> String {
        let safe = doc.number.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
        var base = safe.isEmpty ? doc.kind.rawValue : safe
        if let client = doc.client?.name, !client.isEmpty {
            base += " " + client.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
        }
        var name = base + ".pdf"
        var n = 2
        while used.contains(name) {
            name = "\(base) (\(n)).pdf"
            n += 1
        }
        used.insert(name)
        return name
    }
}

/// Zips a folder with the system (no third-party dependency).
enum ZipFolder {
    nonisolated static func zip(_ folder: URL, to destination: URL) throws {
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: [.forUploading], error: &coordinatorError) { zipped in
            do { try FileManager.default.copyItem(at: zipped, to: destination) } catch { copyError = error }
        }
        if let error = coordinatorError ?? copyError { throw error }
    }
}
