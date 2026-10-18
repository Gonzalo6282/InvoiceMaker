import InvoiceKit
import SwiftUI

/// The live PDF beside the editor on iPad (watermarked without Premium).
struct LivePDFPanel: View {
    let document: Document
    let business: Business
    let taxes: [TaxRate]
    @State private var purchases = PurchaseManager.shared

    var body: some View {
        VStack(spacing: 10) {
            PDFPreview(data: pdfData)
                .aspectRatio(business.paperAspect, contentMode: .fit)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.1), radius: 14, y: 8)
                .frame(maxWidth: 560)
            Text(purchases.isPremium ? "Live PDF preview" : "Live PDF preview. The \"Preview\" mark disappears with Premium.")
                .font(.system(size: 12.5)).foregroundStyle(Color.ink3)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("PDF preview"))
    }

    private var pdfData: Data {
        let model = InvoicePDFModelBuilder(watermark: !purchases.isPremium)
            .build(document: document, business: business, taxes: taxes)
        return PDFRenderer(model: model).render()
    }
}
