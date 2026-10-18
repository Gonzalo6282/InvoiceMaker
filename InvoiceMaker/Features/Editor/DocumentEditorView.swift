import InvoiceKit
import UniformTypeIdentifiers
import SwiftData
import SwiftUI

/// The editor: every change saves automatically (SwiftData autosave, plus an
/// explicit save when the app goes to the background or the editor closes).
struct DocumentEditorView: View {
    @Bindable var document: Document
    let business: Business
    /// Show another document (after duplicate, receipt, convert).
    var open: (Document) -> Void = { _ in }
    /// Leave the editor (after delete).
    var close: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]
    @State private var editingLine: LineItem?
    @State private var showingClientPicker = false
    @State private var showingPreview = false
    @State private var sendFlow = SendFlow()

    private var actions: DocumentActions { DocumentActions(context: context) }
    private var taxes: [TaxRate] { taxRecords.map(\.taxRate) }
    /// Taxes offered in pickers (archived ones are hidden).
    private var pickerTaxes: [TaxRate] { taxRecords.filter { !$0.isArchived }.map(\.taxRate) }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EditorHeader(document: document)
                EditorBanners(document: document, business: business, actions: actions, open: open)
                clientSection
                if sendFlow.issues.contains(.missingClient) { errorText("Add a client before sending.") }
                EditorDetailsSection(document: document, business: business)
                EditorItemsSection(document: document, business: business, taxes: taxes, actions: actions, edit: { editingLine = $0 })
                if sendFlow.issues.contains(.missingItems) { errorText("Add at least one item with a price.") }
                EditorTaxSection(document: document, business: business, taxes: pickerTaxes)
                EditorTotalsView(totals: document.totals(taxes: taxes), document: document, business: business)
                    .padding(.top, 12)
                notesSection
                lookSection
            }
            .padding(.bottom, 24)
        }
    }

    var body: some View {
        GeometryReader { geo in
            if sizeClass == .regular, geo.size.width >= 820 {
                // iPad landscape: editor (440pt) + live PDF (design-system.md).
                HStack(spacing: 0) {
                    form.frame(width: 440)
                    Rectangle().fill(Color.line).frame(width: 1)
                    LivePDFPanel(document: document, business: business, taxes: taxes)
                }
            } else {
                form
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.canvas)
        .navigationTitle(business.title(for: document.kind))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actionBar }
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button("Save", systemImage: "square.and.arrow.down") { save() }
                    .keyboardShortcut("s", modifiers: .command)
            }
            ToolbarItem(placement: .primaryAction) {
                EditorMoreMenu(
                    document: document, business: business, actions: actions, open: open, close: close,
                    print: { sendFlow.print(document, business: business, taxes: taxes) },
                    savePDF: { sendFlow.savePDF(document, business: business, taxes: taxes) })
            }
        }
        .sheet(item: $editingLine) { line in
            LineItemSheet(line: line, document: document, business: business, taxes: pickerTaxes, actions: actions)
        }
        .sheet(isPresented: $showingClientPicker) {
            ClientPickerSheet(selected: document.client) { client in
                document.client = client
                if let client { document.currencyCode = client.currencyCode }
                actions.touch(document)
            }
        }
        .navigationDestination(isPresented: $showingPreview) {
            DocumentPreviewView(document: document, business: business)
        }
        .sheet(item: $sendFlow.sharing) { pdf in
            ShareSheet(items: [PDFActivityItem(url: pdf.url, title: sendFlow.shareTitle(for: pdf))]) { completed, activity in
                sendFlow.finished(document, completed: completed, activity: activity, context: context)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $sendFlow.offeringSignIn, onDismiss: { sendFlow.continueAfterSignInOffer() }) {
            SignInOfferSheet()
        }
        .fileExporter(
            isPresented: Binding(get: { sendFlow.exporting != nil }, set: { if !$0 { sendFlow.exporting = nil } }),
            document: sendFlow.exporting, contentType: .pdf, defaultFilename: document.number
        ) { result in
            if case .success = result {
                AppAnalytics.shared.log(.pdfExported, ["method": "files", "document_type": document.kind.rawValue])
            }
        }
        .alert("Something went wrong", isPresented: Binding(get: { sendFlow.errorMessage != nil }, set: { if !$0 { sendFlow.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sendFlow.errorMessage ?? "")
        }
        .onChange(of: document.client) { if !sendFlow.issues.isEmpty { sendFlow.issues = SendValidation.check(document) } }
        .onChange(of: document.items?.count) { if !sendFlow.issues.isEmpty { sendFlow.issues = SendValidation.check(document) } }
        .onChange(of: scenePhase) { if scenePhase != .active { save() } }
        .onDisappear { save() }
    }

    private var clientSection: some View {
        GroupedSection(header: document.kind == .estimate ? "For" : "Bill to") {
            Button { showingClientPicker = true } label: {
                if let client = document.client {
                    Row(
                        verbatim: client.name,
                        meta: [client.email, client.currencyCode != business.currencyCode ? String(localized: "Billed in \(client.currencyCode)") : ""]
                            .filter { !$0.isEmpty }.joined(separator: " · "),
                        showsChevron: true)
                } else {
                    Row(icon: "person.fill", title: "Add client", titleColor: .brand)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pickClient")
        }
    }

    private var notesSection: some View {
        GroupedSection(header: "Notes") {
            TextField("Payment terms, thank-you note", text: $document.notes, axis: .vertical)
                .lineLimit(3...8)
                .font(.callout)
                .padding(14)
                .onChange(of: document.notes) { actions.touch(document) }
        }
    }

    private var lookSection: some View {
        GroupedSection(header: "Look") {
            Button { showingPreview = true } label: {
                Row(icon: "paintpalette.fill", title: "Template and colour", value: InvoiceTemplate(id: document.templateID).displayName, showsChevron: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button { showingPreview = true } label: { Label("Preview", systemImage: "eye") }
                .buttonStyle(.ghost)
                .fixedSize()
            Button {
                save()
                sendFlow.send(document, business: business, taxes: taxes, context: context)
            } label: {
                HStack(spacing: 6) {
                    if !PurchaseManager.shared.isPremium { Image(systemName: "lock.fill").font(.subheadline.weight(.bold)) }
                    Text(sendTitle)
                }
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("send")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func errorText(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.footnote).foregroundStyle(Color.due).padding(.horizontal, 20).padding(.top, 6)
            .accessibilityIdentifier("sendError")
    }

    private var sendTitle: String {
        if document.kind == .receipt { return String(localized: "Send receipt") }
        return document.status == .draft ? String(localized: "Send") : String(localized: "Send again")
    }

    private func save() {
        if context.hasChanges { try? context.save() }
    }
}
