import InvoiceKit
import SwiftData
import SwiftUI

/// Edit tax rates, choose the default, add your own, restore presets.
struct TaxesView: View {
    @Bindable var business: Business
    @Environment(\.modelContext) private var context
    @Query(sort: \TaxRateRecord.sortIndex) private var records: [TaxRateRecord]
    @State private var confirmingRestore = false

    private var active: [TaxRateRecord] { records.filter { !$0.isArchived } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Banner(tone: .info, systemImage: "percent",
                       text: Text("Presets for **\(business.region.countryName)**. Edit any rate or add your own. Changing a rate never changes invoices you've already sent."))
                GroupedSection(header: "Saved rates", footer: "Canada: add GST and PST or QST to one invoice, or a single HST. US: sales tax depends on state, county and city, so type your own rate.") {
                    ForEach(Array(active.enumerated()), id: \.element.persistentModelID) { index, record in
                        if index > 0 { RowDivider() }
                        TaxRow(record: record, isDefault: business.defaultTaxID == record.taxID,
                               makeDefault: { business.defaultTaxID = record.taxID },
                               delete: {
                                   record.isArchived = true
                                   if business.defaultTaxID == record.taxID { business.defaultTaxID = nil }
                               })
                    }
                    if !active.isEmpty { RowDivider() }
                    Button(action: add) { Row(icon: "plus", title: "Add a tax", titleColor: .brand) }.buttonStyle(.plain)
                }
                Button(String(localized: "Restore \(business.region.countryName) presets")) { confirmingRestore = true }
                    .buttonStyle(.ghost)
                    .padding(16)
            }
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .navigationTitle("Taxes")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Restore the preset rates?", isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("Restore presets") { try? BusinessSetup.restorePresets(for: business.region, business: business, in: context) }
        } message: {
            Text("Your own rates are removed from the list. Invoices already sent keep their rates.")
        }
    }

    private func add() {
        let index = (records.map(\.sortIndex).max() ?? -1) + 1
        context.insert(TaxRateRecord(taxID: "custom-\(UUID().uuidString.prefix(8))", name: String(localized: "Tax"), rate: 0, sortIndex: index))
    }
}

private struct TaxRow: View {
    @Bindable var record: TaxRateRecord
    let isDefault: Bool
    let makeDefault: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $record.name).frame(maxWidth: .infinity)
            DecimalField("0", value: $record.rate).multilineTextAlignment(.trailing).frame(width: 64)
            Text("%").foregroundStyle(Color.ink2)
            if isDefault {
                Text("Default").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.brand)
                    .padding(.horizontal, 9).frame(height: 22).background(Color.brandWash, in: Capsule()).fixedSize()
            } else {
                ChoiceChip(title: String(localized: "Make default"), isOn: false, action: makeDefault)
            }
            Button(action: delete) { Image(systemName: "trash").foregroundStyle(Color.due) }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Delete \(record.name)"))
        }
        .font(.system(size: 16))
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }
}
