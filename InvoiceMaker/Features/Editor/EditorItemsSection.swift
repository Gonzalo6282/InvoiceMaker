import InvoiceKit
import SwiftData
import SwiftUI

struct EditorItemsSection: View {
    let document: Document
    let business: Business
    let taxes: [TaxRate]
    let actions: DocumentActions
    let edit: (LineItem) -> Void

    @Query(sort: \SavedItem.itemDescription) private var savedItems: [SavedItem]
    @Environment(\.modelContext) private var context
    @State private var showingSaved = false

    var body: some View {
        GroupedSection(header: "Items") {
            ForEach(document.sortedItems) { line in
                Button { edit(line) } label: { LineRow(line: line, document: document, business: business, taxes: taxes) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { actions.deleteLineItem(line) }
                    }
                RowDivider()
            }
            Button {
                let line = actions.addLineItem(to: document, defaultTaxID: business.defaultTaxID)
                // Save first so the line's ID is permanent before its sheet opens.
                // Otherwise autosave swaps the temporary ID a moment later and
                // `.sheet(item:)` closes and reopens (device bug, 19 Oct).
                try? context.save()
                edit(line)
            } label: {
                Row(icon: "plus", title: "Add item", titleColor: .brand)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addItem")
            if !savedItems.isEmpty {
                RowDivider()
                Button { showingSaved = true } label: {
                    Row(icon: "tag.fill", iconTint: .item, title: "Add from saved items", titleColor: .brand)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingSaved) {
            SavedItemPickerSheet(items: savedItems, business: business) { saved in
                actions.addLineItem(to: document, from: saved, defaultTaxID: business.defaultTaxID)
            }
        }
    }
}

/// "Bespoke shelving / 2 unit × £87.50 · VAT 20%      £175.00" (mockup `.line`).
private struct LineRow: View {
    let line: LineItem
    let document: Document
    let business: Business
    let taxes: [TaxRate]

    var body: some View {
        let input = LineItemInput(quantity: line.quantity, rate: line.rate, discount: line.discount)
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(line.itemDescription.isEmpty ? String(localized: "Untitled item") : line.itemDescription)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(line.itemDescription.isEmpty ? Color.ink3 : Color.ink)
                Text(meta(input))
                    .font(.footnote)
                    .foregroundStyle(Color.ink2)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            Text(business.money(input.net, currency: document.currencyCode))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func meta(_ input: LineItemInput) -> String {
        var parts = [
            "\(line.quantity.formatted()) \(line.unit) × \(business.money(line.rate, currency: document.currencyCode))"
                .replacingOccurrences(of: "  ", with: " ")
        ]
        if input.discountAmount > 0 {
            switch line.discount {
            case .percent(let v): parts.append("−\(v.formatted())%")
            case .amount(let v): parts.append("−" + business.money(v, currency: document.currencyCode))
            }
        }
        if document.taxPlacement == .perItem {
            let names = line.taxIDs.compactMap { id in taxes.first { $0.id == id }?.label }
            parts.append(names.isEmpty ? String(localized: "No tax") : names.joined(separator: " + "))
        }
        return parts.joined(separator: " · ")
    }
}

/// Pick a saved item to add as a line.
struct SavedItemPickerSheet: View {
    let items: [SavedItem]
    let business: Business
    let pick: (SavedItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(items) { item in
                Button {
                    pick(item)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        IconChip(systemName: "tag.fill", tint: .item, size: 38)
                        VStack(alignment: .leading) {
                            Text(item.itemDescription).foregroundStyle(Color.ink)
                            if !item.unit.isEmpty {
                                Text("per \(item.unit)").font(.footnote).foregroundStyle(Color.ink2)
                            }
                        }
                        Spacer()
                        Text(business.money(item.rate)).monospacedDigit().foregroundStyle(Color.ink)
                    }
                }
            }
            .navigationTitle("Saved items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
