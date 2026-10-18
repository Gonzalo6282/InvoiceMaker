import InvoiceKit
import SwiftData
import SwiftUI

/// Tabs on iPhone (and iPad in a narrow window); sidebar + list + detail on iPad.
struct AppShell: View {
    let business: Business
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            SplitShell(business: business)
        } else {
            TabShell(business: business)
        }
    }
}

enum AppSection: Hashable {
    case documents(DocumentKind)
    case clients
    case items
    case settings
}

// MARK: - iPhone

private struct TabShell: View {
    let business: Business
    @State private var tab: Tab = .documents
    @State private var kind: DocumentKind = .invoice
    @State private var path: [PersistentIdentifier] = []

    enum Tab { case documents, clients, items, settings }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $path) {
                DocumentListView(business: business, kind: $kind, open: { path = [$0.persistentModelID] })
                    .navigationDestination(for: PersistentIdentifier.self) { id in
                        DocumentDetailHost(id: id, business: business)
                    }
            }
            .tabItem { Label("Invoices", systemImage: "doc.text") }
            .tag(Tab.documents)

            NavigationStack { SectionPlaceholder(title: "Clients", message: "Coming in the next build step.") }
                .tabItem { Label("Clients", systemImage: "person.2") }
                .tag(Tab.clients)

            NavigationStack { SectionPlaceholder(title: "Items", message: "Coming in the next build step.") }
                .tabItem { Label("Items", systemImage: "tag") }
                .tag(Tab.items)

            NavigationStack { SectionPlaceholder(title: "Settings", message: "Coming in the next build step.") }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Color.brand)
    }
}

// MARK: - iPad

private struct SplitShell: View {
    let business: Business
    @State private var section: AppSection? = .documents(.invoice)
    @State private var kind: DocumentKind = .invoice
    @State private var selectedID: PersistentIdentifier?
    @State private var visibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            List(selection: $section) {
                ForEach(DocumentKind.allCases, id: \.self) { k in
                    Label(business.pluralTitle(for: k), systemImage: icon(for: k)).tag(AppSection.documents(k))
                }
                Label("Clients", systemImage: "person.2").tag(AppSection.clients)
                Label("Items", systemImage: "tag").tag(AppSection.items)
                Label("Settings", systemImage: "gearshape").tag(AppSection.settings)
            }
            .navigationTitle("Duly")
        } content: {
            switch section {
            case .documents, .none:
                DocumentListView(business: business, kind: $kind, open: { selectedID = $0.persistentModelID }, selectedID: selectedID)
            case .clients:
                SectionPlaceholder(title: "Clients", message: "Coming in the next build step.")
            case .items:
                SectionPlaceholder(title: "Items", message: "Coming in the next build step.")
            case .settings:
                SectionPlaceholder(title: "Settings", message: "Coming in the next build step.")
            }
        } detail: {
            if let selectedID {
                NavigationStack {
                    DocumentDetailHost(id: selectedID, business: business)
                }
                .id(selectedID)
            } else {
                SectionPlaceholder(title: "", message: String(localized: "Choose an invoice, or press ⌘N to create one"))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Color.brand)
        .onChange(of: section) {
            if case .documents(let k) = section { kind = k }
        }
        .onChange(of: kind) {
            if case .documents = section { section = .documents(kind) }
        }
    }

    private func icon(for kind: DocumentKind) -> String {
        switch kind {
        case .invoice: "doc.text"
        case .estimate: "doc.text.magnifyingglass"
        case .receipt: "receipt"
        }
    }
}

// MARK: - Shared

/// Loads a document by id so navigation survives the document being deleted.
struct DocumentDetailHost: View {
    let id: PersistentIdentifier
    let business: Business
    @Environment(\.modelContext) private var context

    var body: some View {
        if let doc = context.model(for: id) as? Document, !doc.isDeleted {
            DocumentEditorView(document: doc, business: business)
        } else {
            SectionPlaceholder(title: "", message: String(localized: "This document was deleted."))
        }
    }
}

struct SectionPlaceholder: View {
    let title: LocalizedStringKey
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(Color.ink3)
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvas)
            .navigationTitle(title)
    }
}
