import InvoiceKit
import PhotosUI
import SwiftData
import SwiftUI

/// Welcome → role → business → first invoice (live preview) → soft paywall.
/// (The analytics consent question, for UK/EEA, is asked before this.)
struct OnboardingView: View {
    let finish: (Document) -> Void

    @Environment(\.modelContext) private var context
    @State private var step: Step = .welcome
    @State private var role: OnboardingRole?
    @State private var name = ""
    @State private var region: Region = Region.resolve(countryCode: Locale.current.region?.identifier)
    @State private var logoItem: PhotosPickerItem?
    @State private var logoData: Data?
    @State private var business: Business?
    @State private var draft: Document?

    enum Step: Int { case welcome = 1, role, business, first }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if step != .welcome { dots }
                    content
                }
                .padding(24)
            }
            footer
        }
        .background(Color.canvas)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { i in
                Capsule().fill(i == step.rawValue ? Color.brand : Color.line).frame(width: i == step.rawValue ? 18 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:
            Image(systemName: "doc.richtext.fill").font(.system(size: 72)).foregroundStyle(Color.brand)
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            title("Create and send an invoice in 60 seconds")
            lead("Invoices, \(region == .uk ? String(localized: "quotes") : String(localized: "estimates")) and receipts with your logo. Create free. Send with Premium.")
        case .role:
            title("What do you do?")
            lead("We'll pick a template and sample items to start you off.")
            ForEach(OnboardingRole.allCases) { r in
                Button { role = r } label: {
                    HStack(spacing: 14) {
                        IconChip(systemName: r.icon, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.ink)
                            Text(r.detail).font(.system(size: 14)).foregroundStyle(Color.ink2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(role == r ? Color.brand : Color.line, lineWidth: role == r ? 2 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("role-\(r.rawValue)")
                .accessibilityAddTraits(role == r ? .isSelected : [])
            }
        case .business:
            title("Your business")
            lead("This goes at the top of every invoice. You can change it later.")
            field("Business name") {
                TextField("e.g. Kestrel Joinery", text: $name).textContentType(.organizationName)
                    .accessibilityIdentifier("onboardingBusinessName")
            }
            field("Country") {
                Picker("Country", selection: $region) {
                    ForEach(Region.allCases, id: \.self) { Text($0.countryName).tag($0) }
                }
                .labelsHidden()
            }
            PhotosPicker(selection: $logoItem, matching: .images) {
                HStack(spacing: 14) {
                    Group {
                        if let logoData, let image = UIImage(data: logoData) {
                            Image(uiImage: image).resizable().scaledToFit().padding(4).background(.white)
                        } else {
                            Image(systemName: "photo").font(.system(size: 24)).foregroundStyle(Color.brand)
                        }
                    }
                    .frame(width: 56, height: 56).background(Color.brandWash, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading) {
                        Text(logoData == nil ? "Add your logo" : "Logo added").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink)
                        Text("Optional. From Photos.").font(.system(size: 13)).foregroundStyle(Color.ink2)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
            .buttonStyle(.plain)
            .onChange(of: logoItem) {
                guard let logoItem else { return }
                Task { logoData = (try? await logoItem.loadTransferable(type: Data.self)).flatMap { LogoImage.prepare($0) } }
            }
        case .first:
            Text("Here's your first invoice").font(.system(size: 28, weight: .heavy)).foregroundStyle(Color.ink)
            lead("We filled in examples. Change anything; the preview updates as you type.")
            if let draft, let business { FirstInvoiceFields(document: draft, business: business) }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            switch step {
            case .welcome:
                Button("Get started") { go(.role) }.buttonStyle(.primary).accessibilityIdentifier("onboardingNext")
            case .role:
                Button("Continue") { go(.business) }.buttonStyle(.primary).disabled(role == nil).accessibilityIdentifier("onboardingNext")
                Button("Back") { step = .welcome }.foregroundStyle(Color.brand)
            case .business:
                Button("Continue") { makeBusinessAndDraft() }.buttonStyle(.primary).accessibilityIdentifier("onboardingNext")
                Button("Skip for now") { name = ""; makeBusinessAndDraft() }.foregroundStyle(Color.brand)
            case .first:
                Button("Looks good") { complete() }.buttonStyle(.primary).accessibilityIdentifier("onboardingDone")
            }
        }
        .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 12)
        .background(.bar)
    }

    private func go(_ next: Step) {
        AppAnalytics.shared.log(.onboardingStep, ["step": "\(next)"])
        step = next
    }

    private func makeBusinessAndDraft() {
        let biz: Business
        if let existing = business ?? (try? BusinessSetup.current(in: context)) {
            biz = existing
            if existing.region != region {
                existing.countryCode = region.isoCode
                existing.currencyCode = region.preset.currencyCode
                try? BusinessSetup.restorePresets(for: region, business: existing, in: context)
            }
        } else {
            biz = BusinessSetup.create(name: name, region: region, countryCode: region.isoCode, in: context)
        }
        biz.name = name
        biz.role = (role ?? .other).rawValue
        biz.logoData = logoData
        biz.templateID = (role ?? .other).template.rawValue
        biz.defaultNotes = String(localized: "Thank you for your business.")
        business = biz
        if draft == nil {
            let client = Client(name: (role ?? .other).sampleClient, currencyCode: biz.currencyCode)
            context.insert(client)
            let actions = DocumentActions(context: context)
            let doc = actions.create(.invoice, business: biz, client: client)
            for (desc, qty, rate, unit) in (role ?? .other).sampleItems {
                let line = actions.addLineItem(to: doc, defaultTaxID: biz.taxRegistered ? biz.defaultTaxID : nil)
                line.itemDescription = desc
                line.quantity = qty
                line.rate = rate
                line.unit = unit
            }
            draft = doc
        }
        go(.first)
    }

    private func complete() {
        guard let draft else { return }
        try? context.save()
        AppAnalytics.shared.log(.invoiceCreated, ["source": "onboarding"])
        AppAnalytics.shared.log(.onboardingComplete, ["role": (role ?? .other).rawValue])
        OnboardingState.markDone()
        finish(draft)
        // Soft paywall: closable; Premium isn't needed to keep going.
        PaywallService.shared.gate(.onboardingEnd) {}
    }

    private func title(_ text: LocalizedStringKey) -> some View {
        Text(text).textStyle(.largeTitle).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
    }

    private func lead(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.system(size: 17)).foregroundStyle(Color.ink2).fixedSize(horizontal: false, vertical: true)
    }

    private func field<F: View>(_ label: LocalizedStringKey, @ViewBuilder content: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink2)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line))
        }
    }
}

/// Client, first item and price, with a live PDF preview (watermarked).
private struct FirstInvoiceFields: View {
    @Bindable var document: Document
    let business: Business
    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let client = document.client {
                ClientNameField(client: client)
            }
            if let line = document.sortedItems.first {
                FirstLineFields(line: line)
            }
            if let image = preview {
                Image(uiImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                    .padding(.top, 4)
                    .accessibilityLabel(Text("Preview of your first invoice"))
            }
        }
    }

    private var preview: UIImage? {
        let model = InvoicePDFModelBuilder(watermark: !PurchaseManager.shared.isPremium)
            .build(document: document, business: business, taxes: taxRecords.map(\.taxRate))
        return PDFRenderer(model: model).renderFirstPageImage(width: 600)
    }
}

private struct ClientNameField: View {
    @Bindable var client: Client
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Client").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink2)
            TextField("Client name", text: $client.name)
                .padding(12).background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line))
        }
    }
}

private struct FirstLineFields: View {
    @Bindable var line: LineItem
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("First item").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink2)
                TextField("Item", text: $line.itemDescription)
                    .padding(12).background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Price").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink2)
                DecimalField("0.00", value: $line.rate)
                    .padding(12).background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line))
            }
            .frame(width: 110)
        }
    }
}

enum OnboardingState {
    static let key = "onboardingDone"
    static var isDone: Bool { UserDefaults.standard.bool(forKey: key) }
    static func markDone() { UserDefaults.standard.set(true, forKey: key) }
}
