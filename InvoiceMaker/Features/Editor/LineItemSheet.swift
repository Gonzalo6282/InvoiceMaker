import InvoiceKit
import SwiftData
import SwiftUI

/// Edit one line: description, quantity, unit, rate, discount, taxes.
/// Changes apply live (autosave); "Delete" removes the line.
struct LineItemSheet: View {
    @Bindable var line: LineItem
    let document: Document
    let business: Business
    let taxes: [TaxRate]
    let actions: DocumentActions

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var saveForLater = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    GroupedSection {
                        TextField("Description", text: $line.itemDescription, axis: .vertical)
                            .font(.system(size: 16))
                            .focused($focused)
                            .padding(14)
                            .accessibilityIdentifier("lineDescription")
                        RowDivider()
                        FieldRow(label: "Quantity") {
                            TextField("1", value: decimal(\.quantity), format: .number).keyboardType(.decimalPad)
                        }
                        RowDivider()
                        FieldRow(label: "Unit") {
                            TextField("hour, day, item…", text: $line.unit)
                        }
                        RowDivider()
                        FieldRow(label: "Rate") {
                            TextField("0.00", value: decimal(\.rate), format: .number)
                                .keyboardType(.decimalPad)
                                .accessibilityIdentifier("lineRate")
                        }
                        RowDivider()
                        FieldRow(label: "Discount") {
                            HStack(spacing: 8) {
                                TextField("0", value: decimal(\.discountValue), format: .number).keyboardType(.decimalPad)
                                ChoiceChip(title: "%", isOn: line.discountIsPercent) { line.discountIsPercent = true }
                                ChoiceChip(title: document.currencyCode, isOn: !line.discountIsPercent) { line.discountIsPercent = false }
                            }
                        }
                    }
                    if document.taxPlacement == .perItem {
                        GroupedSection(header: "Tax", footer: "Pick one or more. Canada: GST plus PST or QST.") {
                            FlowChips(taxes: taxes, selected: line.taxIDs) { id in
                                if line.taxIDs.contains(id) { line.taxIDs.removeAll { $0 == id } } else { line.taxIDs.append(id) }
                            }
                            .padding(14)
                        }
                    }
                    GroupedSection {
                        Toggle("Save to my items", isOn: $saveForLater).padding(.horizontal, 14).frame(minHeight: 48)
                    }
                    HStack {
                        Text("Line total").foregroundStyle(Color.ink2)
                        Spacer()
                        Text(business.money(LineItemInput(quantity: line.quantity, rate: line.rate, discount: line.discount).net, currency: document.currencyCode))
                            .textStyle(.total)
                            .foregroundStyle(Color.ink)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    Button("Delete item", role: .destructive) {
                        actions.deleteLineItem(line)
                        dismiss()
                    }
                    .foregroundStyle(Color.due)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                }
                .padding(.bottom, 24)
            }
            .background(Color.canvas)
            .navigationTitle("Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finish() }.accessibilityIdentifier("lineDone")
                }
            }
            .onAppear { focused = line.itemDescription.isEmpty }
        }
        .presentationDetents([.large])
    }

    private func decimal(_ keyPath: ReferenceWritableKeyPath<LineItem, Decimal>) -> Binding<Decimal> {
        Binding(get: { line[keyPath: keyPath] }, set: { line[keyPath: keyPath] = max($0, 0); actions.touch(document) })
    }

    private func finish() {
        if saveForLater, !line.itemDescription.isEmpty {
            context.insert(SavedItem(itemDescription: line.itemDescription, unit: line.unit, rate: line.rate, taxID: line.taxIDs.first))
        }
        actions.touch(document)
        dismiss()
    }
}
