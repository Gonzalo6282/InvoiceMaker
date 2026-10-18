#if DEBUG
    import InvoiceKit
    import SwiftUI

    /// Debug-only screen to compare the components with design/mockup.
    struct DesignGalleryView: View {
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeroCard(
                        owed: "£4,860.00", paidLabel: "Paid in October", paid: "£2,310.00", overdue: "£640.00",
                        hasOverdue: true, footnote: "Plus €1,200.00 owed in other currencies"
                    )
                    .padding(.horizontal, 16)

                    GroupedSection(header: "Status pills") {
                        HStack(spacing: 6) {
                            ForEach(DisplayStatus.allCases, id: \.self) { StatusPill(status: $0) }
                        }
                        .padding(14)
                    }

                    GroupedSection(header: "Rows", footer: "Hairlines inset 14pt, no shadows.") {
                        Row(title: "Marlow & Finch Architects", meta: "INV-0012 · Due 1 Nov", value: "£1,450.00") {
                            StatusPill(status: .sent)
                        }
                        RowDivider()
                        Row(icon: "tag.fill", iconTint: .item, title: "Add from saved items", titleColor: .brand)
                        RowDivider()
                        Row(icon: "icloud.slash", iconTint: .warn, title: "iCloud backup", value: "Off", showsChevron: true)
                        RowDivider()
                        Row(icon: "trash", iconTint: .due, title: "Delete", titleColor: .due)
                        RowDivider()
                        Row(title: "Ostara Café", meta: "jonas@ostaracafe.co.uk") { Avatar(name: "Ostara Café") }
                    }

                    VStack(spacing: 12) {
                        Text("Total £273.00").textStyle(.total).foregroundStyle(Color.ink)
                        Button("Send invoice") {}.buttonStyle(.primary)
                        Button("Preview") {}.buttonStyle(.ghost)
                        Button("Send invoice") {}.buttonStyle(.primary).disabled(true)
                        Button("Delete invoice") {}.buttonStyle(.destructivePrimary)
                        Button("Mark as paid") {}.buttonStyle(.small)
                    }
                    .padding(16)
                }
                .padding(.vertical, 16)
            }
            .background(Color.canvas)
            .navigationTitle("Design system")
        }
    }

    #Preview("Light") {
        NavigationStack { DesignGalleryView() }
    }

    #Preview("Dark") {
        NavigationStack { DesignGalleryView() }.preferredColorScheme(.dark)
    }
#endif
