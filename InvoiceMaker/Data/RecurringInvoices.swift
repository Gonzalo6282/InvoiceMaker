import Foundation
import InvoiceKit
import SwiftData

/// Recurring invoices (v1.1). The first invoice of a series carries the
/// schedule; when a date comes round, the app prepares a draft copy for the
/// user to check and send (it never sends anything by itself). Runs when the
/// app opens; a local notification tells the user a copy is ready.
@MainActor
struct RecurringInvoices {
    let context: ModelContext
    var calendar: Calendar = .current
    var now: () -> Date = { .now }

    /// Starts, changes or stops the schedule on an invoice.
    func set(_ recurrence: Recurrence?, on invoice: Document) {
        guard invoice.kind == .invoice else { return }
        invoice.recurrence = recurrence
        invoice.nextRecurrence = recurrence.map {
            $0.next(after: max(now(), invoice.issueDate), anchor: invoice.issueDate, calendar: calendar)
        }
        invoice.updatedAt = now()
    }

    /// Makes the draft copies that are due and moves each schedule on.
    /// If the app wasn't opened for a while, only the latest missed copy is
    /// made (one draft per series, dated on its scheduled day).
    @discardableResult
    func prepareDue(business: Business) -> [Document] {
        let today = now()
        let descriptor = FetchDescriptor<Document>(predicate: #Predicate { $0.recurrenceRaw != "" })
        let series = (try? context.fetch(descriptor)) ?? []
        var made: [Document] = []
        for invoice in series {
            guard let recurrence = invoice.recurrence, let due = invoice.nextRecurrence, due <= today else { continue }
            var scheduled = due
            var next = recurrence.next(after: scheduled, anchor: invoice.issueDate, calendar: calendar)
            while next <= today {
                scheduled = next
                next = recurrence.next(after: scheduled, anchor: invoice.issueDate, calendar: calendar)
            }
            let actions = DocumentActions(context: context, calendar: calendar, now: { scheduled })
            let copy = actions.duplicate(invoice, business: business)
            copy.currencyCode = invoice.currencyCode
            copy.recurringFromNumber = invoice.number
            made.append(copy)
            invoice.nextRecurrence = recurrence.next(after: today, anchor: invoice.issueDate, calendar: calendar)
        }
        return made
    }

    /// "Monthly · next 27 Nov" for the editor.
    static func summary(_ invoice: Document, business: Business) -> String? {
        guard let recurrence = invoice.recurrence else { return nil }
        guard let next = invoice.nextRecurrence else { return recurrence.title }
        return String(localized: "\(recurrence.title) · next \(business.shortDate(next))")
    }
}

extension Recurrence {
    var title: String {
        switch self {
        case .weekly: String(localized: "Weekly")
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        }
    }
}
