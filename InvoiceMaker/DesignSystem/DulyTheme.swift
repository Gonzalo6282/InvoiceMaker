// SliceUI (SliceLibrary) provides the components; Duly provides its colours here.
// Re-exported so every file can use Row, GroupedSection, Pill… without importing it.
@_exported import SliceUI
import SwiftUI

extension SliceTheme {
    /// Duly's design system (docs/design-system.md), from the asset catalog,
    /// so light and dark mode work as before.
    static let duly = SliceTheme(
        appearance: .system,
        accent: .brand,
        accentPressed: .brandPress,
        accentSoft: .brandWash,
        accentEdge: .brandEdge,
        onAccent: .white,
        canvas: .canvas,
        surface: .surface,
        surfaceAlt: .surface2,
        line: .line,
        ink: .ink,
        inkSecondary: .ink2,
        inkTertiary: .ink3,
        success: .paid,
        successSoft: .paidWash,
        successInk: .paidInk,
        successText: .paidText,
        danger: .due,
        dangerSoft: .dueWash,
        warning: .warn,
        warningSoft: .warnWash,
        chipBackground: .chipBackground,
        chipInk: .chipInk,
        text: .system,
        display: .system
    )
}

/// Duly's names for the icon tints.
extension IconChip.Tint {
    static let brand = IconChip.Tint.accent
    static let paid = IconChip.Tint.success
    static let due = IconChip.Tint.danger
    static let warn = IconChip.Tint.warning
    /// Saved items: peach tile, orange tag (inverted in dark mode).
    static let item = IconChip.Tint.custom(tile: .itemTile, glyph: .itemGlyph)
}

/// Duly's text styles on top of SliceUI's (.largeTitle, .pill, …).
extension SliceTextStyle {
    /// 40 Black, -3.5%: "Owed to you".
    static let moneyDisplay = SliceTextStyle(size: 40, weight: .black, tracking: -0.035, relativeTo: .largeTitle, display: true)
    /// 28 Heavy, -2.5%: INV-0012 in the editor.
    static let docNumber = SliceTextStyle(size: 28, weight: .heavy, tracking: -0.025, relativeTo: .title, display: true)
    /// 30 Black, -3.5%.
    static let paywallHeadline = SliceTextStyle.headline
    /// 24 Black, -3%: totals.
    static let total = SliceTextStyle(size: 24, weight: .black, tracking: -0.03, relativeTo: .title2, display: true)
}
