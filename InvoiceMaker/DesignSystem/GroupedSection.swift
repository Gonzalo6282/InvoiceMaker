import SwiftUI

/// A white card of rows on the canvas: 14pt radius, 1pt hairline, no shadow.
/// Put a `RowDivider()` between rows.
struct GroupedSection<Content: View>: View {
    var header: LocalizedStringKey?
    var footer: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                Text(header)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.ink2)
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 7)
            }
            VStack(spacing: 0) { content }
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(Color.ink2)
                    .padding(.horizontal, 16)
                    .padding(.top, 7)
            }
        }
    }
}

/// Hairline between rows in a `GroupedSection`, inset 14pt like the mockup.
struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Color.line).frame(height: 1).padding(.leading, 14)
    }
}
