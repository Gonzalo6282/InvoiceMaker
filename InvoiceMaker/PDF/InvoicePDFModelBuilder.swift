import Foundation
import InvoiceKit

/// Turns a stored document into the strings printed on the PDF.
@MainActor
struct InvoicePDFModelBuilder {
    var templateOverride: InvoiceTemplate?
    var accentOverride: String?
    /// "PREVIEW" across the page (non-Premium users previewing a Premium template).
    var watermark = false
    /// The "Made with Duly" line (Settings > Invoice look).
    var showsMadeWith = MadeWithDuly.isOn()
    var today: Date = .now
    var calendar: Calendar = .current

    func build(document doc: Document, business: Business, taxes allTaxes: [TaxRate]) -> InvoicePDFModel {
        let taxes = doc.effectiveTaxes(allTaxes)
        let region = business.region
        let locale = Locale(identifier: region.preset.localeIdentifier)
        let money = { (amount: Decimal) in
            MoneyFormat.string(amount, currencyCode: doc.currencyCode, display: business.currencyDisplay, locale: locale)
        }
        let totals = doc.totals(taxes: taxes)
        let template = templateOverride ?? InvoiceTemplate(id: doc.templateID)
        let kind = doc.kind
        let rateByID = Dictionary(taxes.map { ($0.id, $0.rate) }, uniquingKeysWith: { first, _ in first })

        let showsTaxColumn = doc.taxPlacement == .perItem && !totals.taxes.isEmpty
        let rows = doc.sortedItems.map { item -> InvoicePDFModel.LineRow in
            let line = LineItemInput(quantity: item.quantity, rate: item.rate, discount: item.discount)
            let rates = item.taxIDs.compactMap { rateByID[$0] }
            return InvoicePDFModel.LineRow(
                description: item.itemDescription.isEmpty ? String(localized: "Item") : item.itemDescription,
                discountNote: line.discountAmount == 0 ? nil : discountNote(item.discount, money: money, locale: locale),
                quantity: [item.quantity.formatted(.number.locale(locale)), item.unit]
                    .filter { !$0.isEmpty }.joined(separator: " "),
                rate: money(item.rate),
                tax: showsTaxColumn
                    ? (rates.isEmpty ? "0%" : rates.map { $0.formatted(.number.locale(locale)) }.joined(separator: " + ") + "%")
                    : nil,
                amount: money(line.net))
        }

        return InvoicePDFModel(
            template: template,
            paper: PaperSize.for(countryCode: business.countryCode),
            accentHex: accentOverride ?? doc.brandColorHex,
            title: business.title(for: kind),
            number: doc.number,
            logo: business.logoData,
            initials: Avatar.initials(for: Self.displayName(business)),
            from: fromParty(business),
            to: toParty(doc),
            dates: dateBlocks(doc, locale: locale),
            job: doc.job.isEmpty ? nil : doc.job,
            showsTaxColumn: showsTaxColumn,
            rows: rows,
            emptyRowsText: String(localized: "No items yet"),
            summary: summaryRows(doc, totals: totals, money: money, locale: locale),
            totalLabel: totalLabel(kind, region: region),
            totalValue: money(totals.total),
            showsPayment: kind == .invoice
                && (bankLine(business.payment) != nil || !payButtons(business.payment).isEmpty),
            bankLine: bankLine(business.payment),
            payButtons: payButtons(business.payment),
            qrPayload: qrPayload(business.payment),
            notes: doc.notes,
            signatures: signatures(doc, business: business, locale: locale),
            paidStamp: kind == .receipt || (kind == .invoice && doc.status == .paid),
            watermark: watermark,
            photos: doc.sortedPhotos.compactMap(\.imageData),
            madeWith: showsMadeWith ? MadeWithDuly.text : nil)
    }

    // MARK: Blocks

    private func fromParty(_ business: Business) -> InvoicePDFModel.Party {
        var lines = splitLines(business.address)
        if business.taxRegistered, !business.taxID.isEmpty {
            lines.append("\(business.taxIDLabel) \(business.taxID)")
        }
        return .init(label: String(localized: "From"), name: Self.displayName(business), lines: lines)
    }

    /// The business name on documents; "Your Business" until one is entered.
    static func displayName(_ business: Business) -> String {
        let name = business.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? String(localized: "Your Business") : name
    }

    private func toParty(_ doc: Document) -> InvoicePDFModel.Party {
        let label = doc.kind == .estimate ? String(localized: "For") : String(localized: "Bill to")
        guard let client = doc.client else { return .init(label: label, name: String(localized: "Client name"), lines: []) }
        var lines = splitLines(client.address)
        if !client.taxID.isEmpty { lines.append(client.taxID) }
        return .init(label: label, name: client.name, lines: lines)
    }

    private func dateBlocks(_ doc: Document, locale: Locale) -> [InvoicePDFModel.DateBlock] {
        let date = { (d: Date?) in d.map { self.format($0, locale: locale) } ?? "" }
        switch doc.kind {
        case .receipt:
            return [.init(label: String(localized: "Paid on"), value: date(doc.paidOn ?? doc.issueDate))]
        case .estimate:
            return [
                .init(label: String(localized: "Issued"), value: date(doc.issueDate)),
                .init(label: String(localized: "Valid until"), value: date(doc.dueDate)),
            ]
        case .invoice:
            return [
                .init(label: String(localized: "Issued"), value: date(doc.issueDate)),
                .init(label: String(localized: "Due"), value: date(doc.dueDate)),
            ]
        }
    }

    private func summaryRows(
        _ doc: Document, totals: Totals, money: (Decimal) -> String, locale: Locale
    ) -> [InvoicePDFModel.SummaryRow] {
        let included = doc.taxMode == .included
        var rows: [InvoicePDFModel.SummaryRow] = [
            .init(label: included ? String(localized: "Subtotal (incl. tax)") : String(localized: "Subtotal"), value: money(totals.subtotal))
        ]
        if totals.discount != 0 {
            rows.append(.init(label: String(localized: "Discount"), value: "−" + money(totals.discount)))
        }
        for tax in totals.taxes {
            let rate = tax.rate.formatted(.number.locale(locale))
            let label = included ? String(localized: "Includes \(tax.name) \(rate)%") : "\(tax.name) \(rate)%"
            rows.append(.init(label: label, value: money(tax.amount)))
        }
        if totals.shipping != 0 {
            rows.append(.init(label: String(localized: "Shipping"), value: money(totals.shipping)))
        }
        for fee in doc.fees where fee.amount != 0 {
            rows.append(.init(label: fee.name.isEmpty ? String(localized: "Fee") : fee.name, value: money(fee.amount)))
        }
        return rows
    }

    private func totalLabel(_ kind: DocumentKind, region: Region) -> String {
        switch kind {
        case .receipt: String(localized: "Paid")
        case .estimate: region == .uk ? String(localized: "Quote total") : String(localized: "Estimate total")
        case .invoice: String(localized: "Total due")
        }
    }

    // MARK: Payment

    private func bankLine(_ p: PaymentDetails?) -> String? {
        guard let p, !p.accountNumber.isEmpty || !p.iban.isEmpty else { return nil }
        var parts = [String(localized: "Bank transfer")]
        if !p.bankName.isEmpty { parts.append(p.bankName) }
        if !p.sortCode.isEmpty { parts.append(String(localized: "Sort code \(p.sortCode)")) }
        if !p.accountNumber.isEmpty { parts.append(String(localized: "Account \(p.accountNumber)")) }
        if !p.iban.isEmpty { parts.append("IBAN \(p.iban)") }
        if !p.swift.isEmpty { parts.append("SWIFT \(p.swift)") }
        return parts.joined(separator: " · ")
    }

    private func payButtons(_ p: PaymentDetails?) -> [InvoicePDFModel.PayButton] {
        guard let p else { return [] }
        var buttons: [InvoicePDFModel.PayButton] = []
        if let url = PaymentLinks.web(p.paymentLink) { buttons.append(.init(label: String(localized: "Pay online"), url: url)) }
        if let url = PaymentLinks.payPal(p.payPalMe) { buttons.append(.init(label: "PayPal", url: url)) }
        if let url = PaymentLinks.venmo(p.venmo) { buttons.append(.init(label: "Venmo", url: url)) }
        if let url = PaymentLinks.cashApp(p.cashApp) { buttons.append(.init(label: "Cash App", url: url)) }
        if !p.zelle.trimmingCharacters(in: .whitespaces).isEmpty {
            buttons.append(.init(label: "Zelle \(p.zelle.trimmingCharacters(in: .whitespaces))", url: nil))
        }
        return buttons
    }

    private func qrPayload(_ p: PaymentDetails?) -> String? {
        guard let p, p.showsQRCode else { return nil }
        return (PaymentLinks.web(p.paymentLink) ?? PaymentLinks.payPal(p.payPalMe))?.absoluteString
    }

    // MARK: Signatures

    private func signatures(_ doc: Document, business: Business, locale: Locale) -> [InvoicePDFModel.Signature] {
        let clientCaption = [doc.signedName, doc.signedAt.map { format($0, locale: locale) } ?? ""]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        let client = InvoicePDFModel.Signature(
            label: String(localized: "Client signature"), image: doc.clientSignatureData,
            caption: clientCaption.isEmpty ? nil : clientCaption, blankLine: doc.clientSignatureData == nil)
        switch doc.kind {
        case .invoice:
            var list: [InvoicePDFModel.Signature] = []
            if let own = business.signatureData { list.append(.init(label: nil, image: own, caption: business.name)) }
            if doc.clientSignatureData != nil { list.append(client) }
            return list
        case .estimate:
            return [client]
        case .receipt:
            return []
        }
    }

    // MARK: Helpers

    private func discountNote(_ discount: Discount, money: (Decimal) -> String, locale: Locale) -> String {
        switch discount {
        case .percent(let v): String(localized: "Discount \(v.formatted(.number.locale(locale)))%")
        case .amount(let v): String(localized: "Discount \(money(v))")
        }
    }

    private func format(_ date: Date, locale: Locale) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    private func splitLines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

/// Turns what the user typed into payment URLs. Returns nil for empty or unusable input.
nonisolated enum PaymentLinks {
    nonisolated static func web(_ raw: String) -> URL? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        let withScheme = s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://") ? s : "https://" + s
        guard let url = URL(string: withScheme), let host = url.host(), host.contains(".") else { return nil }
        return url
    }

    /// "paypal.me/kestrel", "https://paypal.me/kestrel" or "kestrel" → https://paypal.me/kestrel
    nonisolated static func payPal(_ raw: String) -> URL? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if s.lowercased().contains("paypal.") { return web(s) }
        return handle(s, prefix: "https://paypal.me/")
    }

    /// "@kestrel" → https://venmo.com/u/kestrel
    nonisolated static func venmo(_ raw: String) -> URL? {
        handle(raw.replacingOccurrences(of: "@", with: ""), prefix: "https://venmo.com/u/")
    }

    /// "$kestrel" → https://cash.app/$kestrel
    nonisolated static func cashApp(_ raw: String) -> URL? {
        let s = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "$", with: "")
        return handle(s, prefix: "https://cash.app/$")
    }

    nonisolated private static func handle(_ raw: String, prefix: String) -> URL? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s.allSatisfy({ $0.isLetter || $0.isNumber || "-_.".contains($0) }) else { return nil }
        return URL(string: prefix + s)
    }
}
