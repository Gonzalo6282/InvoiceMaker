import InvoiceKit
import SwiftData
import SwiftUI

/// Saved items and services (mockup scrItems).
struct ItemsView: View {
    let business: Business

    @Environment(\.modelContext) private var context
    @Query(sort: \SavedItem.itemDescription) private var items: [SavedItem]
    @Query(sort: \TaxRateRecord.sortIndex) private var taxRecords: [TaxRateRecord]
    @State private var editing: SavedItem?

    var body: some View {
        ScrollView {
            if items.isEmpty {
                VStack(spacing: 10) {
                    IconChip(systemName: "tag.fill", tint: .item, size: 64)
                    Text("Save what you charge for").textStyle(.total).foregroundStyle(Color.ink)
                    Text("Add services and products once, with their price and tax. Then add them to any invoice in one tap.")
                        .foregroundStyle(Color.ink2).multilineTextAlignment(.center).frame(maxWidth: 300)
                    Button { addNew() } label: { Label("Add item", systemImage: "plus") }.buttonStyle(.primary).fixedSize()
                }
                .padding(.horizontal, 32).padding(.vertical, 48)
            } else {
                GroupedSection(footer: "Prices are in \(business.currencyCode). On an invoice in another currency, check the price before sending.") {
                    ForEach(Array(items.enumerated()), id: \.element.persistentModelID) { index, item in
                        if index > 0 { RowDivider() }
                        Button { editing = item } label: { row(item) }.buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(Color.canvas)
        .navigationTitle("Items")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addNew) { Label("Add item", systemImage: "plus") }
            }
        }
        .sheet(item: $editing) { item in
            SavedItemSheet(item: item, business: business, taxes: taxRecords.filter { !$0.isArchived }.map(\.taxRate))
        }
    }

    private func row(_ item: SavedItem) -> some View {
        let tax = taxRecords.first { $0.taxID == item.taxID }?.taxRate.label ?? String(localized: "No tax")
        let meta = [item.unit.isEmpty ? "" : String(localized: "per \(item.unit)"), tax].filter { !$0.isEmpty }.joined(separator: " · ")
        return HStack(spacing: 12) {
            IconChip(systemName: "tag.fill", tint: .item, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.itemDescription.isEmpty ? String(localized: "Untitled item") : item.itemDescription)
                    .font(.callout.weight(.semibold)).foregroundStyle(Color.ink)
                Text(verbatim: meta).font(.footnote).foregroundStyle(Color.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.rate == 0 ? String(localized: "At cost") : business.money(item.rate))
                .font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(Color.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func addNew() {
        let item = SavedItem(taxID: business.defaultTaxID)
        context.insert(item)
        editing = item
    }
}

struct SavedItemSheet: View {
    @Bindable var item: SavedItem
    let business: Business
    let taxes: [TaxRate]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            ScrollView {
                GroupedSection {
                    FieldRow(label: "Description") { TextField("e.g. Labour", text: $item.itemDescription) }
                    RowDivider()
                    FieldRow(label: "Unit") { TextField("hour, day, item…", text: $item.unit) }
                    RowDivider()
                    FieldRow(label: "Price") {
                        DecimalField("0.00", value: $item.rate)
                    }
                }
                GroupedSection(header: "Tax") {
                    FlowChips(taxes: taxes, selected: item.taxID.map { [$0] } ?? []) { id in
                        item.taxID = item.taxID == id ? nil : id
                    }
                    .padding(14)
                }
                GroupedSection {
                    Button {
                        context.delete(item)
                        dismiss()
                    } label: { Row(title: "Delete item", titleColor: .due) }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)
            }
            .background(Color.canvas)
            .navigationTitle("Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onDisappear {
                if !item.isDeleted, item.itemDescription.trimmingCharacters(in: .whitespaces).isEmpty, item.rate == 0 {
                    context.delete(item)
                }
            }
        }
    }
}
