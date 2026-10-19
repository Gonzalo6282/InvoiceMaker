import InvoiceKit
import SwiftData
import SwiftUI

/// Client list with amounts owed (mockup scrClients).
struct ClientsView: View {
    let business: Business
    let openClient: (Client) -> Void
    var selectedID: PersistentIdentifier?

    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]
    @State private var search = ""
    @State private var showingContacts = false
    @State private var contactsDenied = false
    @Environment(\.openURL) private var openURL

    /// Asks for Contacts access with the iOS pop-up first; denied → explain + Settings.
    private func importFromContacts() {
        Task {
            if await ContactAccess.request() { showingContacts = true } else { contactsDenied = true }
        }
    }

    var body: some View {
        ScrollView {
            if clients.isEmpty {
                VStack(spacing: 10) {
                    IconChip(systemName: "person.2.fill", size: 64)
                    Text("Add your first client").textStyle(.total).foregroundStyle(Color.ink)
                    Text("Type their details or pick them from your Contacts. Duly only sees the contact you choose.")
                        .foregroundStyle(Color.ink2).multilineTextAlignment(.center).frame(maxWidth: 300)
                    Button { importFromContacts() } label: { Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus") }
                        .buttonStyle(.primary).fixedSize()
                    Button("Type details", action: addNew).foregroundStyle(Color.brand)
                }
                .padding(.horizontal, 32).padding(.vertical, 48)
            } else {
                let taxes = taxRecords.map(\.taxRate)
                GroupedSection {
                    ForEach(Array(filtered.enumerated()), id: \.element.persistentModelID) { index, client in
                        if index > 0 { RowDivider() }
                        Button { openClient(client) } label: { row(client, taxes: taxes) }
                            .buttonStyle(.plain)
                            .background(client.persistentModelID == selectedID ? Color.brandWash : .clear)
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(Color.canvas)
        .navigationTitle("Clients")
        .searchable(text: $search, prompt: Text("Search clients"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Type details", systemImage: "square.and.pencil", action: addNew)
                    Button("Import from Contacts", systemImage: "person.crop.circle.badge.plus") { importFromContacts() }
                } label: { Label("Add client", systemImage: "plus") }
            }
        }
        .alert("Allow access to Contacts", isPresented: $contactsDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Duly needs access to your contacts to add a client from them. You can allow it in Settings, or type the client's details instead.")
        }
        .background(ContactPicker(isPresented: $showingContacts) { contact in
            let client = Client(currencyCode: business.currencyCode)
            client.fill(from: contact)
            context.insert(client)
            openClient(client)
        })
    }

    private var filtered: [Client] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return clients }
        return clients.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.contactName.localizedCaseInsensitiveContains(q) }
    }

    private func row(_ client: Client, taxes: [TaxRate]) -> some View {
        let owed = (client.documents ?? [])
            .filter { $0.kind == .invoice && [.sent, .overdue].contains($0.displayStatus()) }
            .reduce(Decimal(0)) { $0 + $1.totals(taxes: taxes).total }
        let meta = [client.contactName.isEmpty ? client.email : client.contactName,
                    client.currencyCode != business.currencyCode ? client.currencyCode : ""]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        return HStack(spacing: 12) {
            Avatar(name: client.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: client.name.isEmpty ? String(localized: "New client") : client.name)
                    .font(.callout.weight(.semibold)).foregroundStyle(Color.ink)
                if !meta.isEmpty { Text(verbatim: meta).font(.footnote).foregroundStyle(Color.ink2).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if owed > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(business.money(owed, currency: client.currencyCode)).font(.subheadline.weight(.bold)).monospacedDigit()
                    Text("owed").font(.caption).foregroundStyle(Color.ink2)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func addNew() {
        let client = Client(currencyCode: business.currencyCode)
        context.insert(client)
        openClient(client)
    }
}

/// Currencies offered for clients (mockup list).
enum CurrencyChoices {
    static let codes = ["GBP", "EUR", "USD", "AUD", "CAD", "NZD", "CHF", "JPY"]
}
