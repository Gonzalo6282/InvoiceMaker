import CoreImage.CIFilterBuiltins
import CoreText
import UIKit

/// Draws an `InvoicePDFModel` as a PDF. Sizes follow the mockup's `.paper`
/// CSS, where 1 unit = 1% of the page width. Long item lists flow onto more
/// pages; the table header repeats and the totals block stays together.
@MainActor
struct PDFRenderer {
    let model: InvoicePDFModel

    func render() -> Data {
        let size = model.paper.points
        let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(model.title) \(model.number)",
            kCGPDFContextCreator as String: "Duly",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        return renderer.pdfData { context in
            var layout = PageLayout(model: model, bounds: bounds, context: context)
            layout.drawDocument()
        }
    }

    /// Renders page 1 as an image (template picker thumbnails, snapshot tests).
    func renderFirstPageImage(width: CGFloat) -> UIImage? {
        guard let page = PDFPageImage.firstPage(of: render(), width: width) else { return nil }
        return page
    }
}

// MARK: - Layout

@MainActor
private struct PageLayout {
    let model: InvoicePDFModel
    let bounds: CGRect
    let context: UIGraphicsPDFRendererContext

    /// 1% of the page width, like the mockup's cqw.
    var u: CGFloat { bounds.width / 100 }
    var accent: UIColor { UIColor(hex: model.accentHex) ?? UIColor(red: 0.33, green: 0.23, blue: 0.99, alpha: 1) }
    var template: InvoiceTemplate { model.template }

    /// Content area (the Split template has a coloured side bar on the left).
    var left: CGFloat { template.header == .sideBar ? 30 * u : 6.5 * u }
    var right: CGFloat { bounds.width - 6.5 * u }
    var width: CGFloat { right - left }
    var bottom: CGFloat { bounds.height - 5 * u }

    var y: CGFloat = 0
    var pageIndex = 0

    init(model: InvoicePDFModel, bounds: CGRect, context: UIGraphicsPDFRendererContext) {
        self.model = model
        self.bounds = bounds
        self.context = context
    }

    // Colours from the mockup paper.
    let ink = UIColor(red: 0x14 / 255, green: 0x20 / 255, blue: 0x2E / 255, alpha: 1)
    let muted = UIColor(red: 0x5B / 255, green: 0x68 / 255, blue: 0x78 / 255, alpha: 1)
    let label = UIColor(red: 0x7A / 255, green: 0x86 / 255, blue: 0x96 / 255, alpha: 1)
    let hairline = UIColor(red: 0xE6 / 255, green: 0xEB / 255, blue: 0xF1 / 255, alpha: 1)
    let grid = UIColor(red: 0xD5 / 255, green: 0xDD / 255, blue: 0xE7 / 255, alpha: 1)
    let stampGreen = UIColor(red: 0x3D / 255, green: 0x8A / 255, blue: 0x1B / 255, alpha: 1)

    // MARK: Fonts (body 2.05u ≈ 12pt on A4, as in the mockup)

    func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size * u, weight: weight)
        guard template.serif, let serif = base.fontDescriptor.withDesign(.serif) else {
            return base.withTabularDigits()
        }
        return UIFont(descriptor: serif, size: size * u).withTabularDigits()
    }

    var body: UIFont { font(2.05) }
    var bodyBold: UIFont { font(2.05, .semibold) }
    var small: UIFont { font(1.65, .semibold) }

    // MARK: Document

    mutating func drawDocument() {
        beginPage()
        drawHeader()
        drawJob()
        drawTable()
        drawSummaryAndFooter()
    }

    mutating func beginPage() {
        context.beginPage()
        pageIndex += 1
        y = 6.5 * u
        if template.header == .sideBar {
            accent.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 24 * u, height: bounds.height))
        }
        if model.watermark { drawWatermark() }
        if pageIndex > 1 {
            draw("\(model.title) \(model.number)", font: small, color: label, x: left, width: width, align: .left)
            y += 3 * u
        }
    }

    // MARK: Header

    mutating func drawHeader() {
        switch template.header {
        case .band: drawBandHeader()
        case .studio: drawStudioHeader()
        case .sideBar: drawSideBarHeader()
        case .standard, .classic: drawStandardHeader()
        }
        drawMeta()
    }

    private mutating func drawStandardHeader() {
        let top = y
        drawLogo(in: CGRect(x: left, y: top, width: 11 * u, height: 11 * u), tile: accent, text: .white)
        let titleFont = template.serif ? font(6, .bold) : font(5.6, .heavy)
        let titleColor = template.accentTitle ? accent : ink
        var ty = top
        ty += drawText(model.title, font: titleFont, color: titleColor, rect: CGRect(x: left, y: ty, width: width, height: 20 * u), align: .right, kern: template.serif ? 0 : -0.03)
        ty += 1 * u
        ty += drawText(model.number, font: body, color: muted, rect: CGRect(x: left, y: ty, width: width, height: 5 * u), align: .right)
        y = max(top + 11 * u, ty)
        if template.header == .classic {
            y += 3 * u
            ink.setFill()
            UIRectFill(CGRect(x: left, y: y, width: width, height: 0.12 * u))
            UIRectFill(CGRect(x: left, y: y + 0.36 * u, width: width, height: 0.12 * u))
            y += 0.5 * u
        }
    }

    private mutating func drawBandHeader() {
        let bandTop: CGFloat = 0
        let titleFont = font(7, .heavy)
        let titleH = measure(model.title, font: titleFont, width: width)
        let numberH = measure(model.number, font: body, width: width)
        let bandH = 6 * u + max(11 * u, titleH + 1 * u + numberH) + 5 * u
        accent.setFill()
        UIRectFill(CGRect(x: 0, y: bandTop, width: bounds.width, height: bandH))
        let contentBottom = bandH - 5 * u
        drawLogo(in: CGRect(x: left, y: contentBottom - 11 * u, width: 11 * u, height: 11 * u), tile: .white, text: accent)
        drawText(model.number, font: body, color: UIColor.white.withAlphaComponent(0.8), rect: CGRect(x: left, y: contentBottom - numberH, width: width, height: numberH), align: .right)
        drawText(model.title, font: titleFont, color: .white, rect: CGRect(x: left, y: contentBottom - numberH - 1 * u - titleH, width: width, height: titleH), align: .right, kern: -0.03)
        y = bandH
    }

    private mutating func drawStudioHeader() {
        y += drawText(model.title, font: font(11, .black), color: ink, rect: CGRect(x: left, y: y, width: width, height: 20 * u), align: .left, kern: -0.06)
        y += 1 * u
        y += drawText(model.number, font: body, color: muted, rect: CGRect(x: left, y: y, width: width, height: 5 * u), align: .left)
        y += 3 * u
        drawLogo(in: CGRect(x: left, y: y, width: 11 * u, height: 11 * u), tile: accent, text: .white)
        y += 11 * u
    }

    private mutating func drawSideBarHeader() {
        // Side bar: logo + From block in white.
        let barX = 4 * u, barW = 16 * u
        drawLogo(in: CGRect(x: barX, y: 6.5 * u, width: 12 * u, height: 12 * u), tile: .white, text: accent)
        drawParty(model.from, x: barX, y: 21.5 * u, width: barW, labelColor: UIColor.white.withAlphaComponent(0.7), textColor: .white)
        // Title on the right.
        y += drawText(model.title, font: font(5.6, .heavy), color: ink, rect: CGRect(x: left, y: y, width: width, height: 20 * u), align: .left, kern: -0.03)
        y += 1 * u
        y += drawText(model.number, font: body, color: muted, rect: CGRect(x: left, y: y, width: width, height: 5 * u), align: .left)
    }

    private mutating func drawMeta() {
        y += 5 * u
        var parties: [InvoicePDFModel.Party] = template.header == .sideBar ? [model.to] : [model.from, model.to]
        if parties.isEmpty { parties = [model.to] }
        let columns = parties.count + 1
        let gap = 3 * u
        let colW = (width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        var maxH: CGFloat = 0
        for (i, party) in parties.enumerated() {
            let h = drawParty(party, x: left + CGFloat(i) * (colW + gap), y: y, width: colW, labelColor: label, textColor: ink)
            maxH = max(maxH, h)
        }
        var dy = y
        let dx = left + CGFloat(columns - 1) * (colW + gap)
        for (i, block) in model.dates.enumerated() {
            if i > 0 { dy += 1.6 * u }
            dy += drawText(block.label, font: small, color: label, rect: CGRect(x: dx, y: dy, width: colW, height: 4 * u)) + 0.6 * u
            dy += drawText(block.value, font: i == 0 ? body : bodyBold, color: ink, rect: CGRect(x: dx, y: dy, width: colW, height: 4 * u))
        }
        y += max(maxH, dy - y)
    }

    @discardableResult
    private func drawParty(_ party: InvoicePDFModel.Party, x: CGFloat, y: CGFloat, width: CGFloat, labelColor: UIColor, textColor: UIColor) -> CGFloat {
        var py = y
        py += drawText(party.label, font: small, color: labelColor, rect: CGRect(x: x, y: py, width: width, height: 4 * u)) + 0.6 * u
        py += drawText(party.name, font: bodyBold, color: textColor, rect: CGRect(x: x, y: py, width: width, height: 12 * u))
        for line in party.lines {
            py += drawText(line, font: body, color: textColor, rect: CGRect(x: x, y: py, width: width, height: 12 * u))
        }
        return py - y
    }

    // MARK: Job

    mutating func drawJob() {
        guard let job = model.job else { return }
        y += 3 * u
        if template.jobBox {
            let textW = width - 3.4 * u
            let h = 2 * u + small.lineHeight + 0.6 * u + measure(job, font: bodyBold, width: textW) + 2 * u
            accent.withAlphaComponent(0.09).setFill()
            UIRectFill(CGRect(x: left, y: y, width: width, height: h))
            accent.setFill()
            UIRectFill(CGRect(x: left, y: y, width: 0.8 * u, height: h))
            var jy = y + 2 * u
            jy += drawText(String(localized: "Job site"), font: small, color: label, rect: CGRect(x: left + 3.4 * u, y: jy, width: textW, height: 4 * u)) + 0.6 * u
            drawText(job, font: bodyBold, color: ink, rect: CGRect(x: left + 3.4 * u, y: jy, width: textW, height: 20 * u))
            y += h
        } else {
            let text = NSMutableAttributedString(string: String(localized: "Job") + " ", attributes: [.font: small, .foregroundColor: label])
            text.append(NSAttributedString(string: job, attributes: [.font: body, .foregroundColor: ink]))
            let h = text.boundingRect(with: CGSize(width: width, height: 1000), options: [.usesLineFragmentOrigin], context: nil).height
            text.draw(with: CGRect(x: left, y: y, width: width, height: h + 1), options: [.usesLineFragmentOrigin], context: nil)
            y += ceil(h)
        }
    }

    // MARK: Table

    private var columnWidths: [CGFloat] {
        // Description takes what's left after the number columns.
        let qty = 12 * u, rate = 15 * u, tax = model.showsTaxColumn ? 10 * u : 0, amount = 16 * u
        return [width - qty - rate - tax - amount, qty, rate, tax, amount]
    }

    mutating func drawTable() {
        y += 5 * u
        drawTableHeader()
        if model.rows.isEmpty {
            y += drawText(model.emptyRowsText, font: body, color: label, rect: CGRect(x: left, y: y + 1.6 * u, width: width, height: 5 * u)) + 3.2 * u
            return
        }
        for row in model.rows {
            let h = rowHeight(row)
            if y + h > bottom {
                beginPage()
                drawTableHeader()
            }
            drawRow(row, height: h)
        }
    }

    private mutating func drawTableHeader() {
        let h = headings
        let titles = [h.description, h.quantity, h.rate, h.tax, h.amount]
        let cellPad = template.gridTable ? 1.6 * u : 0
        let height = small.lineHeight + 2.4 * u
        if template.gridTable {
            accent.withAlphaComponent(0.10).setFill()
            UIRectFill(CGRect(x: left, y: y, width: width, height: height))
        }
        var x = left
        for (i, title) in titles.enumerated() where columnWidths[i] > 0 {
            let w = columnWidths[i]
            drawText(title, font: small, color: template.gridTable ? ink : label, rect: CGRect(x: x + cellPad + (i > 0 ? 2 * u : 0), y: y + 1.2 * u, width: w - 2 * cellPad - (i > 0 ? 2 * u : 0), height: height), align: i == 0 ? .left : .right)
            if template.gridTable { strokeRect(CGRect(x: x, y: y, width: w, height: height)) }
            x += w
        }
        y += height
        if !template.gridTable {
            (template.accentTableRule ? accent : ink).setFill()
            UIRectFill(CGRect(x: left, y: y - 0.25 * u, width: width, height: 0.25 * u))
        }
    }

    private var headings: (description: String, quantity: String, rate: String, tax: String, amount: String) { model.headings }

    private func rowHeight(_ row: InvoicePDFModel.LineRow) -> CGFloat {
        let pad = template.gridTable ? 1.6 * u : 0
        var descH = measure(row.description, font: body, width: columnWidths[0] - 2 * pad)
        if let note = row.discountNote { descH += measure(note, font: body, width: columnWidths[0] - 2 * pad) }
        return descH + (template.gridTable ? 2.6 * u : 3.2 * u)
    }

    private mutating func drawRow(_ row: InvoicePDFModel.LineRow, height: CGFloat) {
        let pad = template.gridTable ? 1.6 * u : 0
        let top = y + (template.gridTable ? 1.3 * u : 1.6 * u)
        let cells = [row.description, row.quantity, row.rate, row.tax ?? "", row.amount]
        var x = left
        for (i, text) in cells.enumerated() where columnWidths[i] > 0 {
            let w = columnWidths[i]
            let inset = pad + (i > 0 ? 2 * u : 0)
            var cy = top
            cy += drawText(text, font: body, color: ink, rect: CGRect(x: x + inset, y: cy, width: w - inset - pad, height: height), align: i == 0 ? .left : .right)
            if i == 0, let note = row.discountNote {
                drawText(note, font: body, color: label, rect: CGRect(x: x + inset, y: cy, width: w - inset - pad, height: height))
            }
            if template.gridTable { strokeRect(CGRect(x: x, y: y, width: w, height: height)) }
            x += w
        }
        if !template.gridTable {
            hairline.setFill()
            UIRectFill(CGRect(x: left, y: y + height - 0.15 * u, width: width, height: 0.15 * u))
        }
        y += height
    }

    // MARK: Summary, payment, signatures

    mutating func drawSummaryAndFooter() {
        let sumW = width * 0.48
        let sumX = right - sumW
        let rowH = body.lineHeight + 1.4 * u
        let totalFont = font(3.1, .heavy)
        let summaryH = 2.5 * u + CGFloat(model.summary.count) * rowH + 2.6 * u + totalFont.lineHeight + 1 * u
        let footerH = footerHeight()
        if y + summaryH + footerH > bottom {
            beginPage()
        }
        y += 2.5 * u
        for row in model.summary {
            drawText(row.label, font: body, color: muted, rect: CGRect(x: sumX, y: y + 0.7 * u, width: sumW * 0.6, height: rowH))
            drawText(row.value, font: body, color: muted, rect: CGRect(x: sumX, y: y + 0.7 * u, width: sumW, height: rowH), align: .right)
            y += rowH
        }
        y += 1 * u
        ink.setFill()
        UIRectFill(CGRect(x: sumX, y: y, width: sumW, height: 0.25 * u))
        y += 1.6 * u
        drawText(model.totalLabel, font: totalFont, color: ink, rect: CGRect(x: sumX, y: y, width: sumW * 0.6, height: totalFont.lineHeight * 2), kern: -0.02)
        drawText(model.totalValue, font: totalFont, color: ink, rect: CGRect(x: sumX, y: y, width: sumW, height: totalFont.lineHeight * 2), align: .right, kern: -0.02)
        y += totalFont.lineHeight

        if model.paidStamp { drawPaidStamp() }
        drawFooter(height: footerH)
    }

    private var qrSize: CGFloat { 14 * u }
    private var signatureHeight: CGFloat { 6 * u }

    private func footerTextWidth() -> CGFloat { model.showsPayment && model.qrPayload != nil ? width - qrSize - 4 * u : width }

    private func footerHeight() -> CGFloat {
        let w = footerTextWidth()
        var h = 3 * u
        if model.showsPayment {
            h += small.lineHeight + 0.6 * u
            if let bank = model.bankLine { h += measure(bank, font: body, width: w) }
            if !model.payButtons.isEmpty { h += 1.4 * u + buttonRowsHeight(width: w) }
        }
        if !model.notes.isEmpty { h += 3 * u + measure(model.notes, font: body, width: w) }
        if !model.signatures.isEmpty { h += 2 * u + small.lineHeight + signatureHeight + body.lineHeight + 1 * u }
        return max(h, model.showsPayment && model.qrPayload != nil ? qrSize + 3 * u : 0)
    }

    private func buttonRowsHeight(width: CGFloat) -> CGFloat {
        buttonFrames(originX: 0, originY: 0, width: width).map { $0.frame.maxY }.max() ?? 0
    }

    private var buttonFont: UIFont { font(1.75, .bold) }

    private func buttonFrames(originX: CGFloat, originY: CGFloat, width: CGFloat) -> [(button: InvoicePDFModel.PayButton, frame: CGRect)] {
        var x = originX, y = originY
        let h = buttonFont.lineHeight + 1.8 * u
        var result: [(button: InvoicePDFModel.PayButton, frame: CGRect)] = []
        for button in model.payButtons {
            let w = measureWidth(button.label, font: buttonFont) + 4.8 * u
            if x > originX, x + w > originX + width {
                x = originX
                y += h + 1.2 * u
            }
            result.append((button: button, frame: CGRect(x: x, y: y, width: w, height: h)))
            x += w + 1.2 * u
        }
        return result
    }

    private mutating func drawFooter(height: CGFloat) {
        // Footer sits at the bottom of the last page, like the mockup's margin-top:auto.
        let top = max(y + 3 * u, bottom - height)
        hairline.setFill()
        UIRectFill(CGRect(x: left, y: top, width: width, height: 0.15 * u))
        var fy = top + 3 * u
        let w = footerTextWidth()
        if model.showsPayment {
            fy += drawText(String(localized: "How to pay"), font: small, color: label, rect: CGRect(x: left, y: fy, width: w, height: 4 * u)) + 0.6 * u
            if let bank = model.bankLine {
                fy += drawText(bank, font: body, color: ink, rect: CGRect(x: left, y: fy, width: w, height: 12 * u))
            }
            if !model.payButtons.isEmpty {
                fy += 1.4 * u
                for (button, frame) in buttonFrames(originX: left, originY: fy, width: w) {
                    let path = UIBezierPath(roundedRect: frame, cornerRadius: frame.height / 2)
                    accent.setFill()
                    path.fill()
                    drawText(button.label, font: buttonFont, color: .white, rect: frame.insetBy(dx: 2.4 * u, dy: 0.9 * u), align: .center)
                    if let url = button.url { context.setURL(url, for: frame) }
                }
                fy += buttonRowsHeight(width: w)
            }
            if let payload = model.qrPayload, let qr = QRCode.image(for: payload) {
                let rect = CGRect(x: right - qrSize, y: bottom - qrSize, width: qrSize, height: qrSize)
                qr.draw(in: rect)
                if let url = URL(string: payload) { context.setURL(url, for: rect) }
            }
        }
        if !model.notes.isEmpty {
            fy += 3 * u
            fy += drawText(model.notes, font: body, color: muted, rect: CGRect(x: left, y: fy, width: w, height: 40 * u))
        }
        if !model.signatures.isEmpty {
            fy += 2 * u
            var sx = left
            for signature in model.signatures {
                var sy = fy
                let colW = min(30 * u, w / CGFloat(max(model.signatures.count, 1)))
                if let heading = signature.label {
                    sy += drawText(heading, font: small, color: label, rect: CGRect(x: sx, y: sy, width: colW, height: 4 * u)) + 0.6 * u
                } else {
                    sy += small.lineHeight + 0.6 * u
                }
                let sigRect = CGRect(x: sx, y: sy, width: colW, height: signatureHeight)
                if let data = signature.image, let image = UIImage(data: data) {
                    let fitted = aspectFit(image.size, in: sigRect, alignLeft: true)
                    image.draw(in: fitted)
                } else if signature.blankLine {
                    grid.setFill()
                    UIRectFill(CGRect(x: sx, y: sigRect.maxY - 0.2 * u, width: colW, height: 0.2 * u))
                }
                sy += signatureHeight + 1 * u
                if let caption = signature.caption {
                    drawText(caption, font: body, color: ink, rect: CGRect(x: sx, y: sy, width: colW, height: 5 * u))
                }
                sx += colW + 6 * u
            }
        }
    }

    // MARK: Stamp, watermark, logo

    private func drawPaidStamp() {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let text = String(localized: "PAID")
        let stampFont = UIFont.systemFont(ofSize: 8 * u, weight: .black)
        let attrs: [NSAttributedString.Key: Any] = [.font: stampFont, .foregroundColor: stampGreen.withAlphaComponent(0.85), .kern: 8 * u * 0.06]
        let size = (text as NSString).size(withAttributes: attrs)
        let box = CGRect(x: -size.width / 2 - 3 * u, y: -size.height / 2 - 0.5 * u, width: size.width + 6 * u, height: size.height + 1 * u)
        cg.saveGState()
        cg.translateBy(x: bounds.width * 0.92 - box.width / 2, y: bounds.height * 0.30 + box.height / 2)
        cg.rotate(by: -14 * .pi / 180)
        let path = UIBezierPath(roundedRect: box, cornerRadius: 2 * u)
        path.lineWidth = 0.6 * u
        stampGreen.withAlphaComponent(0.85).setStroke()
        path.stroke()
        (text as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
        cg.restoreGState()
    }

    private func drawWatermark() {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        let text = String(localized: "PREVIEW")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15 * u, weight: .black),
            .foregroundColor: UIColor(red: 0.33, green: 0.23, blue: 0.99, alpha: 0.08), .kern: 15 * u * 0.08,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        cg.saveGState()
        cg.translateBy(x: bounds.midX, y: bounds.midY)
        cg.rotate(by: -30 * .pi / 180)
        (text as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
        cg.restoreGState()
    }

    /// Logo is always "fit", never cropped. Without a logo: initials on a tile.
    private func drawLogo(in rect: CGRect, tile: UIColor, text: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.2)
        if let data = model.logo, let image = UIImage(data: data) {
            UIColor.white.setFill()
            path.fill()
            image.draw(in: aspectFit(image.size, in: rect, alignLeft: false))
        } else {
            tile.setFill()
            path.fill()
            let f = UIFont.systemFont(ofSize: rect.width * 0.36, weight: .heavy)
            let h = f.lineHeight
            drawText(model.initials, font: f, color: text, rect: CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h), align: .center, kern: -0.04)
        }
    }

    // MARK: Primitives

    private func strokeRect(_ rect: CGRect) {
        let path = UIBezierPath(rect: rect)
        path.lineWidth = 0.15 * u
        grid.setStroke()
        path.stroke()
    }

    private func attributes(_ font: UIFont, _ color: UIColor, _ align: NSTextAlignment, kern: CGFloat) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = .byWordWrapping
        return [.font: font, .foregroundColor: color, .paragraphStyle: style, .kern: kern * font.pointSize]
    }

    /// Draws text wrapped in `rect` (height grows to fit) and returns the height used.
    @discardableResult
    private func drawText(_ text: String, font: UIFont, color: UIColor, rect: CGRect, align: NSTextAlignment = .left, kern: CGFloat = 0) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let attrs = attributes(font, color, align, kern: kern)
        let h = ceil((text as NSString).boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: attrs, context: nil).height)
        (text as NSString).draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: h + 1), options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        return h
    }

    private func draw(_ text: String, font: UIFont, color: UIColor, x: CGFloat, width: CGFloat, align: NSTextAlignment) {
        drawText(text, font: font, color: color, rect: CGRect(x: x, y: y, width: width, height: 10 * u), align: align)
    }

    private func measure(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return ceil((text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: [.font: font], context: nil).height)
    }

    private func measureWidth(_ text: String, font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func aspectFit(_ size: CGSize, in rect: CGRect, alignLeft: Bool) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let w = size.width * scale, h = size.height * scale
        let x = alignLeft ? rect.minX : rect.midX - w / 2
        return CGRect(x: x, y: rect.midY - h / 2, width: w, height: h)
    }
}

// MARK: - Helpers

enum QRCode {
    /// A crisp QR code image (nearest-neighbour scaled), or nil if it can't be made.
    static func image(for payload: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
            let cg = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum PDFPageImage {
    static func firstPage(of data: Data, width: CGFloat) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData), let pdf = CGPDFDocument(provider), let page = pdf.page(at: 1) else { return nil }
        let box = page.getBoxRect(.mediaBox)
        let scale = width / box.width
        let size = CGSize(width: width, height: box.height * scale)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            ctx.cgContext.drawPDFPage(page)
        }
    }

    static func pageCount(of data: Data) -> Int {
        guard let provider = CGDataProvider(data: data as CFData), let pdf = CGPDFDocument(provider) else { return 0 }
        return pdf.numberOfPages
    }
}

extension UIFont {
    func withTabularDigits() -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .featureSettings: [[UIFontDescriptor.FeatureKey.type: kNumberSpacingType, UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector]]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

extension UIColor {
    /// "#533AFD" or "533AFD".
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}
