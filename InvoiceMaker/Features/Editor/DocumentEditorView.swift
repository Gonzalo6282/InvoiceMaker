import InvoiceKit
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
    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]
    @State private var editingLine: LineItem?
    @State private var showingClientPicker = false
    @State private var showingPreview = false

    private var actions: DocumentActions { DocumentActions(context: context) }
    private var taxes: [TaxRate] { taxRecords.map(\.taxRate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EditorHeader(document: document)
                EditorBanners(document: document, business: business, actions: actions, open: open)
                clientSection
                EditorDetailsSection(document: document, business: business)
                EditorItemsSection(document: document, business: business, taxes: taxes, actions: actions, edit: { editingLine = $0 })
                EditorTaxSection(document: document, business: business, taxes: taxes)
                EditorTotalsView(totals: document.totals(taxes: taxes), document: document, business: business)
                    .padding(.top, 12)
                notesSection
                lookSection
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.canvas)
        .navigationTitle(business.title(for: document.kind))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actionBar }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditorMoreMenu(document: document, business: business, actions: actions, open: open, close: close)
            }
        }
        .sheet(item: $editingLine) { line in
            LineItemSheet(line: line, document: document, business: business, taxes: taxes, actions: actions)
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
                .font(.system(size: 16))
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
                // Sending (Premium gate, share sheet) arrives in M7.
                showingPreview = true
            } label: {
                Text(sendTitle)
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("send")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var sendTitle: String {
        if document.kind == .receipt { return String(localized: "Send receipt") }
        return document.status == .draft ? String(localized: "Send") : String(localized: "Send again")
    }

    private func save() {
        if context.hasChanges { try? context.save() }
    }
}
