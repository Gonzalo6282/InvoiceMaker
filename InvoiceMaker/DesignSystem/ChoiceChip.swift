import SwiftUI

/// Small selectable capsule (mockup `.chip`), e.g. "Tax added" / "Tax included".
struct ChoiceChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: isOn ? .semibold : .medium))
                .foregroundStyle(isOn ? Color.brand : Color.ink2)
                .padding(.horizontal, 12)
                .frame(minHeight: 30)
                .background(isOn ? Color.brandWash : Color.surface2, in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? Color.brandEdge : Color.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A coloured banner under the editor header (mockup `.banner`).
struct Banner: View {
    enum Tone { case info, ok, warn, error }

    let tone: Tone
    let systemImage: String
    let text: Text
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage).font(.system(size: 17, weight: .semibold))
            text.font(.system(size: 13.5)).frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13.5, weight: .semibold))
                    .underline()
                    .buttonStyle(.plain)
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(background, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var foreground: Color {
        switch tone {
        case .info: .brand
        case .ok: .paidInk
        case .warn: .warn
        case .error: .due
        }
    }

    private var background: Color {
        switch tone {
        case .info: .brandWash
        case .ok: .paidWash
        case .warn: .warnWash
        case .error: .dueWash
        }
    }
}

/// A label + trailing field row for forms (mockup `inRow`).
struct FieldRow<Field: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var field: Field

    var body: some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 16)).foregroundStyle(Color.ink)
            field
                .font(.system(size: 16))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }
}
