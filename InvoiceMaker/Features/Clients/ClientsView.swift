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

    var body: some View {
        ScrollView {
            if clients.isEmpty {
                VStack(spacing: 10) {
                    IconChip(systemName: "person.2.fill", size: 64)
                    Text("Add your first client").textStyle(.total).foregroundStyle(Color.ink)
                    Text("Type their details or pick them from your Contacts. Duly only sees the contact you choose.")
                        .foregroundStyle(Color.ink2).multilineTextAlignment(.center).frame(maxWidth: 300)
                    Button { showingContacts = true } label: { Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus") }
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
                    Button("Import from Contacts", systemImage: "person.crop.circle.badge.plus") { showingContacts = true }
                } label: { Label("Add client", systemImage: "plus") }
            }
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
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink)
                if !meta.isEmpty { Text(verbatim: meta).font(.system(size: 13)).foregroundStyle(Color.ink2).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if owed > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(business.money(owed, currency: client.currencyCode)).font(.system(size: 15, weight: .bold)).monospacedDigit()
                    Text("owed").font(.system(size: 12)).foregroundStyle(Color.ink2)
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
