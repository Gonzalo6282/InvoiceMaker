import SwiftUI

/// A list row: optional icon chip, label + meta, trailing value, chevron.
/// At least 48pt tall, 14pt side padding.
struct Row<Trailing: View>: View {
    var icon: String?
    var iconTint: IconChip.Tint = .brand
    let title: Text
    var meta: String?
    var value: String?
    var titleColor: Color = .ink
    var showsChevron = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let icon { IconChip(systemName: icon, tint: iconTint) }
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.callout)
                    .foregroundStyle(titleColor)
                if let meta, !meta.isEmpty {
                    Text(meta)
                        .font(.footnote)
                        .foregroundStyle(Color.ink2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color.ink2)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            trailing
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.ink3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

extension Row {
    /// Localized title with trailing content.
    init(
        icon: String? = nil, iconTint: IconChip.Tint = .brand, title: LocalizedStringKey, meta: String? = nil,
        value: String? = nil, titleColor: Color = .ink, showsChevron: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            icon: icon, iconTint: iconTint, title: Text(title), meta: meta, value: value, titleColor: titleColor,
            showsChevron: showsChevron, trailing: trailing)
    }

    /// User-entered title (shown as typed, never looked up as a translation key).
    init(
        icon: String? = nil, iconTint: IconChip.Tint = .brand, verbatim: String, meta: String? = nil,
        value: String? = nil, titleColor: Color = .ink, showsChevron: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            icon: icon, iconTint: iconTint, title: Text(verbatim: verbatim), meta: meta, value: value,
            titleColor: titleColor, showsChevron: showsChevron, trailing: trailing)
    }
}

extension Row where Trailing == EmptyView {
    init(
        icon: String? = nil, iconTint: IconChip.Tint = .brand, title: LocalizedStringKey, meta: String? = nil,
        value: String? = nil, titleColor: Color = .ink, showsChevron: Bool = false
    ) {
        self.init(
            icon: icon, iconTint: iconTint, title: Text(title), meta: meta, value: value, titleColor: titleColor,
            showsChevron: showsChevron) { EmptyView() }
    }

    init(
        icon: String? = nil, iconTint: IconChip.Tint = .brand, verbatim: String, meta: String? = nil,
        value: String? = nil, titleColor: Color = .ink, showsChevron: Bool = false
    ) {
        self.init(
            icon: icon, iconTint: iconTint, title: Text(verbatim: verbatim), meta: meta, value: value,
            titleColor: titleColor, showsChevron: showsChevron) { EmptyView() }
    }
}
