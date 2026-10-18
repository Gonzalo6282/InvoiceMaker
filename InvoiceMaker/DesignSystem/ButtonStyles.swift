import SwiftUI

/// Indigo capsule, 52pt tall, full width: the main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    var role: Role = .normal

    enum Role { case normal, destructive, dark }

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 24)
            .background(background(pressed: configuration.isPressed), in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .contentShape(Capsule())
    }

    private func background(pressed: Bool) -> Color {
        switch role {
        case .normal: pressed ? .brandPress : .brand
        case .destructive: .due
        case .dark: .black
        }
    }
}

/// Ghost capsule with a lavender border: the secondary action, paired with primary.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.brand)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 24)
            .background(Color.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.brandEdge, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Small capsule (36pt), e.g. "Mark as paid" in a row.
struct SmallButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : Color.brand)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(prominent ? Color.brand : Color.brandWash, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var destructivePrimary: PrimaryButtonStyle { PrimaryButtonStyle(role: .destructive) }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}

extension ButtonStyle where Self == SmallButtonStyle {
    static var small: SmallButtonStyle { SmallButtonStyle() }
}
