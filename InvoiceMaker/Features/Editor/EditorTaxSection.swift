import InvoiceKit
import SwiftUI

struct EditorTaxSection: View {
    @Bindable var document: Document
    let business: Business
    let taxes: [TaxRate]

    var body: some View {
        GroupedSection(header: "Tax and discount") {
            chipRow("Prices") {
                ChoiceChip(title: String(localized: "Tax added"), isOn: document.taxMode == .added) { change { document.taxMode = .added } }
                ChoiceChip(title: String(localized: "Tax included"), isOn: document.taxMode == .included) { change { document.taxMode = .included } }
            }
            RowDivider()
            chipRow("Apply tax") {
                ChoiceChip(title: String(localized: "Per item"), isOn: document.taxPlacement == .perItem) { change { document.taxPlacement = .perItem } }
                ChoiceChip(title: String(localized: "On total"), isOn: document.taxPlacement == .onTotal) {
                    change {
                        document.taxPlacement = .onTotal
                        if document.totalTaxIDs.isEmpty, let id = business.defaultTaxID { document.totalTaxIDs = [id] }
                    }
                }
            }
            if document.taxPlacement == .onTotal {
                RowDivider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Taxes on the total").font(.system(size: 16)).foregroundStyle(Color.ink)
                    FlowChips(taxes: taxes, selected: document.totalTaxIDs) { id in
                        change {
                            if document.totalTaxIDs.contains(id) {
                                document.totalTaxIDs.removeAll { $0 == id }
                            } else {
                                document.totalTaxIDs.append(id)
                            }
                        }
                    }
                }
                .padding(14)
            }
            RowDivider()
            FieldRow(label: "Discount") {
                HStack(spacing: 8) {
                    TextField("0", value: discountValue.zeroAsEmpty, format: .number)
                        .keyboardType(.decimalPad)
                    ChoiceChip(title: "%", isOn: document.discountIsPercent) { change { document.discountIsPercent = true } }
                    ChoiceChip(title: document.currencyCode, isOn: !document.discountIsPercent) { change { document.discountIsPercent = false } }
                }
            }
            RowDivider()
            FieldRow(label: "Shipping") {
                TextField("0.00", value: money(\.shipping).zeroAsEmpty, format: .number)
                    .keyboardType(.decimalPad)
            }
            ForEach(document.fees.indices, id: \.self) { index in
                RowDivider()
                HStack(spacing: 8) {
                    TextField("Fee name", text: feeName(index))
                    TextField("0.00", value: feeAmount(index).zeroAsEmpty, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                    Button {
                        change { document.fees.remove(at: index) }
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(Color.due)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove fee")
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
            }
            RowDivider()
            Button {
                change { document.fees.append(Fee(name: "", amount: 0)) }
            } label: {
                Row(icon: "plus", title: "Add a fee", titleColor: .brand)
            }
            .buttonStyle(.plain)
        }
    }

    private func chipRow<Chips: View>(_ label: LocalizedStringKey, @ViewBuilder chips: () -> Chips) -> some View {
        HStack {
            Text(label).font(.system(size: 16)).foregroundStyle(Color.ink)
            Spacer()
            HStack(spacing: 6) { chips() }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }

    private func change(_ body: () -> Void) {
        body()
        document.updatedAt = .now
    }

    private var discountValue: Binding<Decimal> {
        Binding(get: { document.discountValue }, set: { v in change { document.discountValue = max(v, 0) } })
    }

    private func money(_ keyPath: ReferenceWritableKeyPath<Document, Decimal>) -> Binding<Decimal> {
        Binding(get: { document[keyPath: keyPath] }, set: { v in change { document[keyPath: keyPath] = max(v, 0) } })
    }

    private func feeName(_ index: Int) -> Binding<String> {
        Binding(
            get: { document.fees.indices.contains(index) ? document.fees[index].name : "" },
            set: { v in change { if document.fees.indices.contains(index) { document.fees[index].name = v } } })
    }

    private func feeAmount(_ index: Int) -> Binding<Decimal> {
        Binding(
            get: { document.fees.indices.contains(index) ? document.fees[index].amount : 0 },
            set: { v in change { if document.fees.indices.contains(index) { document.fees[index].amount = v } } })
    }
}

/// Tax chips that wrap onto more lines.
struct FlowChips: View {
    let taxes: [TaxRate]
    let selected: [String]
    let toggle: (String) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    @ViewBuilder private var chips: some View {
        ForEach(taxes) { tax in
            ChoiceChip(title: tax.label, isOn: selected.contains(tax.id)) { toggle(tax.id) }
        }
    }
}
