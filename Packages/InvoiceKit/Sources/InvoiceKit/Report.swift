import Foundation

/// One document as the reports need it.
public struct ReportInput: Sendable {
    public var kind: DocumentKind
    public var status: DocumentStatus
    public var issueDate: Date
    public var due: Date?
    public var paidOn: Date?
    public var currencyCode: String
    public var total: Decimal
    public var clientName: String

    public init(
        kind: DocumentKind, status: DocumentStatus, issueDate: Date, due: Date?, paidOn: Date?, currencyCode: String,
        total: Decimal, clientName: String
    ) {
        self.kind = kind
        self.status = status
        self.issueDate = issueDate
        self.due = due
        self.paidOn = paidOn
        self.currencyCode = currencyCode
        self.total = total
        self.clientName = clientName
    }
}

/// Totals by month and by client for one year and one currency. Only invoices
/// that were sent count (drafts don't). "Invoiced" goes by the invoice date,
/// "Paid" by the date it was paid, "Unpaid" is what those invoices still owe.
public struct Report: Equatable, Sendable {
    public struct Month: Equatable, Sendable {
        /// 1–12.
        public let month: Int
        public let invoiced: Decimal
        public let paid: Decimal
    }

    public struct ClientTotal: Equatable, Sendable {
        public let name: String
        public let invoices: Int
        public let invoiced: Decimal
        public let paid: Decimal
        public let unpaid: Decimal
    }

    public let year: Int
    public let currencyCode: String
    public let months: [Month]
    /// Biggest first.
    public let clients: [ClientTotal]
    public let invoiced: Decimal
    public let paid: Decimal
    public let unpaid: Decimal
    public let invoiceCount: Int

    public init(documents: [ReportInput], year: Int, currencyCode: String, calendar: Calendar = .current) {
        var invoicedByMonth = [Decimal](repeating: 0, count: 12)
        var paidByMonth = [Decimal](repeating: 0, count: 12)
        var byClient: [String: (count: Int, invoiced: Decimal, paid: Decimal, unpaid: Decimal)] = [:]
        var count = 0
        for doc in documents where doc.kind == .invoice && doc.currencyCode == currencyCode && doc.status != .draft {
            if calendar.component(.year, from: doc.issueDate) == year {
                let month = calendar.component(.month, from: doc.issueDate) - 1
                invoicedByMonth[month] += doc.total
                count += 1
                let name = doc.clientName.isEmpty ? Self.noClient : doc.clientName
                var row = byClient[name] ?? (0, 0, 0, 0)
                row.count += 1
                row.invoiced += doc.total
                if doc.status == .paid { row.paid += doc.total } else { row.unpaid += doc.total }
                byClient[name] = row
            }
            if doc.status == .paid, let paidOn = doc.paidOn, calendar.component(.year, from: paidOn) == year {
                paidByMonth[calendar.component(.month, from: paidOn) - 1] += doc.total
            }
        }
        self.year = year
        self.currencyCode = currencyCode
        months = (0..<12).map { Month(month: $0 + 1, invoiced: invoicedByMonth[$0], paid: paidByMonth[$0]) }
        clients = byClient
            .map { ClientTotal(name: $0.key, invoices: $0.value.count, invoiced: $0.value.invoiced, paid: $0.value.paid, unpaid: $0.value.unpaid) }
            .sorted { $0.invoiced != $1.invoiced ? $0.invoiced > $1.invoiced : $0.name < $1.name }
        invoiced = invoicedByMonth.reduce(0, +)
        paid = paidByMonth.reduce(0, +)
        unpaid = clients.reduce(0) { $0 + $1.unpaid }
        invoiceCount = count
    }

    /// Shown (and exported) for invoices without a client.
    public static let noClient = "—"

    /// The years with sent invoices, newest first.
    public static func years(in documents: [ReportInput], calendar: Calendar = .current) -> [Int] {
        Set(documents.filter { $0.kind == .invoice && $0.status != .draft }.map { calendar.component(.year, from: $0.issueDate) })
            .sorted(by: >)
    }

    /// The currencies of sent invoices, `preferred` first.
    public static func currencies(in documents: [ReportInput], preferred: String) -> [String] {
        let codes = Set(documents.filter { $0.kind == .invoice && $0.status != .draft }.map(\.currencyCode))
        return codes.sorted { $0 == preferred ? true : $1 == preferred ? false : $0 < $1 }
    }

    /// The report as CSV: one row per month, then one per client.
    /// `monthName` turns 1–12 into the label to show.
    public func csv(monthName: (Int) -> String) -> String {
        let header = ["Section", "Name", "Invoices", "Invoiced", "Paid", "Unpaid", "Currency"]
        var rows = months.map {
            ["Month", "\(monthName($0.month)) \(year)", "", CSVWriter.amount($0.invoiced), CSVWriter.amount($0.paid), "", currencyCode]
        }
        rows += clients.map {
            ["Client", $0.name, "\($0.invoices)", CSVWriter.amount($0.invoiced), CSVWriter.amount($0.paid), CSVWriter.amount($0.unpaid), currencyCode]
        }
        rows.append(["Total", "\(year)", "\(invoiceCount)", CSVWriter.amount(invoiced), CSVWriter.amount(paid), CSVWriter.amount(unpaid), currencyCode])
        return CSVWriter.string(header: header, rows: rows)
    }
}
