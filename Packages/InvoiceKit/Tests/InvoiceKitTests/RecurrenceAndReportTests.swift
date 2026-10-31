import Foundation
import InvoiceKit
import Testing

private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/London")!
    return c
}()

private func day(_ s: String, hour: Int = 9) -> Date {
    let p = s.split(separator: "-").map { Int($0)! }
    return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: hour))!
}

struct RecurrenceTests {
    @Test func occurrencesCountFromTheAnchor() {
        let anchor = day("2026-01-31")
        #expect(Recurrence.monthly.occurrence(1, from: anchor, calendar: calendar) == day("2026-02-28"))
        #expect(Recurrence.monthly.occurrence(2, from: anchor, calendar: calendar) == day("2026-03-31"))
        #expect(Recurrence.weekly.occurrence(2, from: anchor, calendar: calendar) == day("2026-02-14"))
        #expect(Recurrence.yearly.occurrence(1, from: day("2028-02-29"), calendar: calendar) == day("2029-02-28"))
    }

    @Test func nextIsStrictlyAfterTheDate() {
        let anchor = day("2026-01-31")
        #expect(Recurrence.monthly.next(after: anchor, anchor: anchor, calendar: calendar) == day("2026-02-28"))
        #expect(Recurrence.monthly.next(after: day("2026-02-28"), anchor: anchor, calendar: calendar) == day("2026-03-31"))
        #expect(Recurrence.monthly.next(after: day("2026-03-01"), anchor: anchor, calendar: calendar) == day("2026-03-31"))
        #expect(Recurrence.weekly.next(after: day("2026-02-01"), anchor: anchor, calendar: calendar) == day("2026-02-07"))
        #expect(Recurrence.yearly.next(after: day("2026-06-01"), anchor: anchor, calendar: calendar) == day("2027-01-31"))
    }

    @Test func nextAfterALongGapLandsOnTheSchedule() {
        let anchor = day("2020-01-06")  // a Monday
        let next = Recurrence.weekly.next(after: day("2026-10-27", hour: 12), anchor: anchor, calendar: calendar)
        #expect(next == day("2026-11-02"))
        #expect(Recurrence.monthly.next(after: day("2026-10-27"), anchor: anchor, calendar: calendar) == day("2026-11-06"))
        #expect(Recurrence.yearly.next(after: day("2026-10-27"), anchor: anchor, calendar: calendar) == day("2027-01-06"))
    }

    @Test func dateBeforeTheAnchorGivesTheFirstRepeat() {
        let anchor = day("2026-05-10")
        #expect(Recurrence.weekly.next(after: day("2026-01-01"), anchor: anchor, calendar: calendar) == day("2026-05-17"))
    }
}

struct ReportTests {
    func doc(
        _ status: DocumentStatus, _ issued: String, total: Decimal, client: String = "Oak", paid: String? = nil,
        currency: String = "GBP", kind: DocumentKind = .invoice
    ) -> ReportInput {
        ReportInput(
            kind: kind, status: status, issueDate: day(issued), due: nil, paidOn: paid.map { day($0) }, currencyCode: currency,
            total: total, clientName: client)
    }

    var documents: [ReportInput] {
        [
            doc(.paid, "2026-01-10", total: 100, paid: "2026-02-03"),
            doc(.sent, "2026-01-20", total: 50),
            doc(.sent, "2026-03-05", total: 70, client: "Bay"),
            doc(.draft, "2026-03-06", total: 999),
            doc(.paid, "2025-12-20", total: 40, paid: "2026-01-02"),
            doc(.sent, "2026-04-01", total: 30, currency: "EUR"),
            doc(.sent, "2026-04-02", total: 500, kind: .estimate),
            doc(.paid, "2026-05-01", total: 20, client: "", paid: "2026-05-02"),
        ]
    }

    @Test func monthsAndTotals() {
        let report = Report(documents: documents, year: 2026, currencyCode: "GBP", calendar: calendar)
        #expect(report.months.count == 12)
        #expect(report.months[0] == Report.Month(month: 1, invoiced: 150, paid: 40))
        #expect(report.months[1] == Report.Month(month: 2, invoiced: 0, paid: 100))
        #expect(report.months[2].invoiced == 70)
        #expect(report.invoiced == 240)
        #expect(report.paid == 160)
        #expect(report.unpaid == 120)
        #expect(report.invoiceCount == 4)
    }

    @Test func clientsBiggestFirst() {
        let report = Report(documents: documents, year: 2026, currencyCode: "GBP", calendar: calendar)
        #expect(report.clients == [
            Report.ClientTotal(name: "Oak", invoices: 2, invoiced: 150, paid: 100, unpaid: 50),
            Report.ClientTotal(name: "Bay", invoices: 1, invoiced: 70, paid: 0, unpaid: 70),
            Report.ClientTotal(name: Report.noClient, invoices: 1, invoiced: 20, paid: 20, unpaid: 0),
        ])
        let tie = Report(
            documents: [doc(.sent, "2026-01-01", total: 10, client: "B"), doc(.sent, "2026-01-01", total: 10, client: "A")],
            year: 2026, currencyCode: "GBP", calendar: calendar)
        #expect(tie.clients.map(\.name) == ["A", "B"])
    }

    @Test func yearsAndCurrencies() {
        #expect(Report.years(in: documents, calendar: calendar) == [2026, 2025])
        #expect(Report.currencies(in: documents, preferred: "GBP") == ["GBP", "EUR"])
        #expect(Report.currencies(in: documents, preferred: "EUR") == ["EUR", "GBP"])
        #expect(Report.currencies(in: documents + [doc(.sent, "2026-01-01", total: 1, currency: "AUD")], preferred: "USD") == ["AUD", "EUR", "GBP"])
    }

    @Test func csvHasMonthsClientsAndTotal() {
        let report = Report(documents: documents, year: 2026, currencyCode: "GBP", calendar: calendar)
        let lines = report.csv { "M\($0)" }.components(separatedBy: "\r\n")
        #expect(lines[0] == "Section,Name,Invoices,Invoiced,Paid,Unpaid,Currency")
        #expect(lines[1] == "Month,M1 2026,,150.00,40.00,,GBP")
        #expect(lines[13] == "Client,Oak,2,150.00,100.00,50.00,GBP")
        #expect(lines[16] == "Total,2026,4,240.00,160.00,120.00,GBP")
    }
}
