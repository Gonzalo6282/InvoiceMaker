import Foundation
import InvoiceKit
import SwiftData
import Testing

@testable import InvoiceMaker

@MainActor
struct RecurringAndRemindersTests {
    let container: ModelContainer
    let context: ModelContext
    let business: Business
    let calendar: Calendar

    init() throws {
        container = try ModelContainerFactory.makeForTests()
        context = container.mainContext
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London")!
        calendar = cal
        business = BusinessSetup.create(name: "Kestrel Joinery", region: .uk, countryCode: "GB", in: context)
    }

    func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    func invoice(issued: Date, client: String = "Marlow & Finch") -> Document {
        let actions = DocumentActions(context: context, calendar: calendar, now: { issued })
        let buyer = Client(name: client)
        context.insert(buyer)
        let doc = actions.create(.invoice, business: business, client: buyer)
        actions.addLineItem(to: doc, defaultTaxID: business.defaultTaxID).rate = 100
        return doc
    }

    func recurring(at now: Date) -> RecurringInvoices {
        RecurringInvoices(context: context, calendar: calendar, now: { now })
    }

    // MARK: Recurring

    @Test func settingAScheduleSetsTheNextDate() {
        let doc = invoice(issued: day(2026, 1, 31))
        recurring(at: day(2026, 1, 31)).set(.monthly, on: doc)
        #expect(doc.recurrence == .monthly)
        #expect(doc.nextRecurrence == day(2026, 2, 28))
        recurring(at: day(2026, 1, 31)).set(nil, on: doc)
        #expect(doc.recurrence == nil)
        #expect(doc.nextRecurrence == nil)
    }

    @Test func onlyInvoicesRepeat() {
        let estimate = DocumentActions(context: context, calendar: calendar).create(.estimate, business: business)
        recurring(at: .now).set(.weekly, on: estimate)
        #expect(estimate.recurrence == nil)
    }

    @Test func dueCopyIsADraftOnItsScheduledDay() throws {
        let doc = invoice(issued: day(2026, 1, 15))
        recurring(at: day(2026, 1, 15)).set(.monthly, on: doc)
        #expect(recurring(at: day(2026, 2, 14)).prepareDue(business: business).isEmpty)
        let made = recurring(at: day(2026, 2, 16)).prepareDue(business: business)
        let copy = try #require(made.first)
        #expect(made.count == 1)
        #expect(copy.status == .draft)
        #expect(copy.number != doc.number)
        #expect(copy.recurringFromNumber == doc.number)
        #expect(copy.recurrence == nil)
        #expect(copy.client?.name == "Marlow & Finch")
        #expect(copy.sortedItems.map(\.rate) == [100])
        #expect(calendar.isDate(copy.issueDate, inSameDayAs: day(2026, 2, 15)))
        #expect(calendar.isDate(copy.dueDate!, inSameDayAs: day(2026, 3, 1)))  // 14 days
        #expect(doc.nextRecurrence == day(2026, 3, 15))
        #expect(recurring(at: day(2026, 2, 20)).prepareDue(business: business).isEmpty)
    }

    @Test func afterALongGapOnlyTheLatestCopyIsMade() throws {
        let doc = invoice(issued: day(2026, 1, 5))
        recurring(at: day(2026, 1, 5)).set(.weekly, on: doc)
        let made = recurring(at: day(2026, 3, 3)).prepareDue(business: business)
        #expect(made.count == 1)
        #expect(calendar.isDate(try #require(made.first).issueDate, inSameDayAs: day(2026, 3, 2)))
        #expect(doc.nextRecurrence == day(2026, 3, 9))
    }

    @Test func changingTheDateOfAnOldInvoiceSchedulesFromToday() {
        let doc = invoice(issued: day(2026, 1, 10))
        recurring(at: day(2026, 4, 20)).set(.monthly, on: doc)
        #expect(doc.nextRecurrence == day(2026, 5, 10))
    }

    // MARK: Reminders

    @Test func paymentRemindersBeforeAndOnTheDueDate() throws {
        let doc = invoice(issued: day(2026, 10, 1))
        DocumentActions(context: context, calendar: calendar, now: { day(2026, 10, 1) }).markSent(doc)
        let planned = Reminders.plan(
            documents: [doc], business: business, taxes: try BusinessSetup.taxes(in: context), paymentReminders: true,
            now: day(2026, 10, 2), calendar: calendar)
        #expect(planned.map(\.id) == ["duly.due-before.\(doc.number)", "duly.due-today.\(doc.number)"])
        #expect(planned.map(\.date) == [day(2026, 10, 12, hour: 9), day(2026, 10, 15, hour: 9)])
        #expect(planned[0].title == "\(doc.number) is due in 3 days")
        #expect(planned[1].body == "Marlow & Finch · £120.00")
    }

    @Test func noPaymentRemindersWhenOffPaidOrPast() throws {
        let taxes = try BusinessSetup.taxes(in: context)
        let actions = DocumentActions(context: context, calendar: calendar, now: { day(2026, 10, 1) })
        let sent = invoice(issued: day(2026, 10, 1))
        actions.markSent(sent)
        let paid = invoice(issued: day(2026, 10, 1))
        actions.markSent(paid)
        actions.markPaid(paid)
        let draft = invoice(issued: day(2026, 10, 1))
        #expect(Reminders.plan(documents: [sent], business: business, taxes: taxes, paymentReminders: false, now: day(2026, 10, 2), calendar: calendar).isEmpty)
        #expect(Reminders.plan(documents: [paid, draft], business: business, taxes: taxes, paymentReminders: true, now: day(2026, 10, 2), calendar: calendar).isEmpty)
        // Only the due-day note is still ahead.
        #expect(Reminders.plan(documents: [sent], business: business, taxes: taxes, paymentReminders: true, now: day(2026, 10, 13), calendar: calendar).count == 1)
    }

    @Test func recurringInvoiceGetsAReadyNoteEvenWithPaymentRemindersOff() {
        let doc = invoice(issued: day(2026, 10, 1))
        recurring(at: day(2026, 10, 1)).set(.monthly, on: doc)
        let planned = Reminders.plan(documents: [doc], business: business, taxes: [], paymentReminders: false, now: day(2026, 10, 2), calendar: calendar)
        #expect(planned == [Reminders.Planned(
            id: "duly.recurring.\(doc.number)", date: day(2026, 11, 1, hour: 9), title: "Your monthly invoice is ready",
            body: "For Marlow & Finch. Open Duly to check it and send it.")])
    }
}
