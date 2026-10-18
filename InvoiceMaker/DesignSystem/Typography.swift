import SwiftUI

/// Type styles from docs/design-system.md. Sizes scale with Dynamic Type
/// (each is tied to the nearest system text style).
enum TextStyle {
    case moneyDisplay  // 40 Black, -3.5%: "Owed to you" hero
    case largeTitle  // 34 Heavy, -2.5%: screen titles
    case docNumber  // 28 Heavy, -2.5%: INV-0012 in the editor
    case paywallHeadline  // 30 Black, -3.5%
    case total  // 24 Black, -3%: totals block
    case body  // 17 Regular
    case secondary  // 15 Regular: row meta, footers
    case footnote  // 13 Regular
    case pill  // 12 Semibold: status tags

    var size: CGFloat {
        switch self {
        case .moneyDisplay: 40
        case .largeTitle: 34
        case .docNumber: 28
        case .paywallHeadline: 30
        case .total: 24
        case .body: 17
        case .secondary: 15
        case .footnote: 13
        case .pill: 12
        }
    }

    var weight: Font.Weight {
        switch self {
        case .moneyDisplay, .paywallHeadline, .total: .black
        case .largeTitle, .docNumber: .heavy
        case .pill: .semibold
        case .body, .secondary, .footnote: .regular
        }
    }

    /// Tracking as a fraction of the font size (design-system.md percentages).
    var trackingRatio: CGFloat {
        switch self {
        case .moneyDisplay, .paywallHeadline: -0.035
        case .largeTitle, .docNumber: -0.025
        case .total: -0.03
        default: 0
        }
    }

    var relativeTo: Font.TextStyle {
        switch self {
        case .moneyDisplay, .largeTitle, .paywallHeadline: .largeTitle
        case .docNumber: .title
        case .total: .title2
        case .body: .body
        case .secondary: .subheadline
        case .footnote: .footnote
        case .pill: .caption
        }
    }

    /// Money is always shown with tabular figures.
    var isNumeric: Bool { self == .moneyDisplay || self == .total }
}

private struct TextStyleModifier: ViewModifier {
    let style: TextStyle
    @ScaledMetric private var size: CGFloat

    init(style: TextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: style.weight))
            .tracking(size * style.trackingRatio)
            .monospacedDigit()
    }
}

extension View {
    /// Applies a design-system text style. Digits are always tabular.
    func textStyle(_ style: TextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}
