import Foundation

/// What is stored on a document.
public enum DocumentStatus: String, CaseIterable, Sendable, Codable {
    case draft
    case sent
    case paid
    /// Estimate signed or accepted by the client.
    case accepted
    /// Estimate turned into an invoice.
    case converted
}

/// What the user sees: stored status, plus overdue.
public enum DisplayStatus: String, CaseIterable, Sendable {
    case draft, sent, paid, overdue, accepted, converted
}

public enum StatusRules {
    /// A sent invoice is overdue the day after its due date.
    public static func display(
        kind: DocumentKind, status: DocumentStatus, due: Date?, today: Date, calendar: Calendar = .current
    ) -> DisplayStatus {
        if kind == .invoice, status == .sent, let due,
            calendar.startOfDay(for: due) < calendar.startOfDay(for: today)
        {
            return .overdue
        }
        switch status {
        case .draft: return .draft
        case .sent: return .sent
        case .paid: return .paid
        case .accepted: return .accepted
        case .converted: return .converted
        }
    }

    /// Whole days past due (0 if not overdue).
    public static func daysOverdue(due: Date, today: Date, calendar: Calendar = .current) -> Int {
        // Midnight to midnight; rounding absorbs the 23/25-hour days at clock changes.
        let seconds = calendar.startOfDay(for: today).timeIntervalSince(calendar.startOfDay(for: due))
        return max(Int((seconds / 86_400).rounded()), 0)
    }
}

/// One invoice as the money summary needs it.
public struct SummaryInput: Sendable {
    public var kind: DocumentKind
    public var status: DocumentStatus
    public var due: Date?
    public var paidOn: Date?
    public var currencyCode: String
    public var total: Decimal

    public init(kind: DocumentKind, status: DocumentStatus, due: Date?, paidOn: Date?, currencyCode: String, total: Decimal) {
        self.kind = kind
        self.status = status
        self.due = due
        self.paidOn = paidOn
        self.currencyCode = currencyCode
        self.total = total
    }
}

/// The "Owed to you" hero card. Only invoices count; only the business
/// currency is added up, other currencies are listed separately.
public struct MoneySummary: Equatable, Sendable {
    public let owed: Decimal
    public let overdue: Decimal
    public let paidThisMonth: Decimal
    /// Owed in other currencies, by currency code.
    public let owedInOtherCurrencies: [String: Decimal]

    public init(documents: [SummaryInput], currencyCode: String, today: Date, calendar: Calendar = .current) {
        var owed: Decimal = 0
        var overdue: Decimal = 0
        var paid: Decimal = 0
        var other: [String: Decimal] = [:]
        for doc in documents where doc.kind == .invoice {
            let shown = StatusRules.display(kind: doc.kind, status: doc.status, due: doc.due, today: today, calendar: calendar)
            let unpaid = shown == .sent || shown == .overdue
            guard doc.currencyCode == currencyCode else {
                if unpaid { other[doc.currencyCode, default: 0] += doc.total }
                continue
            }
            if unpaid { owed += doc.total }
            if shown == .overdue { overdue += doc.total }
            if doc.status == .paid, let paidOn = doc.paidOn,
                calendar.isDate(paidOn, equalTo: today, toGranularity: .month)
            {
                paid += doc.total
            }
        }
        self.owed = owed
        self.overdue = overdue
        self.paidThisMonth = paid
        self.owedInOtherCurrencies = other
    }
}
