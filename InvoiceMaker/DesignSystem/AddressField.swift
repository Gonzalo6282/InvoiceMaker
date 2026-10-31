import Contacts
import MapKit
import Observation
import SwiftUI

/// The "Address" row with Apple Maps suggestions while typing (v1.1).
/// Picking one fills the whole address, one line per part; the country line
/// is left out when it's the business's own country.
struct AddressField: View {
    @Binding var text: String
    /// ISO code of the business's country (its addresses don't repeat it).
    let homeCountry: String
    @State private var completer = AddressCompleter()
    @FocusState private var focused: Bool
    @State private var picking = false

    var body: some View {
        VStack(spacing: 0) {
            FieldRow(label: "Address") {
                TextField("Street, town, postcode", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .textContentType(.fullStreetAddress)
            }
            if focused, !completer.suggestions.isEmpty {
                ForEach(completer.suggestions) { suggestion in
                    RowDivider()
                    Button { pick(suggestion) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(Color.brand)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: suggestion.title).font(.callout).foregroundStyle(Color.ink)
                                if !suggestion.subtitle.isEmpty {
                                    Text(verbatim: suggestion.subtitle).font(.footnote).foregroundStyle(Color.ink2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Fills in the address"))
                }
            }
        }
        .onChange(of: text) {
            // Only while typing a first line; a picked or multi-line address is left alone.
            if focused, !picking, !text.contains("\n") { completer.update(text) } else { completer.clear() }
        }
        .onChange(of: focused) { if !focused { completer.clear() } }
    }

    private func pick(_ suggestion: AddressCompleter.Suggestion) {
        picking = true
        completer.clear()
        Task {
            text = await AddressCompleter.resolve(suggestion, homeCountry: homeCountry)
            picking = false
            focused = false
        }
    }
}

/// Apple Maps address search (MKLocalSearchCompleter). No location permission needed.
@MainActor
@Observable
final class AddressCompleter: NSObject {
    nonisolated struct Suggestion: Identifiable, Hashable, Sendable {
        let id = UUID()
        let title: String
        let subtitle: String
    }

    private(set) var suggestions: [Suggestion] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return clear() }
        completer.queryFragment = trimmed
    }

    func clear() {
        completer.cancel()
        suggestions = []
    }

    /// The full postal address for a suggestion, one line per part.
    static func resolve(_ suggestion: Suggestion, homeCountry: String) async -> String {
        let fallback = [suggestion.title, suggestion.subtitle].filter { !$0.isEmpty }.joined(separator: "\n")
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [suggestion.title, suggestion.subtitle].joined(separator: ", ")
        request.resultTypes = .address
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first,
            let postal = item.placemark.postalAddress
        else { return fallback }
        return format(postal, homeCountry: homeCountry)
    }

    nonisolated static func format(_ postal: CNPostalAddress, homeCountry: String) -> String {
        guard let address = postal.mutableCopy() as? CNMutablePostalAddress else {
            return CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
        }
        if address.isoCountryCode.uppercased() == homeCountry.uppercased() { address.country = "" }
        return CNPostalAddressFormatter.string(from: address, style: .mailingAddress)
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

/// MapKit calls the delegate on the main thread.
extension AddressCompleter: @preconcurrency MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.prefix(4).map { Suggestion(title: $0.title, subtitle: $0.subtitle) }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        suggestions = []
    }
}
