#if DEBUG
    import Foundation
    import InvoiceKit
    import SwiftData

    /// The mockup's demo business (Kestrel Joinery, Bristol) for previews and
    /// screenshots. Debug builds only.
    @MainActor
    enum DemoData {
        static func container() -> ModelContainer {
            // In-memory store creation only fails if the schema is broken, which tests catch.
            guard let container = try? ModelContainerFactory.make(.inMemory) else {
                preconditionFailure("In-memory store failed")
            }
            seed(container.mainContext)
            return container
        }

        static func seed(_ context: ModelContext, today: Date = .now) {
            let cal = Calendar.current
            func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today) ?? today }

            let biz = BusinessSetup.create(name: "Kestrel Joinery", region: .uk, countryCode: "GB", in: context)
            biz.role = "contractor"
            biz.email = "hello@kestreljoinery.co.uk"
            biz.phone = "07700 900418"
            biz.address = "Unit 4, Mill Yard\nBristol BS3 4AQ"
            biz.taxID = "GB 284 1937 62"
            biz.taxRegistered = true
            biz.defaultNotes = "Thank you for your business. Payment within 14 days, please."
            biz.nextInvoiceNumber = 7
            biz.nextEstimateNumber = 3
            biz.payment?.bankName = "Kestrel Joinery Ltd"
            biz.payment?.sortCode = "04-00-04"
            biz.payment?.accountNumber = "31926819"
            biz.payment?.payPalMe = "paypal.me/kestreljoinery"

            let marlow = Client(name: "Marlow & Finch Architects")
            marlow.contactName = "Priya Marlow"
            marlow.email = "priya@marlowfinch.co.uk"
            marlow.address = "22 Queen Square\nBristol BS1 4ND"
            let ostara = Client(name: "Ostara Café")
            ostara.contactName = "Jonas Berg"
            ostara.email = "jonas@ostaracafe.co.uk"
            let lund = Client(name: "Lund Design Studio", currencyCode: "EUR")
            lund.email = "hej@lunddesign.dk"
            [marlow, ostara, lund].forEach(context.insert)

            context.insert(SavedItem(itemDescription: "Labour", unit: "hour", rate: 45, taxID: "uk-vat20"))
            context.insert(SavedItem(itemDescription: "Oak worktop, fitted", unit: "metre", rate: 180, taxID: "uk-vat20"))

            let actions = DocumentActions(context: context, now: { today })
            let a = actions.create(.invoice, business: biz, client: marlow)
            actions.addLineItem(to: a, defaultTaxID: "uk-vat20").configure("Bespoke shelving, installed", qty: 2, rate: 87.5)
            actions.addLineItem(to: a, defaultTaxID: "uk-vat20").configure("Site visit", qty: 1, rate: 52.5)
            actions.markSent(a)

            let b = actions.create(.invoice, business: biz, client: ostara)
            b.issueDate = day(-30)
            b.dueDate = day(-16)
            actions.addLineItem(to: b, defaultTaxID: "uk-vat20").configure("Counter repair", qty: 1, rate: 640)
            actions.markSent(b)

            let c = actions.create(.invoice, business: biz, client: marlow)
            actions.addLineItem(to: c, defaultTaxID: "uk-vat20").configure("Joinery drawings", qty: 1, rate: 600)
            actions.markSent(c)
            actions.markPaid(c, on: today)

            let d = actions.create(.invoice, business: biz, client: lund)
            actions.addLineItem(to: d, defaultTaxID: "uk-vat0").configure("Shop-fit consultation", qty: 1, rate: 1200)
            actions.markSent(d)

            actions.create(.invoice, business: biz, client: ostara)

            let e = actions.create(.estimate, business: biz, client: ostara)
            actions.addLineItem(to: e, defaultTaxID: "uk-vat20").configure("New bar top", qty: 1, rate: 1850)
        }
    }

    extension LineItem {
        fileprivate func configure(_ text: String, qty: Decimal, rate: Decimal) {
            itemDescription = text
            quantity = qty
            self.rate = rate
        }
    }
#endif
