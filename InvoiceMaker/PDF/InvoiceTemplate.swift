import Foundation

/// The 7 PDF templates (design-system.md). Every one takes the brand colour and logo.
nonisolated enum InvoiceTemplate: String, CaseIterable, Identifiable, Sendable {
    case clean, bold, ledger
    case studio, trades, classic, split

    var id: String { rawValue }

    var isPremium: Bool {
        switch self {
        case .clean, .bold, .ledger: false
        case .studio, .trades, .classic, .split: true
        }
    }

    var displayName: String {
        switch self {
        case .clean: String(localized: "Clean")
        case .bold: String(localized: "Bold")
        case .ledger: String(localized: "Ledger")
        case .studio: String(localized: "Studio")
        case .trades: String(localized: "Trades")
        case .classic: String(localized: "Classic")
        case .split: String(localized: "Split")
        }
    }

    init(id: String) {
        self = InvoiceTemplate(rawValue: id) ?? .clean
    }

    /// How the header is laid out.
    enum Header: Sendable { case standard, band, studio, classic, sideBar }

    var header: Header {
        switch self {
        case .clean, .ledger, .trades: .standard
        case .bold: .band
        case .studio: .studio
        case .classic: .classic
        case .split: .sideBar
        }
    }

    /// Table with full cell borders and a tinted header row.
    var gridTable: Bool { self == .ledger }
    /// Serif type throughout.
    var serif: Bool { self == .classic }
    /// Title in the brand colour (otherwise ink).
    var accentTitle: Bool { self == .clean || self == .trades }
    /// Job site shown as a tinted box with a brand-colour bar.
    var jobBox: Bool { self == .trades }
    /// Header rule under the table headings in the brand colour.
    var accentTableRule: Bool { self == .studio }
}

/// Brand colours offered in Settings → Invoice look (from the mockup).
enum BrandColors {
    static let choices = ["#533AFD", "#0A2540", "#0E8A6A", "#0FB5C8", "#D9480F", "#C2185B", "#14202E"]
}
