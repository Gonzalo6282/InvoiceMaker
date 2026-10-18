import SwiftUI

/// A list row: optional icon chip, label + meta, trailing value, chevron.
/// At least 48pt tall, 14pt side padding.
struct Row<Trailing: View>: View {
    var icon: String?
    var iconTint: IconChip.Tint = .brand
    let title: LocalizedStringKey
    var meta: String?
    var value: String?
    var titleColor: Color = .ink
    var showsChevron = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let icon { IconChip(systemName: icon, tint: iconTint) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(titleColor)
                if let meta {
                    Text(meta)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.ink2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.ink2)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            trailing
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ink3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

extension Row where Trailing == EmptyView {
    init(
        icon: String? = nil, iconTint: IconChip.Tint = .brand, title: LocalizedStringKey, meta: String? = nil,
        value: String? = nil, titleColor: Color = .ink, showsChevron: Bool = false
    ) {
        self.init(
            icon: icon, iconTint: iconTint, title: title, meta: meta, value: value, titleColor: titleColor,
            showsChevron: showsChevron
        ) { EmptyView() }
    }
}
