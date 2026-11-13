import Foundation

/// The countries with tax presets (UK, Australia, Canada and the US in 1.0;
/// Germany and France in 1.1; Mexico and Spain in 1.2; South Africa and New Zealand in 1.2). Any other country falls back to the UK preset
/// (as in the mockup); the user edits it.
public enum Region: String, CaseIterable, Sendable, Codable {
    case uk
    case au
    case ca
    case us
    case de
    case fr
    case mx
    case es
    case za
    case nz

    /// Accepts ISO 3166 alpha-2 or alpha-3 codes (`Storefront.countryCode` is
    /// alpha-3), plus "UK". Returns nil for countries without a preset.
    public init?(countryCode: String) {
        switch countryCode.uppercased() {
        case "GB", "GBR", "UK": self = .uk
        case "AU", "AUS": self = .au
        case "CA", "CAN": self = .ca
        case "US", "USA": self = .us
        case "DE", "DEU": self = .de
        case "FR", "FRA": self = .fr
        case "MX", "MEX": self = .mx
        case "ES", "ESP": self = .es
        case "ZA", "ZAF": self = .za
        case "NZ", "NZL": self = .nz
        default: return nil
        }
    }

    /// Like `init?(countryCode:)` but falls back to `.uk`.
    public static func resolve(countryCode: String?) -> Region {
        countryCode.flatMap(Region.init(countryCode:)) ?? .uk
    }

    public var preset: RegionPreset {
        switch self {
        case .uk:
            RegionPreset(
                currencyCode: "GBP", localeIdentifier: "en_GB", taxIDLabel: "VAT number",
                taxes: [
                    TaxRate(id: "uk-vat20", name: "VAT", rate: 20),
                    TaxRate(id: "uk-vat5", name: "VAT", rate: 5),
                    TaxRate(id: "uk-vat0", name: "VAT", rate: 0),
                ])
        case .au:
            RegionPreset(
                currencyCode: "AUD", localeIdentifier: "en_AU", taxIDLabel: "ABN",
                taxes: [
                    TaxRate(id: "au-gst10", name: "GST", rate: 10),
                    TaxRate(id: "au-gst0", name: "GST", rate: 0),  // GST-free
                ])
        case .ca:
            RegionPreset(
                currencyCode: "CAD", localeIdentifier: "en_CA", taxIDLabel: "GST/HST number",
                taxes: [
                    TaxRate(id: "ca-gst5", name: "GST", rate: 5),  // AB, territories; + PST/QST below
                    TaxRate(id: "ca-pst7", name: "PST", rate: 7),  // BC, MB
                    TaxRate(id: "ca-pst6", name: "PST", rate: 6),  // SK
                    TaxRate(id: "ca-qst9975", name: "QST", rate: Decimal(string: "9.975")!),  // QC
                    TaxRate(id: "ca-hst13", name: "HST", rate: 13),  // ON
                    TaxRate(id: "ca-hst14", name: "HST", rate: 14),  // NS (since April 2025)
                    TaxRate(id: "ca-hst15", name: "HST", rate: 15),  // NB, NL, PE
                ])
        case .us:
            RegionPreset(
                currencyCode: "USD", localeIdentifier: "en_US", taxIDLabel: "EIN",
                taxes: [TaxRate(id: "us-sales", name: "Sales tax", rate: Decimal(string: "8.875")!)])
        case .de:
            RegionPreset(
                currencyCode: "EUR", localeIdentifier: "de_DE", taxIDLabel: "USt-IdNr.",
                taxes: [
                    TaxRate(id: "de-mwst19", name: "MwSt.", rate: 19),
                    TaxRate(id: "de-mwst7", name: "MwSt.", rate: 7),
                    TaxRate(id: "de-mwst0", name: "MwSt.", rate: 0),
                ])
        case .fr:
            RegionPreset(
                currencyCode: "EUR", localeIdentifier: "fr_FR", taxIDLabel: "N° TVA",
                taxes: [
                    TaxRate(id: "fr-tva20", name: "TVA", rate: 20),
                    TaxRate(id: "fr-tva10", name: "TVA", rate: 10),
                    TaxRate(id: "fr-tva55", name: "TVA", rate: Decimal(string: "5.5")!),
                    TaxRate(id: "fr-tva0", name: "TVA", rate: 0),
                ])
        case .mx:
            // IVA 16% general, 8% in the northern and southern border zones, 0% (food, exports).
            RegionPreset(
                currencyCode: "MXN", localeIdentifier: "es_MX", taxIDLabel: "RFC",
                taxes: [
                    TaxRate(id: "mx-iva16", name: "IVA", rate: 16),
                    TaxRate(id: "mx-iva8", name: "IVA", rate: 8),
                    TaxRate(id: "mx-iva0", name: "IVA", rate: 0),
                ])
        case .es:
            RegionPreset(
                currencyCode: "EUR", localeIdentifier: "es_ES", taxIDLabel: "NIF",
                taxes: [
                    TaxRate(id: "es-iva21", name: "IVA", rate: 21),
                    TaxRate(id: "es-iva10", name: "IVA", rate: 10),
                    TaxRate(id: "es-iva4", name: "IVA", rate: 4),
                    TaxRate(id: "es-iva0", name: "IVA", rate: 0),
                ])
        case .za:
            // VAT 15% standard, 0% zero-rated (exports, basic foods).
            RegionPreset(
                currencyCode: "ZAR", localeIdentifier: "en_ZA", taxIDLabel: "VAT No.",
                taxes: [
                    TaxRate(id: "za-vat15", name: "VAT", rate: 15),
                    TaxRate(id: "za-vat0", name: "VAT", rate: 0),
                ])
        case .nz:
            // GST 15% standard, 0% zero-rated (exports).
            RegionPreset(
                currencyCode: "NZD", localeIdentifier: "en_NZ", taxIDLabel: "GST No.",
                taxes: [
                    TaxRate(id: "nz-gst15", name: "GST", rate: 15),
                    TaxRate(id: "nz-gst0", name: "GST", rate: 0),
                ])
        }
    }

    /// "Quote" in the UK, Australia, New Zealand and South Africa (what people there say and search for), "Estimate" elsewhere.
    public var usesQuote: Bool { [.uk, .au, .nz, .za].contains(self) }

    /// What an estimate is called: "Quote" or "Estimate".
    public var estimateTitle: String { usesQuote ? "Quote" : "Estimate" }

    /// GST/VAT-registered businesses in Australia, New Zealand and South Africa title it "Tax invoice".
    public func invoiceTitle(taxRegistered: Bool) -> String {
        [.au, .nz, .za].contains(self) && taxRegistered ? "Tax invoice" : "Invoice"
    }

    public func title(for kind: DocumentKind, taxRegistered: Bool) -> String {
        switch kind {
        case .invoice: invoiceTitle(taxRegistered: taxRegistered)
        case .estimate: estimateTitle
        case .receipt: "Receipt"
        }
    }
}

/// Starting values for a new business in a region. The user can edit all of it.
public struct RegionPreset: Equatable, Sendable {
    public let currencyCode: String
    public let localeIdentifier: String
    public let taxIDLabel: String
    public let taxes: [TaxRate]
    /// The first tax is the default for new lines.
    public var defaultTax: TaxRate? { taxes.first }
}

/// Paper size for PDFs.
public enum PaperSize: String, Sendable, Codable, CaseIterable {
    case a4
    case letter

    /// Size in PDF points (1/72 inch).
    public var points: (width: Double, height: Double) {
        switch self {
        case .a4: (595.28, 841.89)
        case .letter: (612, 792)
        }
    }

    /// US Letter in North America and the few other countries that use it; A4 everywhere else.
    public static func `for`(countryCode: String?) -> PaperSize {
        let letter: Set<String> = [
            "US", "USA", "CA", "CAN", "MX", "MEX", "PH", "PHL", "CL", "CHL", "CO", "COL", "VE", "VEN", "PR", "PRI",
        ]
        return letter.contains(countryCode?.uppercased() ?? "") ? .letter : .a4
    }
}

extension Region {
    /// A preset tax's name as the user expects to see it. In Canada with the app
    /// in French (Quebec), GST/HST/PST/QST are TPS/TVH/TVP/TVQ.
    public func taxName(_ tax: TaxRate, french: Bool) -> String {
        guard self == .ca, french else { return tax.name }
        return ["GST": "TPS", "HST": "TVH", "PST": "TVP", "QST": "TVQ"][tax.name] ?? tax.name
    }
}
