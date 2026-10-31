#if DEBUG
    import Foundation
    import InvoiceKit
    import SwiftData
    import UIKit

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

        /// `screenshots`: adds a logo, signatures, an accepted estimate and a
        /// receipt for the App Store screenshots (UI test, `-demoData`).
        /// `region: .us` seeds a US electrician ($, sales tax, estimates) for the US App Store set.
        static func seed(_ context: ModelContext, today: Date = .now, screenshots: Bool = false, region: Region = .uk) {
            seedRegion(context, today: today, screenshots: screenshots, region: region)
            if screenshots { attachDemoPhotos(context, region: region) }
        }

        /// Job photos on the first finished invoice (INV-0007 / RE-0007 / FAC-0007) for the
        /// App Store screenshots. The JPEGs come from the folder in DEMO_PHOTOS_DIR
        /// (set by the AppStoreScreenshots UI test): `<region>-*.jpg`, e.g. `uk-1.jpg`.
        static func attachDemoPhotos(_ context: ModelContext, region: Region) {
            guard let path = ProcessInfo.processInfo.environment["DEMO_PHOTOS_DIR"], !path.isEmpty else { return }
            let dir = URL(fileURLWithPath: path)
            let prefix = region.rawValue.lowercased() + "-"
            let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.lastPathComponent.lowercased().hasPrefix(prefix) && $0.pathExtension.lowercased() == "jpg" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard !files.isEmpty,
                let invoice = ((try? context.fetch(FetchDescriptor<Document>())) ?? [])
                    .first(where: { $0.kindRaw == DocumentKind.invoice.rawValue && $0.number.hasSuffix("0007") })
            else { return }
            for (position, file) in files.prefix(4).enumerated() {
                guard let data = try? Data(contentsOf: file), let jpeg = JobPhotoImage.prepare(data) else { continue }
                let photo = JobPhoto(position: position, imageData: jpeg)
                context.insert(photo)
                photo.document = invoice
            }
        }

        private static func seedRegion(_ context: ModelContext, today: Date, screenshots: Bool, region: Region) {
            if region == .us {
                seedUS(context, today: today, screenshots: screenshots)
                return
            }
            if region == .de || region == .fr {
                seedEU(context, region: region, today: today, screenshots: screenshots)
                return
            }
            if region == .au || region == .ca {
                seedAUCA(context, region: region, today: today, screenshots: screenshots)
                return
            }
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

            guard screenshots else { return }
            biz.logoData = DemoArt.logo(initials: "KJ")
            biz.signatureData = DemoArt.signature()
            e.job = "Ostara Café, 8 Gloucester Road — bar refit"
            if let signature = DemoArt.signature() { actions.recordClientSignature(e, image: signature, name: "Jonas Berg") }
            _ = actions.makeReceipt(for: c, business: biz)
        }
    }

    extension DemoData {
        /// Summit Electric Co., Austin TX: the US screenshot business.
        static func seedUS(_ context: ModelContext, today: Date, screenshots: Bool) {
            let cal = Calendar.current
            func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today) ?? today }

            let biz = BusinessSetup.create(name: "Summit Electric Co.", region: .us, countryCode: "US", in: context)
            biz.role = "contractor"
            biz.email = "hello@summitelectric.co"
            biz.phone = "(512) 555-0148"
            biz.address = "4120 Burnet Rd\nAustin, TX 78756"
            biz.taxRegistered = true
            biz.defaultNotes = "Thank you for your business. Payment due within 14 days."
            biz.nextInvoiceNumber = 7
            biz.nextEstimateNumber = 3
            biz.payment?.payPalMe = "paypal.me/summitelectric"
            biz.payment?.venmo = "@summit-electric"
            biz.payment?.zelle = "pay@summitelectric.co"
            let tax = biz.defaultTaxID ?? "us-sales"

            let oakridge = Client(name: "Oakridge Landscaping", currencyCode: "USD")
            oakridge.contactName = "Dana Ruiz"
            oakridge.email = "dana@oakridgelandscaping.com"
            oakridge.address = "88 Riverside Dr\nAustin, TX 78704"
            let harbor = Client(name: "Harbor Street Café", currencyCode: "USD")
            harbor.contactName = "Mateo Silva"
            harbor.email = "mateo@harborstreetcafe.com"
            let lund = Client(name: "Lund Design Studio", currencyCode: "EUR")
            lund.email = "hej@lunddesign.dk"
            [oakridge, harbor, lund].forEach(context.insert)

            context.insert(SavedItem(itemDescription: "Electrician labor", unit: "hour", rate: 95, taxID: tax))
            context.insert(SavedItem(itemDescription: "Panel upgrade, 200A", unit: "job", rate: 1850, taxID: tax))

            let actions = DocumentActions(context: context, now: { today })
            let a = actions.create(.invoice, business: biz, client: oakridge)
            actions.addLineItem(to: a, defaultTaxID: tax).configure("EV charger, installed", qty: 1, rate: 1250)
            actions.addLineItem(to: a, defaultTaxID: tax).configure("Permit and inspection", qty: 1, rate: 175)
            actions.markSent(a)

            let b = actions.create(.invoice, business: biz, client: harbor)
            b.issueDate = day(-30)
            b.dueDate = day(-16)
            actions.addLineItem(to: b, defaultTaxID: tax).configure("Lighting repair", qty: 1, rate: 480)
            actions.markSent(b)

            let c = actions.create(.invoice, business: biz, client: oakridge)
            actions.addLineItem(to: c, defaultTaxID: tax).configure("Outdoor lighting design", qty: 1, rate: 600)
            actions.markSent(c)
            actions.markPaid(c, on: today)

            let d = actions.create(.invoice, business: biz, client: lund)
            actions.addLineItem(to: d, defaultTaxID: nil).configure("Shop-fit consultation", qty: 1, rate: 1200)
            actions.markSent(d)

            actions.create(.invoice, business: biz, client: harbor)

            let e = actions.create(.estimate, business: biz, client: harbor)
            actions.addLineItem(to: e, defaultTaxID: tax).configure("Kitchen rewiring", qty: 1, rate: 3400)

            guard screenshots else { return }
            biz.logoData = DemoArt.logo(initials: "SE")
            biz.signatureData = DemoArt.signature()
            e.job = "Harbor Street Café, 214 Harbor St — kitchen rewiring"
            if let signature = DemoArt.signature() { actions.recordClientSignature(e, image: signature, name: "Mateo Silva") }
            _ = actions.makeReceipt(for: c, business: biz)
        }
    }

    extension DemoData {
        /// Australian (Sydney electrician, GST, "Tax invoice", quotes) and
        /// Canadian (Toronto plumber, Ontario HST, estimates) screenshot businesses.
        static func seedAUCA(_ context: ModelContext, region: Region, today: Date, screenshots: Bool) {
            let cal = Calendar.current
            func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today) ?? today }
            let au = region == .au
            let biz = BusinessSetup.create(
                name: au ? "Banksia Electrical" : "Northline Plumbing", region: region, countryCode: au ? "AU" : "CA", in: context)
            biz.role = "contractor"
            biz.email = au ? "jobs@banksiaelectrical.com.au" : "hello@northlineplumbing.ca"
            biz.phone = au ? "0491 570 006" : "(416) 555-0182"
            biz.address = au ? "14 Wattle Street\nMarrickville NSW 2204" : "220 Queen St E\nToronto ON M5A 1S3"
            biz.taxID = au ? "51 824 753 556" : "123456789 RT0001"
            biz.taxRegistered = true
            if !au { biz.defaultTaxID = "ca-hst13" }  // Ontario
            biz.defaultNotes = au
                ? "Thanks for your business. Payment within 14 days, please."
                : "Thank you for your business. Payment due within 14 days."
            biz.nextInvoiceNumber = 7
            biz.nextEstimateNumber = 3
            biz.payment?.bankName = au ? "Banksia Electrical Pty Ltd" : "Northline Plumbing Inc."
            biz.payment?.sortCode = au ? "062-000" : "00012-004"
            biz.payment?.accountNumber = au ? "1234 5678" : "1234567"
            biz.payment?.payPalMe = au ? "paypal.me/banksiaelectrical" : "paypal.me/northlineplumbing"
            let tax = biz.defaultTaxID

            let first = Client(name: OnboardingRole.sampleClient(for: region), currencyCode: au ? "AUD" : "CAD")
            first.contactName = au ? "Mia Nguyen" : "Ethan Clarke"
            first.email = au ? "mia@harboursidecafe.com.au" : "ethan@mapleridgebuilders.ca"
            first.address = au ? "3 Circular Quay\nSydney NSW 2000" : "88 King St W\nToronto ON M5H 1A1"
            let second = Client(name: au ? "Coastline Builders" : "Lakeshore Café", currencyCode: au ? "AUD" : "CAD")
            second.contactName = au ? "Jack Turner" : "Sofia Romano"
            second.email = au ? "jack@coastlinebuilders.com.au" : "sofia@lakeshorecafe.ca"
            let abroad = au ? Client(name: "Kauri Design Studio", currencyCode: "NZD") : Client(name: "Lund Design Studio", currencyCode: "USD")
            abroad.email = au ? "kia.ora@kauridesign.co.nz" : "hello@lunddesign.com"
            [first, second, abroad].forEach(context.insert)

            context.insert(SavedItem(itemDescription: au ? "Labour" : "Labour", unit: "hour", rate: au ? 95 : 110, taxID: tax))

            let actions = DocumentActions(context: context, now: { today })
            let a = actions.create(.invoice, business: biz, client: first)
            actions.addLineItem(to: a, defaultTaxID: tax)
                .configure(au ? "Switchboard upgrade, installed" : "Water heater, installed", qty: 1, rate: au ? 1450 : 1680)
            actions.addLineItem(to: a, defaultTaxID: tax).configure(au ? "Call-out fee" : "Service call", qty: 1, rate: au ? 120 : 140)
            actions.markSent(a)

            let b = actions.create(.invoice, business: biz, client: second)
            b.issueDate = day(-30)
            b.dueDate = day(-16)
            actions.addLineItem(to: b, defaultTaxID: tax).configure(au ? "Site power, temporary" : "Leak repair", qty: 1, rate: au ? 680 : 520)
            actions.markSent(b)

            let c = actions.create(.invoice, business: biz, client: first)
            actions.addLineItem(to: c, defaultTaxID: tax).configure(au ? "Lighting plan" : "Drain inspection", qty: 1, rate: au ? 600 : 450)
            actions.markSent(c)
            actions.markPaid(c, on: today)

            let d = actions.create(.invoice, business: biz, client: abroad)
            actions.addLineItem(to: d, defaultTaxID: nil).configure(au ? "Fit-out consultation" : "Plumbing consultation", qty: 1, rate: 1200)
            actions.markSent(d)

            actions.create(.invoice, business: biz, client: second)

            let e = actions.create(.estimate, business: biz, client: second)
            actions.addLineItem(to: e, defaultTaxID: tax).configure(au ? "Rewire, two-storey house" : "Bathroom rough-in", qty: 1, rate: au ? 8900 : 4200)

            guard screenshots else { return }
            biz.logoData = DemoArt.logo(initials: au ? "BE" : "NP")
            biz.signatureData = DemoArt.signature()
            e.job = au ? "12 Ocean Ave, Bondi — rewire" : "41 Beech Ave, The Beaches — bathroom"
            if let signature = DemoArt.signature() { actions.recordClientSignature(e, image: signature, name: au ? "Jack Turner" : "Sofia Romano") }
            _ = actions.makeReceipt(for: c, business: biz)
        }

        /// German and French screenshot businesses (v1.1): a joiner in Hamburg
        /// or Lyon, euros, local VAT, IBAN and PayPal, local numbering.
        static func seedEU(_ context: ModelContext, region: Region, today: Date, screenshots: Bool) {
            let cal = Calendar.current
            func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today) ?? today }
            let german = region == .de
            let biz = BusinessSetup.create(
                name: german ? "Tischlerei Falk" : "Menuiserie Martin", region: region,
                countryCode: german ? "DE" : "FR", in: context)
            biz.role = "contractor"
            biz.email = german ? "info@tischlerei-falk.de" : "contact@menuiserie-martin.fr"
            biz.phone = german ? "040 5550 1234" : "04 72 55 01 23"
            biz.address = german ? "Holstenstraße 12\n22767 Hamburg" : "12 rue Paul Bert\n69003 Lyon"
            biz.taxID = german ? "DE 123 456 789" : "FR 12 345678901"
            biz.taxRegistered = true
            biz.defaultNotes = german
                ? "Vielen Dank für Ihren Auftrag. Bitte zahlen Sie innerhalb von 14 Tagen."
                : "Merci pour votre confiance. Paiement à 14 jours."
            biz.invoicePrefix = german ? "RE-" : "FAC-"
            biz.estimatePrefix = german ? "AN-" : "DEV-"
            biz.receiptPrefix = german ? "QU-" : "REC-"
            biz.nextInvoiceNumber = 7
            biz.nextEstimateNumber = 3
            biz.payment?.bankName = german ? "Tischlerei Falk" : "Menuiserie Martin"
            biz.payment?.iban = german ? "DE89 3704 0044 0532 0130 00" : "FR76 3000 6000 0112 3456 7890 189"
            biz.payment?.swift = german ? "COBADEFFXXX" : "AGRIFRPP"
            biz.payment?.payPalMe = german ? "paypal.me/tischlereifalk" : "paypal.me/menuiseriemartin"
            let tax = biz.defaultTaxID

            let first = Client(name: OnboardingRole.sampleClient(for: region), currencyCode: "EUR")
            first.contactName = german ? "Anna Weber" : "Claire Morel"
            first.email = german ? "anna.weber@lindenhof-gartenbau.de" : "claire@boulangerie-tilleuls.fr"
            first.address = german ? "Lindenallee 4\n22299 Hamburg" : "8 place des Tilleuls\n69006 Lyon"
            let cafe = Client(name: german ? "Café Elbblick" : "Café du Rhône", currencyCode: "EUR")
            cafe.contactName = german ? "Lukas Brandt" : "Julien Faure"
            cafe.email = german ? "lukas@cafe-elbblick.de" : "julien@cafedurhone.fr"
            let uk = Client(name: "Marlow & Finch Ltd", currencyCode: "GBP")
            uk.email = "priya@marlowfinch.co.uk"
            [first, cafe, uk].forEach(context.insert)

            let hour = german ? "Stunde" : "heure"
            context.insert(SavedItem(itemDescription: german ? "Arbeitszeit" : "Main-d'œuvre", unit: hour, rate: 55, taxID: tax))
            context.insert(SavedItem(itemDescription: german ? "Eichenplatte, montiert" : "Plan de travail chêne, posé", unit: "m", rate: 190, taxID: tax))

            let actions = DocumentActions(context: context, now: { today })
            let a = actions.create(.invoice, business: biz, client: first)
            actions.addLineItem(to: a, defaultTaxID: tax)
                .configure(german ? "Einbauschrank nach Maß, montiert" : "Placard sur mesure, posé", qty: 1, rate: 1180)
            actions.addLineItem(to: a, defaultTaxID: tax).configure(german ? "Aufmaß vor Ort" : "Prise de mesures sur place", qty: 1, rate: 65)
            actions.markSent(a)

            let b = actions.create(.invoice, business: biz, client: cafe)
            b.issueDate = day(-30)
            b.dueDate = day(-16)
            actions.addLineItem(to: b, defaultTaxID: tax).configure(german ? "Reparatur Tresen" : "Réparation du comptoir", qty: 1, rate: 540)
            actions.markSent(b)

            let c = actions.create(.invoice, business: biz, client: first)
            actions.addLineItem(to: c, defaultTaxID: tax).configure(german ? "Planung Gartenhaus" : "Plans de l'abri de jardin", qty: 1, rate: 600)
            actions.markSent(c)
            actions.markPaid(c, on: today)

            let d = actions.create(.invoice, business: biz, client: uk)
            actions.addLineItem(to: d, defaultTaxID: nil).configure(german ? "Beratung Ladenbau" : "Conseil agencement de boutique", qty: 1, rate: 1200)
            actions.markSent(d)

            actions.create(.invoice, business: biz, client: cafe)

            let e = actions.create(.estimate, business: biz, client: cafe)
            actions.addLineItem(to: e, defaultTaxID: tax).configure(german ? "Neuer Tresen aus Eiche" : "Nouveau comptoir en chêne", qty: 1, rate: 2350)

            guard screenshots else { return }
            biz.logoData = DemoArt.logo(initials: german ? "TF" : "MM")
            biz.signatureData = DemoArt.signature()
            e.job = german ? "Café Elbblick, Elbchaussee 20 — Tresen" : "Café du Rhône, 3 quai Augagneur — comptoir"
            if let signature = DemoArt.signature() { actions.recordClientSignature(e, image: signature, name: german ? "Lukas Brandt" : "Julien Faure") }
            _ = actions.makeReceipt(for: c, business: biz)
        }
    }

    /// Drawn demo artwork (no image files in the repo).
    enum DemoArt {
        static func logo(initials: String) -> Data? {
            UIGraphicsImageRenderer(size: CGSize(width: 360, height: 360)).image { _ in
                let navy = UIColor(red: 0.04, green: 0.15, blue: 0.25, alpha: 1)
                navy.setFill()
                UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 360, height: 360), cornerRadius: 80).fill()
                // A kestrel's wing: two strokes.
                let wing = UIBezierPath()
                wing.move(to: CGPoint(x: 70, y: 210))
                wing.addQuadCurve(to: CGPoint(x: 290, y: 120), controlPoint: CGPoint(x: 170, y: 90))
                wing.addQuadCurve(to: CGPoint(x: 180, y: 230), controlPoint: CGPoint(x: 230, y: 200))
                wing.close()
                UIColor(red: 0.85, green: 0.55, blue: 0.25, alpha: 1).setFill()
                wing.fill()
                let text = NSAttributedString(string: initials, attributes: [
                    .font: UIFont.systemFont(ofSize: 96, weight: .heavy), .foregroundColor: UIColor.white,
                ])
                text.draw(at: CGPoint(x: 112, y: 222))
            }.pngData()
        }

        static func signature() -> Data? {
            UIGraphicsImageRenderer(size: CGSize(width: 600, height: 200)).image { _ in
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 30, y: 140))
                path.addCurve(to: CGPoint(x: 160, y: 60), controlPoint1: CGPoint(x: 60, y: 20), controlPoint2: CGPoint(x: 120, y: 180))
                path.addCurve(to: CGPoint(x: 300, y: 120), controlPoint1: CGPoint(x: 200, y: 10), controlPoint2: CGPoint(x: 240, y: 170))
                path.addCurve(to: CGPoint(x: 450, y: 80), controlPoint1: CGPoint(x: 350, y: 60), controlPoint2: CGPoint(x: 400, y: 150))
                path.addCurve(to: CGPoint(x: 570, y: 110), controlPoint1: CGPoint(x: 490, y: 30), controlPoint2: CGPoint(x: 530, y: 140))
                path.lineWidth = 7
                path.lineCapStyle = .round
                UIColor(red: 0.06, green: 0.1, blue: 0.3, alpha: 1).setStroke()
                path.stroke()
            }.pngData()
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
