import SwiftUI

/// Small rounded tile with an SF Symbol. Saved items use the peach tile with
/// an orange tag; in dark mode the colours invert (solid tile, dark glyph).
struct IconChip: View {
    enum Tint {
        case brand, item, paid, due, warn, neutral

        var tile: Color {
            switch self {
            case .brand: .chipBackground
            case .item: .itemTile
            case .paid: .paidWash
            case .due: .dueWash
            case .warn: .warnWash
            case .neutral: .canvas
            }
        }

        var glyph: Color {
            switch self {
            case .brand: .chipInk
            case .item: .itemGlyph
            case .paid: .paidText
            case .due: .due
            case .warn: .warn
            case .neutral: .ink2
            }
        }
    }

    let systemName: String
    var tint: Tint = .brand
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(tint.glyph)
            .frame(width: size, height: size)
            .background(tint.tile, in: RoundedRectangle(cornerRadius: size * 0.27))
            .accessibilityHidden(true)
    }
}

/// Client initials in a violet circle (38pt).
struct Avatar: View {
    let name: String
    var size: CGFloat = 38

    var body: some View {
        Text(Self.initials(for: name))
            .font(.system(size: size * 0.37, weight: .bold))
            .foregroundStyle(Color.chipInk)
            .frame(width: size, height: size)
            .background(Color.chipBackground, in: Circle())
            .accessibilityHidden(true)
    }

    /// "Marlow & Finch Architects" → "MF"; "" → "?".
    nonisolated static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let letters = words.prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}
