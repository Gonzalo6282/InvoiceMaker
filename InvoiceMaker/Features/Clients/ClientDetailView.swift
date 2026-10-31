import InvoiceKit
import SwiftData
import SwiftUI

/// Edit a client; new invoice/quote for them; their documents (mockup scrClient).
struct ClientDetailView: View {
    @Bindable var client: Client
    let business: Business
    let openDocument: (Document) -> Void
    let close: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]
    @State private var confirmingDelete = false

    var body: some View {
        let docs = (client.documents ?? []).sorted { $0.createdAt > $1.createdAt }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Avatar(name: client.name, size: 56)
                    VStack(alignment: .leading) {
                        Text(verbatim: client.name.isEmpty ? String(localized: "New client") : client.name)
                            .font(.title2.weight(.heavy)).foregroundStyle(Color.ink)
                        Text(docs.count == 1 ? String(localized: "1 document") : String(localized: "\(docs.count) documents"))
                            .font(.subheadline).foregroundStyle(Color.ink2)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4)
                HStack(spacing: 10) {
                    Button { create(.invoice) } label: { Label("New invoice", systemImage: "plus") }.buttonStyle(.primary)
                    Button(business.newTitle(for: .estimate)) { create(.estimate) }.buttonStyle(.ghost)
                }
                .padding(.horizontal, 16).padding(.top, 14)

                GroupedSection(header: "Details", footer: "New invoices for this client use \(client.currencyCode).") {
                    FieldRow(label: "Name") { TextField("Company or person", text: $client.name) }
                    RowDivider()
                    FieldRow(label: "Contact") { TextField("Person", text: $client.contactName) }
                    RowDivider()
                    FieldRow(label: "Email") {
                        TextField("name@company.com", text: $client.email)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    RowDivider()
                    FieldRow(label: "Phone") { TextField("Optional", text: $client.phone).keyboardType(.phonePad) }
                    RowDivider()
                    AddressField(text: $client.address, homeCountry: business.countryCode)
                    RowDivider()
                    FieldRow(label: "Tax ID") { TextField("Optional", text: $client.taxID) }
                    RowDivider()
                    FieldRow(label: "Currency") {
                        Picker("Currency", selection: $client.currencyCode) {
                            ForEach(currencies, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                }
                if !docs.isEmpty {
                    let taxes = taxRecords.map(\.taxRate)
                    GroupedSection(header: "Documents") {
                        ForEach(Array(docs.enumerated()), id: \.element.persistentModelID) { index, doc in
                            if index > 0 { RowDivider() }
                            Button { openDocument(doc) } label: {
                                Row(
                                    verbatim: doc.number, meta: doc.dueText(business: business),
                                    value: business.money(doc.totals(taxes: taxes).total, currency: doc.currencyCode)
                                ) { StatusPill(status: doc.displayStatus()) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                GroupedSection(footer: "Invoices already made for this client stay as they are.") {
                    Button { confirmingDelete = true } label: { Row(title: "Delete client", titleColor: .due) }.buttonStyle(.plain)
                }
                .padding(.top, 18)
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this client?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                close()
                context.delete(client)
            }
        }
        .onDisappear {
            // A client added but never named isn't kept.
            if client.name.trimmingCharacters(in: .whitespaces).isEmpty, (client.documents ?? []).isEmpty {
                context.delete(client)
            }
        }
    }

    private var currencies: [String] {
        CurrencyChoices.codes.contains(client.currencyCode) ? CurrencyChoices.codes : [client.currencyCode] + CurrencyChoices.codes
    }

    private func create(_ kind: DocumentKind) {
        openDocument(DocumentActions(context: context).create(kind, business: business, client: client))
    }
}
