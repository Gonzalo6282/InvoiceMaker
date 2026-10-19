import InvoiceKit
import SwiftData
import SwiftUI

/// Tabs on iPhone (and iPad in a narrow window); sidebar + list + detail on iPad.
struct AppShell: View {
    let business: Business
    /// Opened right away (the invoice made during onboarding).
    var initialDocument: PersistentIdentifier?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            SplitShell(business: business, documentID: initialDocument)
        } else {
            TabShell(business: business, path: initialDocument.map { [$0] } ?? [])
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
    @Environment(\.modelContext) private var context
    let business: Business
    @State private var tab: Tab = .documents
    @State private var kind: DocumentKind = .invoice
    @State var path: [PersistentIdentifier] = []
    @State private var clientPath: [PersistentIdentifier] = []

    enum Tab { case documents, clients, items, settings }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $path) {
                DocumentListView(business: business, kind: $kind, open: { path = [stableID($0, in: context)] })
                    .navigationDestination(for: PersistentIdentifier.self) { id in
                        DocumentDetailHost(
                            id: id, business: business,
                            open: { path = [stableID($0, in: context)] },
                            close: { path = [] })
                    }
            }
            .tabItem { Label("Invoices", systemImage: "doc.text") }
            .tag(Tab.documents)

            NavigationStack(path: $clientPath) {
                ClientsView(business: business, openClient: { clientPath = [stableID($0, in: context)] })
                    .navigationDestination(for: PersistentIdentifier.self) { id in
                        ClientDetailHost(
                            id: id, business: business,
                            openDocument: { doc in
                                kind = doc.kind
                                path = [stableID(doc, in: context)]
                                tab = .documents
                            },
                            close: { clientPath = [] })
                    }
            }
            .tabItem { Label("Clients", systemImage: "person.2") }
            .tag(Tab.clients)

            NavigationStack { ItemsView(business: business) }
                .tabItem { Label("Items", systemImage: "tag") }
                .tag(Tab.items)

            NavigationStack { SettingsView(business: business) }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Color.brand)
    }
}

// MARK: - iPad

private struct SplitShell: View {
    @Environment(\.modelContext) private var context
    let business: Business
    @State private var section: AppSection? = .documents(.invoice)
    @State private var kind: DocumentKind = .invoice
    @State var documentID: PersistentIdentifier?
    @State private var clientID: PersistentIdentifier?
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
                DocumentListView(business: business, kind: $kind, open: { documentID = stableID($0, in: context) }, selectedID: documentID)
            case .clients:
                ClientsView(business: business, openClient: { clientID = stableID($0, in: context) }, selectedID: clientID)
            case .items:
                ItemsView(business: business)
            case .settings:
                NavigationStack { SettingsView(business: business) }
            }
        } detail: {
            detail
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

    @ViewBuilder private var detail: some View {
        switch section {
        case .clients:
            if let clientID {
                NavigationStack {
                    ClientDetailHost(
                        id: clientID, business: business,
                        openDocument: { doc in
                            documentID = stableID(doc, in: context)
                            section = .documents(doc.kind)
                        },
                        close: { self.clientID = nil })
                }
                .id(clientID)
            } else {
                SectionPlaceholder(title: "", message: String(localized: "Choose a client"))
            }
        case .documents, .none:
            if let documentID {
                NavigationStack {
                    DocumentDetailHost(
                        id: documentID, business: business,
                        open: { self.documentID = stableID($0, in: context) },
                        close: { self.documentID = nil })
                }
                .id(documentID)
            } else {
                SectionPlaceholder(title: "", message: String(localized: "Choose an invoice, or press ⌘N to create one"))
            }
        case .items, .settings:
            SectionPlaceholder(title: "", message: "")
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
    var open: (Document) -> Void = { _ in }
    var close: () -> Void = {}
    @Environment(\.modelContext) private var context

    var body: some View {
        if let doc = context.model(for: id) as? Document, !doc.isDeleted {
            DocumentEditorView(document: doc, business: business, open: open, close: close)
        } else {
            SectionPlaceholder(title: "", message: String(localized: "This document was deleted."))
        }
    }
}

struct ClientDetailHost: View {
    let id: PersistentIdentifier
    let business: Business
    let openDocument: (Document) -> Void
    let close: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        if let client = context.model(for: id) as? Client, !client.isDeleted {
            ClientDetailView(client: client, business: business, openDocument: openDocument, close: close)
        } else {
            SectionPlaceholder(title: "", message: String(localized: "Choose a client"))
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

extension View {
    /// The ID to keep for navigation. A just-created model has a temporary ID
    /// that SwiftData swaps for a permanent one on the next save, after which
    /// the temporary ID points at nothing (crash on iPad, 19 Oct); save first.
    @MainActor
    func stableID(_ model: some PersistentModel, in context: ModelContext) -> PersistentIdentifier {
        if context.hasChanges { try? context.save() }
        return model.persistentModelID
    }
}
