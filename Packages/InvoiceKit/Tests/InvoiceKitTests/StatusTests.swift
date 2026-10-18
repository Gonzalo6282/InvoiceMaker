import Foundation
import InvoiceKit
import Testing

private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/London")!
    return c
}()

private func day(_ s: String, hour: Int = 12) -> Date {
    let p = s.split(separator: "-").map { Int($0)! }
    return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: hour))!
}

struct StatusTests {
    let today = day("2026-10-18")

    @Test func sentInvoicePastDueIsOverdue() {
        #expect(StatusRules.display(kind: .invoice, status: .sent, due: day("2026-10-17"), today: today, calendar: calendar) == .overdue)
    }

    @Test func dueTodayIsNotOverdueEvenLateInTheDay() {
        let late = day("2026-10-18", hour: 23)
        #expect(StatusRules.display(kind: .invoice, status: .sent, due: day("2026-10-18", hour: 1), today: late, calendar: calendar) == .sent)
    }

    @Test func onlySentInvoicesGoOverdue() {
        let past = day("2026-01-01")
        #expect(StatusRules.display(kind: .invoice, status: .paid, due: past, today: today, calendar: calendar) == .paid)
        #expect(StatusRules.display(kind: .invoice, status: .draft, due: past, today: today, calendar: calendar) == .draft)
        #expect(StatusRules.display(kind: .estimate, status: .sent, due: past, today: today, calendar: calendar) == .sent)
        #expect(StatusRules.display(kind: .estimate, status: .accepted, due: past, today: today, calendar: calendar) == .accepted)
        #expect(StatusRules.display(kind: .estimate, status: .converted, due: nil, today: today, calendar: calendar) == .converted)
        #expect(StatusRules.display(kind: .invoice, status: .sent, due: nil, today: today, calendar: calendar) == .sent)
    }

    @Test func daysOverdue() {
        #expect(StatusRules.daysOverdue(due: day("2026-10-15"), today: today, calendar: calendar) == 3)
        // Across the clock change on 25 Oct 2026 (a 25-hour day in London).
        #expect(StatusRules.daysOverdue(due: day("2026-10-24"), today: day("2026-10-27"), calendar: calendar) == 3)
        #expect(StatusRules.daysOverdue(due: day("2026-03-28"), today: day("2026-03-30", hour: 0), calendar: calendar) == 2)
        #expect(StatusRules.daysOverdue(due: day("2026-10-20"), today: today, calendar: calendar) == 0)
    }

    @Test func moneySummary() {
        let docs = [
            SummaryInput(kind: .invoice, status: .sent, due: day("2026-11-01"), paidOn: nil, currencyCode: "GBP", total: 100),
            SummaryInput(kind: .invoice, status: .sent, due: day("2026-10-01"), paidOn: nil, currencyCode: "GBP", total: 50),
            SummaryInput(kind: .invoice, status: .paid, due: nil, paidOn: day("2026-10-02"), currencyCode: "GBP", total: 70),
            SummaryInput(kind: .invoice, status: .paid, due: nil, paidOn: day("2026-09-30"), currencyCode: "GBP", total: 999),
            SummaryInput(kind: .invoice, status: .paid, due: nil, paidOn: nil, currencyCode: "GBP", total: 5),
            SummaryInput(kind: .invoice, status: .draft, due: nil, paidOn: nil, currencyCode: "GBP", total: 30),
            SummaryInput(kind: .invoice, status: .sent, due: day("2026-11-01"), paidOn: nil, currencyCode: "EUR", total: 40),
            SummaryInput(kind: .invoice, status: .sent, due: day("2026-10-01"), paidOn: nil, currencyCode: "EUR", total: 2),
            SummaryInput(kind: .invoice, status: .paid, due: nil, paidOn: day("2026-10-03"), currencyCode: "EUR", total: 8),
            SummaryInput(kind: .estimate, status: .sent, due: nil, paidOn: nil, currencyCode: "GBP", total: 500),
            SummaryInput(kind: .receipt, status: .paid, due: nil, paidOn: day("2026-10-05"), currencyCode: "GBP", total: 500),
        ]
        let s = MoneySummary(documents: docs, currencyCode: "GBP", today: today, calendar: calendar)
        #expect(s.owed == 150)
        #expect(s.overdue == 50)
        #expect(s.paidThisMonth == 70)
        #expect(s.owedInOtherCurrencies == ["EUR": 42])
    }

    @Test func defaultCalendarOverloads() {
        let now = Date()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        #expect(StatusRules.display(kind: .invoice, status: .sent, due: threeDaysAgo, today: now) == .overdue)
        #expect(StatusRules.daysOverdue(due: threeDaysAgo, today: now) == 3)
        #expect(MoneySummary(documents: [], currencyCode: "GBP", today: now).owed == 0)
    }

    @Test func allStatusesHaveDisplayEquivalents() {
        for status in DocumentStatus.allCases {
            #expect(DisplayStatus(rawValue: status.rawValue) != nil)
        }
        #expect(DisplayStatus.allCases.count == DocumentStatus.allCases.count + 1)
        #expect(DocumentKind.allCases == [.invoice, .estimate, .receipt])
    }
}
