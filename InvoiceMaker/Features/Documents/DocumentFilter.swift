import Foundation
import InvoiceKit

/// The filter chips above the list (mockup): invoices get five, estimates three.
enum DocumentFilter: String, CaseIterable, Identifiable {
    case all, unpaid, overdue, paid, draft, accepted

    var id: String { rawValue }

    static func options(for kind: DocumentKind) -> [DocumentFilter] {
        switch kind {
        case .invoice: [.all, .unpaid, .overdue, .paid, .draft]
        case .estimate: [.all, .draft, .accepted]
        case .receipt: []
        }
    }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .unpaid: String(localized: "Unpaid")
        case .overdue: String(localized: "Overdue")
        case .paid: String(localized: "Paid")
        case .draft: String(localized: "Drafts")
        case .accepted: String(localized: "Accepted")
        }
    }

    func matches(_ status: DisplayStatus) -> Bool {
        switch self {
        case .all: true
        case .unpaid: status == .sent || status == .overdue
        case .overdue: status == .overdue
        case .paid: status == .paid
        case .draft: status == .draft
        case .accepted: status == .accepted || status == .paid
        }
    }
}
