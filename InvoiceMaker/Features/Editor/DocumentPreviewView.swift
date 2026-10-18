import InvoiceKit
import PDFKit
import SwiftData
import SwiftUI

/// Full PDF preview with the template strip and colour swatches (mockup scrPreview).
/// Without Premium the preview carries a "PREVIEW" watermark (removed when sent with Premium).
struct DocumentPreviewView: View {
    @Bindable var document: Document
    let business: Business
    @State private var purchases = PurchaseManager.shared
    private var isPremium: Bool { purchases.isPremium }

    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]
    @State private var thumbnails: [InvoiceTemplate: UIImage] = [:]

    private var taxes: [TaxRate] { taxRecords.map(\.taxRate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PDFPreview(data: pdfData())
                    .aspectRatio(business.paperAspect, contentMode: .fit)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: Color(red: 6 / 255, green: 27 / 255, blue: 49 / 255).opacity(0.1), radius: 14, y: 8)
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
                    .accessibilityLabel(Text("PDF preview of \(document.number)"))
                if !isPremium {
                    Text("The \"Preview\" mark is removed when you send with Premium.")
                        .font(.caption)
                        .foregroundStyle(Color.ink2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }
                sectionHeader("Template")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(InvoiceTemplate.allCases) { template in templateButton(template) }
                    }
                    .padding(.horizontal, 16)
                }
                sectionHeader("Colour")
                HStack(spacing: 12) {
                    ForEach(BrandColors.choices, id: \.self) { hex in
                        Button {
                            document.brandColorHex = hex
                            document.updatedAt = .now
                            thumbnails = [:]
                        } label: {
                            Circle()
                                .fill(Color(uiColor: UIColor(hex: hex) ?? .systemIndigo))
                                .frame(width: 34, height: 34)
                                .overlay(Circle().strokeBorder(Color.surface, lineWidth: document.brandColorHex == hex ? 3 : 0))
                                .overlay(Circle().strokeBorder(Color.ink, lineWidth: document.brandColorHex == hex ? 1.5 : 0).padding(-3))
                        }
                        .accessibilityLabel(Text("Colour \(hex)"))
                        .accessibilityAddTraits(document.brandColorHex == hex ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: document.brandColorHex) { renderThumbnails() }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.ink2)
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 7)
    }

    private func templateButton(_ template: InvoiceTemplate) -> some View {
        let selected = InvoiceTemplate(id: document.templateID) == template
        return Button {
            let choose = {
                document.templateID = template.rawValue
                document.updatedAt = .now
            }
            if template.isPremium {
                PaywallService.shared.gate(.templatePremium, feature: choose)
            } else {
                choose()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let image = thumbnails[template] {
                            Image(uiImage: image).resizable().scaledToFit()
                        } else {
                            Color.white
                        }
                    }
                    .frame(width: 96, height: 96 / business.paperAspect)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(selected ? Color.brand : Color.line, lineWidth: selected ? 2 : 1))
                    if template.isPremium, !isPremium {
                        Text("PRO")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.navy, in: Capsule())
                            .padding(4)
                    }
                }
                Text(template.displayName)
                    .font(.footnote.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.brand : Color.ink2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func pdfData() -> Data {
        let model = InvoicePDFModelBuilder(watermark: !isPremium)
            .build(document: document, business: business, taxes: taxes)
        return PDFRenderer(model: model).render()
    }

    private func renderThumbnails() {
        var result: [InvoiceTemplate: UIImage] = [:]
        for template in InvoiceTemplate.allCases {
            let model = InvoicePDFModelBuilder(templateOverride: template)
                .build(document: document, business: business, taxes: taxes)
            result[template] = PDFRenderer(model: model).renderFirstPageImage(width: 192)
        }
        thumbnails = result
    }
}

extension Business {
    /// Width ÷ height of this business's paper (A4 or US Letter).
    var paperAspect: CGFloat {
        let size = PaperSize.for(countryCode: countryCode).points
        return size.width / size.height
    }
}

/// PDFKit view showing every page, scaled to fit the width.
struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .white
        view.pageShadowsEnabled = false
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard context.coordinator.lastData != data else { return }
        context.coordinator.lastData = data
        view.document = PDFDocument(data: data)
        view.autoScales = true
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastData: Data?
    }
}
