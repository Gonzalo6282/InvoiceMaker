import InvoiceKit
import SwiftData
import SwiftUI

/// Invoices / quotes / receipts with the money card, search and filters.
struct DocumentListView: View {
    let business: Business
    @Binding var kind: DocumentKind
    /// Called when the user opens or creates a document.
    var open: (Document) -> Void
    /// Highlighted row on iPad.
    var selectedID: PersistentIdentifier?

    @Environment(\.modelContext) private var context
    @Query(sort: \Document.createdAt, order: .reverse) private var documents: [Document]
    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]
    @State private var search = ""
    @State private var filter: DocumentFilter = .all

    private var taxes: [TaxRate] { taxRecords.map(\.taxRate) }

    var body: some View {
        let ofKind = documents.filter { $0.kind == kind }
        let totals = Dictionary(uniqueKeysWithValues: ofKind.map { ($0.persistentModelID, $0.totals(taxes: taxes).total) })
        let visible = ofKind.filter { doc in
            filter.matches(doc.displayStatus()) && matchesSearch(doc)
        }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                typePicker
                if kind == .invoice, !ofKind.isEmpty {
                    heroCard(for: ofKind, totals: totals)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                if ofKind.isEmpty {
                    EmptyDocumentsView(kind: kind, business: business, create: create)
                } else {
                    filterBar
                    if visible.isEmpty {
                        Text("Nothing matches. Try another filter or search.")
                            .foregroundStyle(Color.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(48)
                    } else {
                        GroupedSection {
                            ForEach(Array(visible.enumerated()), id: \.element.persistentModelID) { index, doc in
                                if index > 0 { RowDivider() }
                                Button {
                                    open(doc)
                                } label: {
                                    DocumentRow(document: doc, business: business, total: totals[doc.persistentModelID] ?? 0)
                                        .background(doc.persistentModelID == selectedID ? Color.brandWash : .clear)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { rowMenu(doc) }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle(business.pluralTitle(for: kind))
        .searchable(text: $search, prompt: Text("Search clients or numbers"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(DocumentKind.allCases, id: \.self) { k in
                        Button(String(localized: "New \(business.title(for: k).lowercased())")) { create(k) }
                    }
                } label: {
                    Label("New", systemImage: "plus")
                } primaryAction: {
                    create(kind == .receipt ? .invoice : kind)
                }
                .accessibilityIdentifier("newDocument")
            }
        }
        .onChange(of: kind) { filter = .all }
    }

    private var typePicker: some View {
        Picker("Document type", selection: $kind) {
            ForEach(DocumentKind.allCases, id: \.self) { k in
                Text(business.pluralTitle(for: k)).tag(k)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder private var filterBar: some View {
        let options = DocumentFilter.options(for: kind)
        if !options.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        Button(option.title) { filter = option }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(filter == option ? Color.brand : Color.ink2)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(filter == option ? Color.brandWash : Color.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(filter == option ? Color.brandEdge : Color.line, lineWidth: 1))
                            .accessibilityAddTraits(filter == option ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
    }

    private func heroCard(for invoices: [Document], totals: [PersistentIdentifier: Decimal]) -> some View {
        let summary = MoneySummary(
            documents: invoices.map {
                SummaryInput(
                    kind: $0.kind, status: $0.status, due: $0.dueDate, paidOn: $0.paidOn,
                    currencyCode: $0.currencyCode, total: totals[$0.persistentModelID] ?? 0)
            },
            currencyCode: business.currencyCode, today: .now)
        let others = summary.owedInOtherCurrencies.sorted { $0.key < $1.key }
            .map { business.money($0.value, currency: $0.key) }
        let month = Date.now.formatted(.dateTime.month(.wide).locale(business.locale))
        return HeroCard(
            owed: business.money(summary.owed),
            paidLabel: "Paid in \(month)",
            paid: business.money(summary.paidThisMonth),
            overdue: business.money(summary.overdue),
            hasOverdue: summary.overdue > 0,
            footnote: others.isEmpty ? nil : String(localized: "Plus \(others.joined(separator: ", ")) owed in other currencies"))
    }

    @ViewBuilder private func rowMenu(_ doc: Document) -> some View {
        let actions = DocumentActions(context: context)
        Button("Duplicate", systemImage: "plus.square.on.square") { open(actions.duplicate(doc, business: business)) }
        if doc.kind == .invoice, doc.status != .paid {
            Button("Mark as paid", systemImage: "checkmark.circle") { actions.markPaid(doc) }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { actions.delete(doc) }
    }

    private func matchesSearch(_ doc: Document) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return doc.number.localizedCaseInsensitiveContains(q) || (doc.client?.name ?? "").localizedCaseInsensitiveContains(q)
    }

    private func create(_ kind: DocumentKind) {
        let doc = DocumentActions(context: context).create(kind, business: business)
        self.kind = kind
        open(doc)
    }
}

/// First-run state for a document type (mockup `.empty`).
private struct EmptyDocumentsView: View {
    let kind: DocumentKind
    let business: Business
    let create: (DocumentKind) -> Void

    var body: some View {
        VStack(spacing: 10) {
            IconChip(systemName: kind == .receipt ? "receipt" : kind == .estimate ? "doc.text.magnifyingglass" : "doc.text", size: 64)
            Text(title).textStyle(.total).foregroundStyle(Color.ink).multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(Color.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if kind != .receipt {
                Button {
                    create(kind)
                } label: {
                    Label(String(localized: "New \(business.title(for: kind).lowercased())"), systemImage: "plus")
                }
                .buttonStyle(.primary)
                .fixedSize()
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 48)
    }

    private var title: String {
        switch kind {
        case .invoice: String(localized: "Create your first invoice")
        case .estimate: String(localized: "No \(business.pluralTitle(for: .estimate).lowercased()) yet")
        case .receipt: String(localized: "No receipts yet")
        }
    }

    private var message: String {
        kind == .receipt
            ? String(localized: "Mark an invoice as paid and send a receipt. It appears here.")
            : String(localized: "It takes about a minute. Creating and previewing is free; sending needs Premium.")
    }
}
