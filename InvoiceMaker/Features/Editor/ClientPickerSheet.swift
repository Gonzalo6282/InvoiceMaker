import SwiftData
import SwiftUI

/// Choose the client for a document, or add a new one by name.
/// (The full client list, details and Contacts import are in Clients, T4.8.)
struct ClientPickerSheet: View {
    var selected: Client?
    let pick: (Client?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]
    @State private var search = ""
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New client name", text: $newName)
                            .submitLabel(.done)
                            .onSubmit(addNew)
                            .accessibilityIdentifier("newClientName")
                        Button("Add", action: addNew).disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section {
                    ForEach(filtered) { client in
                        Button {
                            pick(client)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Avatar(name: client.name)
                                VStack(alignment: .leading) {
                                    Text(verbatim: client.name).foregroundStyle(Color.ink)
                                    if !client.email.isEmpty {
                                        Text(verbatim: client.email).font(.footnote).foregroundStyle(Color.ink2)
                                    }
                                }
                                Spacer()
                                if client.persistentModelID == selected?.persistentModelID {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brand)
                                }
                            }
                        }
                    }
                }
                if selected != nil {
                    Section {
                        Button("Remove client", role: .destructive) {
                            pick(nil)
                            dismiss()
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private var filtered: [Client] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? clients : clients.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.email.localizedCaseInsensitiveContains(q) }
    }

    private func addNew() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let currency = (try? BusinessSetup.current(in: context))?.currencyCode ?? "GBP"
        let client = Client(name: name, currencyCode: currency)
        context.insert(client)
        pick(client)
        dismiss()
    }
}
