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
        OnboardingShell(step: step.rawValue, of: 4, showsProgress: step != .welcome) {
            content
        } footer: {
            footer
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:
            Image(systemName: "doc.richtext.fill").font(.system(size: 72)).foregroundStyle(Color.brand)
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            title("Create and send an invoice in 60 seconds")
            if region.usesQuote {
                lead("Invoices, quotes and receipts with your logo. Create free. Send with Premium.")
            } else {
                lead("Invoices, estimates and receipts with your logo. Create free. Send with Premium.")
            }
        case .role:
            title("What do you do?")
            lead("We'll pick a template and sample items to start you off.")
            ForEach(OnboardingRole.allCases) { r in
                OnboardingChoice(icon: r.icon, title: Text(r.title), detail: Text(r.detail), isSelected: role == r) { role = r }
                    .accessibilityIdentifier("role-\(r.rawValue)")
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
            Group {
                HStack(spacing: 14) {
                    Group {
                        if let logoData, let image = UIImage(data: logoData) {
                            Image(uiImage: image).resizable().scaledToFit().padding(4).background(.white)
                        } else {
                            Image(systemName: "photo").font(.title2).foregroundStyle(Color.brand)
                        }
                    }
                    .frame(width: 56, height: 56).background(Color.brandWash, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading) {
                        Text(logoData == nil ? "Add your logo" : "Logo added").font(.callout.weight(.semibold)).foregroundStyle(Color.ink)
                        Text("Optional. From Photos.").font(.footnote).foregroundStyle(Color.ink2)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
            .logoPhotoPicker(selection: $logoItem)
            .onChange(of: logoItem) {
                guard let logoItem else { return }
                Task { logoData = (try? await logoItem.loadTransferable(type: Data.self)).flatMap { LogoImage.prepare($0) } }
            }
        case .first:
            Text("Here's your first invoice").font(.title.weight(.heavy)).foregroundStyle(Color.ink)
            lead("We filled in examples. Change anything; the preview updates as you type.")
            if let draft, let business { FirstInvoiceFields(document: draft, business: business) }
        }
    }

    @ViewBuilder private var footer: some View {
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

    private func go(_ next: Step) {
        AppAnalytics.shared.log(.onboardingStep, ["step": "\(next)"])
        step = next
    }

    private func makeBusinessAndDraft() {
        let biz: Business
        let isNew: Bool
        if let existing = business ?? (try? BusinessSetup.current(in: context)) {
            biz = existing
            isNew = false
            if existing.region != region {
                existing.countryCode = region.isoCode
                existing.currencyCode = region.preset.currencyCode
                try? BusinessSetup.restorePresets(for: region, business: existing, in: context)
            }
        } else {
            biz = BusinessSetup.create(name: name, region: region, countryCode: region.isoCode, in: context)
            isNew = true
        }
        // A business restored from iCloud keeps what it has: only fill in, never blank out.
        if !name.isEmpty || biz.name.isEmpty { biz.name = name }
        if let logoData { biz.logoData = logoData }
        biz.role = (role ?? .other).rawValue
        if isNew { biz.templateID = (role ?? .other).template.rawValue }
        if biz.defaultNotes.isEmpty { biz.defaultNotes = String(localized: "Thank you for your business.") }
        business = biz
        OnboardingState.createdData = true
        if draft == nil {
            let client = Client(name: OnboardingRole.sampleClient(for: biz.region), currencyCode: biz.currencyCode)
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
        // The analytics question waits until this paywall has closed.
        PaywallService.shared.gate(.onboardingEnd, onFinished: { ConsentPrompt.shared.askIfNeeded() }) {}
    }

    private func title(_ text: LocalizedStringKey) -> some View { OnboardingTitle(text) }

    private func lead(_ text: LocalizedStringKey) -> some View { OnboardingLead(text) }

    private func field<F: View>(_ label: LocalizedStringKey, @ViewBuilder content: () -> F) -> some View {
        OnboardingField(label, field: content)
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
            Text("Client").font(.footnote.weight(.medium)).foregroundStyle(Color.ink2)
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
                Text("First item").font(.footnote.weight(.medium)).foregroundStyle(Color.ink2)
                TextField("Item", text: $line.itemDescription)
                    .padding(12).background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Price").font(.footnote.weight(.medium)).foregroundStyle(Color.ink2)
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
    /// Set once onboarding has made its business and first invoice (this launch).
    @MainActor static var createdData = false
}
