import SwiftUI

/// A number field that saves on every keystroke. (SwiftUI's
/// `TextField(value:format:)` only commits on return or focus loss, so tapping
/// "Done" in a sheet could lose what was typed.) Zero shows as empty.
struct DecimalField: View {
    let placeholder: LocalizedStringKey
    @Binding var value: Decimal
    var allowsFraction = true

    @State private var text = ""
    @FocusState private var focused: Bool

    init(_ placeholder: LocalizedStringKey, value: Binding<Decimal>, allowsFraction: Bool = true) {
        self.placeholder = placeholder
        _value = value
        self.allowsFraction = allowsFraction
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(allowsFraction ? .decimalPad : .numberPad)
            .focused($focused)
            .onAppear { text = Self.display(value) }
            .onChange(of: text) {
                if let parsed = Self.parse(text) { value = parsed }
            }
            .onChange(of: value) {
                // Outside changes (e.g. a different line) refresh the text when not editing.
                if !focused, Self.parse(text) != value { text = Self.display(value) }
            }
            .onChange(of: focused) {
                if !focused { text = Self.display(value) }
            }
    }

    /// "12.5", "12,5" (comma locales), "1,234.50"; empty = 0; nonsense = nil (keep last value).
    nonisolated static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        let decimalSep = locale.decimalSeparator ?? "."
        let groupSep = locale.groupingSeparator ?? ","
        var cleaned = trimmed.replacingOccurrences(of: groupSep == decimalSep ? "" : groupSep, with: "")
        if decimalSep != "." { cleaned = cleaned.replacingOccurrences(of: decimalSep, with: ".") }
        cleaned = cleaned.filter { "0123456789.-".contains($0) }
        guard !cleaned.isEmpty, cleaned.filter({ $0 == "." }).count <= 1,
            let d = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
        else { return nil }
        return max(d, 0)
    }

    nonisolated static func display(_ value: Decimal) -> String {
        value == 0 ? "" : value.formatted(.number.grouping(.never))
    }
}

/// Whole numbers (next invoice number, due days).
struct IntField: View {
    let placeholder: LocalizedStringKey
    @Binding var value: Int

    init(_ placeholder: LocalizedStringKey, value: Binding<Int>) {
        self.placeholder = placeholder
        _value = value
    }

    var body: some View {
        DecimalField(
            placeholder,
            value: Binding(get: { Decimal(value) }, set: { value = NSDecimalNumber(decimal: $0.rounded(0)).intValue }),
            allowsFraction: false)
    }
}
