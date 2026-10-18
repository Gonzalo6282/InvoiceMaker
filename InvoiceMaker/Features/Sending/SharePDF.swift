import InvoiceKit
import LinkPresentation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A rendered PDF written to a temporary file named like "INV-0012 Marlow & Finch.pdf".
struct SharedPDF: Identifiable {
    let id = UUID()
    let url: URL
    let data: Data

    @MainActor
    static func make(document: Document, business: Business, taxes: [TaxRate]) throws -> SharedPDF {
        let model = InvoicePDFModelBuilder().build(document: document, business: business, taxes: taxes)
        let data = PDFRenderer(model: model).render()
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        var name = document.number.components(separatedBy: illegal).joined(separator: "-")
        if let client = document.client?.name, !client.isEmpty { name += " " + client.components(separatedBy: illegal).joined(separator: "-") }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Share", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent((name.isEmpty ? "Document" : name) + ".pdf")
        try data.write(to: url, options: .atomic)
        return SharedPDF(url: url, data: data)
    }
}

/// The PDF as a share-sheet item. The header line shows the offline note
/// when there's no connection (spec U10).
final class PDFActivityItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String

    init(url: URL, title: String) {
        self.url = url
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { url }
    func activityViewController(_ controller: UIActivityViewController, itemForActivityType type: UIActivity.ActivityType?) -> Any? { url }
    func activityViewController(_ controller: UIActivityViewController, subjectForActivityType type: UIActivity.ActivityType?) -> String {
        url.deletingPathExtension().lastPathComponent
    }
    func activityViewController(_ controller: UIActivityViewController, dataTypeIdentifierForActivityType type: UIActivity.ActivityType?) -> String {
        UTType.pdf.identifier
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.originalURL = url
        metadata.url = url
        metadata.iconProvider = NSItemProvider(contentsOf: url)
        return metadata
    }
}

/// A PDF for `.fileExporter` ("Save PDF to Files").
struct PDFFile: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum PrintPDF {
    @MainActor
    static func print(_ data: Data, jobName: String, completion: @escaping (Bool) -> Void) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo.printInfo()
        info.outputType = .general
        info.jobName = jobName
        controller.printInfo = info
        controller.printingItem = data
        controller.present(animated: true) { _, completed, _ in completion(completed) }
    }
}
