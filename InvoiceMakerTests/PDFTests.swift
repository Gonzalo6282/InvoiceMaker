import Foundation
import InvoiceKit
import SwiftData
import Testing
import UIKit

@testable import InvoiceMaker

@MainActor
struct PDFModelBuilderTests {
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
        business.address = "Unit 4, Mill Yard\nBristol BS3 4AQ"
        business.taxRegistered = true
        business.taxID = "GB 284 1937 62"
        actions = DocumentActions(context: context, calendar: cal, now: { now })
    }

    func build(_ doc: Document, watermark: Bool = false) throws -> InvoicePDFModel {
        InvoicePDFModelBuilder(watermark: watermark, today: today, calendar: calendar)
            .build(document: doc, business: business, taxes: try BusinessSetup.taxes(in: context))
    }

    func mockupInvoice() -> Document {
        let client = Client(name: "Marlow & Finch Architects")
        client.address = "22 Queen Square\nBristol BS1 4ND"
        context.insert(client)
        let doc = actions.create(.invoice, business: business, client: client)
        let a = actions.addLineItem(to: doc, defaultTaxID: "uk-vat20")
        a.itemDescription = "Bespoke shelving"
        a.quantity = 2
        a.rate = 87.5
        a.unit = "unit"
        let b = actions.addLineItem(to: doc, defaultTaxID: "uk-vat20")
        b.itemDescription = "Site visit"
        b.rate = 52.5
        return doc
    }

    @Test func jobPhotosGoOnAPageAfterTheInvoice() throws {
        let doc = mockupInvoice()
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        let png = try #require(big.pngData())
        let jpeg = try #require(JobPhotoImage.prepare(png))
        let resized = try #require(UIImage(data: jpeg))
        #expect(max(resized.size.width, resized.size.height) == 1600)
        for position in 0..<7 {
            let photo = JobPhoto(position: position, imageData: jpeg)
            context.insert(photo)
            photo.document = doc
        }
        let m = try build(doc)
        #expect(m.photos.count == 7)
        #expect(PDFPageImage.pageCount(of: PDFRenderer(model: m).render()) == 3)  // invoice, 6 photos, 1 photo
        #expect(PDFPageImage.pageCount(of: PDFRenderer(model: try build(mockupInvoice())).render()) == 1)
    }

    @Test func madeWithDulyIsOnByDefaultAndCanBeTurnedOff() throws {
        let defaults = try #require(UserDefaults(suiteName: "madewith-\(UUID().uuidString)"))
        #expect(MadeWithDuly.isOn(defaults))
        defaults.set(false, forKey: MadeWithDuly.key)
        #expect(!MadeWithDuly.isOn(defaults))
        let doc = mockupInvoice()
        let on = InvoicePDFModelBuilder(showsMadeWith: true, today: today, calendar: calendar)
            .build(document: doc, business: business, taxes: try BusinessSetup.taxes(in: context))
        #expect(on.madeWith == "Made with Duly")
        let off = InvoicePDFModelBuilder(showsMadeWith: false, today: today, calendar: calendar)
            .build(document: doc, business: business, taxes: try BusinessSetup.taxes(in: context))
        #expect(off.madeWith == nil)
        // The line sits in the bottom margin: it never adds a page, on any template or paper size.
        for template in InvoiceTemplate.allCases {
            var model = on
            model.template = template
            #expect(PDFPageImage.pageCount(of: PDFRenderer(model: model).render()) == 1, "\(template)")
            model.paper = .letter
            #expect(PDFPageImage.pageCount(of: PDFRenderer(model: model).render()) == 1, "\(template) letter")
        }
    }

    @Test func invoiceContent() throws {
        let m = try build(mockupInvoice())
        #expect(m.title == "Invoice")
        #expect(m.number == "INV-0001")
        #expect(m.paper == .a4)
        #expect(m.initials == "KJ")
        #expect(m.from.lines == ["Unit 4, Mill Yard", "Bristol BS3 4AQ", "VAT number GB 284 1937 62"])
        #expect(m.to.label == "Bill to")
        #expect(m.to.name == "Marlow & Finch Architects")
        #expect(m.dates.map(\.label) == ["Issued", "Due"])
        #expect(m.dates.first?.value == "18 Oct 2026")
        #expect(m.showsTaxColumn)
        #expect(m.rows.map(\.amount) == ["£175.00", "£52.50"])
        #expect(m.rows.first?.quantity == "2 unit")
        #expect(m.rows.first?.tax == "20%")
        #expect(m.summary.map(\.label) == ["Subtotal", "VAT 20%"])
        #expect(m.summary.map(\.value) == ["£227.50", "£45.50"])
        #expect(m.totalLabel == "Total due")
        #expect(m.totalValue == "£273.00")
        #expect(!m.showsPayment)  // no payment details yet: no empty "How to pay"
        business.payment?.accountNumber = "31926819"
        #expect(try build(mockupInvoice()).showsPayment)
        #expect(!m.paidStamp)
        #expect(!m.watermark)
    }

    @Test func includedTaxDiscountShippingAndFees() throws {
        let doc = mockupInvoice()
        doc.taxMode = .included
        doc.discount = .percent(10)
        doc.shipping = 5
        doc.fees = [Fee(name: "", amount: 2), Fee(name: "Zero", amount: 0)]
        doc.sortedItems[0].discount = .amount(5)
        let m = try build(doc)
        #expect(m.summary.map(\.label) == ["Subtotal (incl. tax)", "Discount", "Includes VAT 20%", "Shipping", "Fee"])
        #expect(m.summary[1].value.hasPrefix("−"))
        #expect(m.rows.first?.discountNote == "Discount £5.00")
    }

    @Test func taxOnTotalHidesTaxColumn() throws {
        let doc = mockupInvoice()
        doc.taxPlacement = .onTotal
        doc.totalTaxIDs = ["uk-vat20"]
        let m = try build(doc)
        #expect(!m.showsTaxColumn)
        #expect(m.rows.allSatisfy { $0.tax == nil })
    }

    @Test func ukEstimateIsAQuoteWithSignatureLine() throws {
        let doc = actions.create(.estimate, business: business)
        let m = try build(doc)
        #expect(m.title == "Quote")
        #expect(m.to.label == "For")
        #expect(m.to.name == "Client name")
        #expect(m.dates.map(\.label) == ["Issued", "Valid until"])
        #expect(m.totalLabel == "Quote total")
        #expect(!m.showsPayment)
        #expect(m.signatures.count == 1)
        #expect(m.signatures.first?.blankLine == true)
        #expect(m.rows.isEmpty)

        actions.recordClientSignature(doc, image: Data([1]), name: "Priya Marlow")
        let signed = try build(doc)
        #expect(signed.signatures.first?.blankLine == false)
        #expect(signed.signatures.first?.caption == "Priya Marlow · 18 Oct 2026")
    }

    @Test func receiptAndPaidInvoiceGetTheStamp() throws {
        let receipt = actions.create(.receipt, business: business)
        let r = try build(receipt)
        #expect(r.paidStamp)
        #expect(r.totalLabel == "Paid")
        #expect(r.dates.map(\.label) == ["Paid on"])
        #expect(r.signatures.isEmpty)
        let invoice = mockupInvoice()
        actions.markPaid(invoice)
        #expect(try build(invoice).paidStamp)
    }

    @Test func australianTaxInvoiceOnLetterForUS() throws {
        business.countryCode = "AU"
        #expect(try build(mockupInvoice()).title == "Tax invoice")
        business.countryCode = "US"
        let m = try build(mockupInvoice())
        #expect(m.paper == .letter)
        #expect(m.title == "Invoice")
    }

    @Test func paymentDetails() throws {
        let p = try #require(business.payment)
        p.bankName = "Kestrel Joinery Ltd"
        p.sortCode = "04-00-04"
        p.accountNumber = "31926819"
        p.payPalMe = "paypal.me/kestreljoinery"
        p.venmo = "@kestrel"
        p.cashApp = "$kestrel"
        p.zelle = "hello@kestrel.co.uk"
        p.paymentLink = "buy.stripe.com/abc"
        let m = try build(mockupInvoice())
        #expect(m.bankLine == "Bank transfer · Kestrel Joinery Ltd · Sort code 04-00-04 · Account 31926819")
        #expect(m.payButtons.map(\.label) == ["Pay online", "PayPal", "Venmo", "Cash App", "Zelle hello@kestrel.co.uk"])
        #expect(m.payButtons.map(\.url?.absoluteString) == [
            "https://buy.stripe.com/abc", "https://paypal.me/kestreljoinery", "https://venmo.com/u/kestrel",
            "https://cash.app/$kestrel", nil,
        ])
        #expect(m.qrPayload == "https://buy.stripe.com/abc")
        p.showsQRCode = false
        #expect(try build(mockupInvoice()).qrPayload == nil)
    }

    @Test func currencyDisplayFollowsSetting() throws {
        business.currencyDisplay = .none
        #expect(try build(mockupInvoice()).totalValue == "273.00")
    }

    @Test func templateFromDocumentAndWatermark() throws {
        let doc = mockupInvoice()
        doc.templateID = "studio"
        let m = try build(doc, watermark: true)
        #expect(m.template == .studio)
        #expect(m.watermark)
        doc.templateID = "unknown"
        #expect(try build(doc).template == .clean)
    }
}

struct PaymentLinksTests {
    @Test func links() {
        #expect(PaymentLinks.web("") == nil)
        #expect(PaymentLinks.web("not a link") == nil)
        #expect(PaymentLinks.web("https://square.link/u/x")?.absoluteString == "https://square.link/u/x")
        #expect(PaymentLinks.payPal("kestrel")?.absoluteString == "https://paypal.me/kestrel")
        #expect(PaymentLinks.payPal("https://www.paypal.me/kestrel")?.absoluteString == "https://www.paypal.me/kestrel")
        #expect(PaymentLinks.venmo("bad handle!") == nil)
        #expect(PaymentLinks.cashApp("") == nil)
    }
}

@MainActor
struct PDFRenderTests {
    @Test(arguments: InvoiceTemplate.allCases)
    func everyTemplateRendersOnePage(template: InvoiceTemplate) throws {
        let container = DemoData.container()
        let context = container.mainContext
        let business = try #require(try BusinessSetup.current(in: context))
        let docs = try context.fetch(FetchDescriptor<Document>(sortBy: [SortDescriptor(\.number)]))
        let doc = try #require(docs.first { $0.kind == .invoice && !($0.items ?? []).isEmpty })
        let model = InvoicePDFModelBuilder(templateOverride: template)
            .build(document: doc, business: business, taxes: try BusinessSetup.taxes(in: context))
        let data = PDFRenderer(model: model).render()
        #expect(data.count > 2_000)
        #expect(PDFPageImage.pageCount(of: data) == 1)
        let image = try #require(PDFRenderer(model: model).renderFirstPageImage(width: 600))
        #expect(image.size.width == 600)
        SnapshotExport.write(image, name: "\(template.rawValue)-invoice")
    }

    @Test func receiptAndQuoteSnapshots() throws {
        let container = DemoData.container()
        let context = container.mainContext
        let business = try #require(try BusinessSetup.current(in: context))
        let taxes = try BusinessSetup.taxes(in: context)
        let docs = try context.fetch(FetchDescriptor<Document>())
        let actions = DocumentActions(context: context)
        let paid = try #require(docs.first { $0.status == .paid })
        let receipt = actions.makeReceipt(for: paid, business: business)
        let r = InvoicePDFModelBuilder(templateOverride: .classic).build(document: receipt, business: business, taxes: taxes)
        #expect(r.paidStamp)
        SnapshotExport.write(try #require(PDFRenderer(model: r).renderFirstPageImage(width: 600)), name: "classic-receipt")

        let quote = try #require(docs.first { $0.kind == .estimate })
        quote.job = "Ostara Café, 8 Gloucester Road — bar refit"
        quote.discount = .percent(10)
        let q = InvoicePDFModelBuilder(templateOverride: .trades, watermark: true).build(document: quote, business: business, taxes: taxes)
        SnapshotExport.write(try #require(PDFRenderer(model: q).renderFirstPageImage(width: 600)), name: "trades-quote-watermark")
    }

    @Test func longInvoiceFlowsOntoMorePages() throws {
        let container = try ModelContainerFactory.makeForTests()
        let context = container.mainContext
        let business = BusinessSetup.create(name: "Kestrel Joinery", region: .uk, countryCode: "GB", in: context)
        let actions = DocumentActions(context: context)
        let doc = actions.create(.invoice, business: business)
        for i in 1...80 {
            let item = actions.addLineItem(to: doc, defaultTaxID: "uk-vat20")
            item.itemDescription = "Line \(i): oak skirting board, supplied and fitted"
            item.rate = Decimal(i)
        }
        for template in InvoiceTemplate.allCases {
            let model = InvoicePDFModelBuilder(templateOverride: template)
                .build(document: doc, business: business, taxes: try BusinessSetup.taxes(in: context))
            #expect(PDFPageImage.pageCount(of: PDFRenderer(model: model).render()) >= 3, "\(template)")
        }
    }

    @Test func logoIsFittedAndHEICWorks() throws {
        let container = try ModelContainerFactory.makeForTests()
        let context = container.mainContext
        let business = BusinessSetup.create(name: "Wide Logo Co", region: .us, countryCode: "US", in: context)
        let wide = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 100)).image { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 100))
        }
        business.logoData = wide.heicData() ?? wide.pngData()
        let doc = DocumentActions(context: context).create(.invoice, business: business)
        let model = InvoicePDFModelBuilder().build(document: doc, business: business, taxes: [])
        #expect(model.paper == .letter)
        let image = try #require(PDFRenderer(model: model).renderFirstPageImage(width: 612))
        #expect(image.size.height == 792)
        SnapshotExport.write(image, name: "logo-wide-letter")
    }
}

/// Writes snapshot PNGs when CI sets SNAPSHOT_DIR, so they can be reviewed.
enum SnapshotExport {
    static func write(_ image: UIImage, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !dir.isEmpty,
            let data = image.pngData()
        else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }
}

@MainActor
struct ExportTests {
    @Test func zipContainsPDFsAndCSVs() throws {
        let container = DemoData.container()
        let context = container.mainContext
        let business = try #require(try BusinessSetup.current(in: context))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let exporter = DataExporter(context: context, business: business)
        let folder = try exporter.makeFolder(in: dir)
        let pdfs = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("PDFs").path)
        #expect(pdfs.count == 6)
        #expect(pdfs.allSatisfy { $0.hasSuffix(".pdf") })
        let documents = try String(contentsOf: folder.appendingPathComponent("documents.csv"), encoding: .utf8)
        #expect(documents.hasPrefix("Type,Number,Status,Client"))
        #expect(documents.contains("INV-0007,sent,Marlow & Finch Architects"))
        #expect(documents.contains(",273.00,"))
        let clients = try String(contentsOf: folder.appendingPathComponent("clients.csv"), encoding: .utf8)
        #expect(clients.contains("Lund Design Studio"))
        let lines = try String(contentsOf: folder.appendingPathComponent("line-items.csv"), encoding: .utf8)
        #expect(lines.contains("INV-0007,1,\"Bespoke shelving, installed\",2,,87.50"))

        let zip = try exporter.makeZip(in: dir)
        let size = try #require(try FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int)
        #expect(zip.pathExtension == "zip")
        #expect(size > 5_000)
    }
}
