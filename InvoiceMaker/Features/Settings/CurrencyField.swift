import InvoiceKit
import SwiftUI

/// Shows the chosen currency code; tapping opens a searchable list of every
/// currency, with the common ones (GBP, USD, EUR, ZAR, AUD, CAD, NZD) at the top.
struct CurrencyField: View {
    @Binding var code: String
    @State private var picking = false

    var body: some View {
        Button { picking = true } label: {
            HStack(spacing: 4) {
                Text(verbatim: code).foregroundStyle(Color.ink)
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(Color.ink3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Currency"))
        .accessibilityValue(Text(verbatim: CurrencyList.name(code)))
        .accessibilityIdentifier("currencyField")
        .sheet(isPresented: $picking) { CurrencyPicker(code: $code) }
    }
}

struct CurrencyPicker: View {
    @Binding var code: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section("Common") { rows(CurrencyList.common) }
                    Section("All currencies") { rows(Array(all.dropFirst(CurrencyList.common.count))) }
                } else {
                    rows(all.filter(matches))
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var all: [String] { CurrencyList.all(keeping: code) }

    private func matches(_ c: String) -> Bool {
        c.localizedCaseInsensitiveContains(search) || CurrencyList.name(c).localizedCaseInsensitiveContains(search)
    }

    private func rows(_ codes: [String]) -> some View {
        ForEach(codes, id: \.self) { c in
            Button {
                code = c
                dismiss()
            } label: {
                HStack {
                    Text(verbatim: c).font(.callout.weight(.semibold)).foregroundStyle(Color.ink).frame(width: 48, alignment: .leading)
                    Text(verbatim: CurrencyList.name(c)).font(.callout).foregroundStyle(Color.ink2)
                    Spacer()
                    if c == code { Image(systemName: "checkmark").foregroundStyle(Color.brand) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("currency-\(c)")
        }
    }
}

#Preview {
    CurrencyPicker(code: .constant("ZAR"))
}
