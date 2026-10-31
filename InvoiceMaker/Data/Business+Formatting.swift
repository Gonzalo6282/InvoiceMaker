import Foundation
import InvoiceKit

extension Business {
    var locale: Locale { Locale(identifier: region.preset.localeIdentifier) }

    /// An amount as the user chose to show currency (symbol / code / none).
    func money(_ amount: Decimal, currency: String? = nil) -> String {
        MoneyFormat.string(amount, currencyCode: currency ?? currencyCode, display: currencyDisplay, locale: locale)
    }

    /// "1 Nov" (UK) or "Nov 1" (US).
    func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    /// "1 Nov 2026" (UK) or "Nov 1, 2026" (US).
    func mediumDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    /// "Invoices", "Quotes"/"Estimates", "Receipts".
    func pluralTitle(for kind: DocumentKind) -> String {
        switch kind {
        case .invoice: String(localized: "Invoices")
        case .estimate: region.usesQuote ? String(localized: "Quotes") : String(localized: "Estimates")
        case .receipt: String(localized: "Receipts")
        }
    }

    /// "Invoice", "Quote", "Tax invoice"… in the app's language.
    func title(for kind: DocumentKind) -> String {
        Self.localized(region.title(for: kind, taxRegistered: taxRegistered))
    }

    /// Whole phrases, so languages with genders read right ("Neue Rechnung", "Neues Angebot").
    func newTitle(for kind: DocumentKind) -> String {
        switch kind {
        case .invoice: String(localized: "New invoice")
        case .estimate: region == .uk ? String(localized: "New quote") : String(localized: "New estimate")
        case .receipt: String(localized: "New receipt")
        }
    }

    /// The tax ID label ("VAT number", "USt-IdNr.") in the app's language.
    var taxIDLabel: String { Self.localized(region.preset.taxIDLabel) }

    /// Looks up an English string that comes from InvoiceKit.
    static func localized(_ english: String) -> String {
        Bundle.main.localizedString(forKey: english, value: english, table: nil)
    }
}

extension Document {
    /// The line under the client name in lists, as in the mockup.
    func dueText(business: Business, today: Date = .now, calendar: Calendar = .current) -> String {
        let shown = displayStatus(today: today, calendar: calendar)
        if kind == .receipt || shown == .paid {
            return String(localized: "Paid \(business.shortDate(paidOn ?? issueDate))")
        }
        if shown == .overdue, let dueDate {
            let n = StatusRules.daysOverdue(due: dueDate, today: today, calendar: calendar)
            return n == 1 ? String(localized: "Overdue by 1 day") : String(localized: "Overdue by \(n) days")
        }
        if kind == .estimate {
            switch shown {
            case .accepted:
                return String(localized: "Signed by \(signedName.isEmpty ? String(localized: "client") : signedName)")
            case .converted:
                return String(localized: "Turned into an invoice")
            default:
                return dueDate.map { String(localized: "Valid until \(business.shortDate($0))") } ?? ""
            }
        }
        if shown == .draft { return String(localized: "Not sent yet") }
        guard let dueDate else { return String(localized: "Sent") }
        let days = StatusRules.daysOverdue(due: today, today: dueDate, calendar: calendar)
        switch days {
        case 0: return String(localized: "Due today")
        case 1: return String(localized: "Due in 1 day")
        default: return String(localized: "Due in \(days) days")
        }
    }
}
