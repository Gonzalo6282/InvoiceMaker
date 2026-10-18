import SwiftUI

extension Binding where Value == Decimal {
    /// Shows 0 as an empty field (so the placeholder appears and typing
    /// doesn't land next to a "0"); clearing the field stores 0.
    var zeroAsEmpty: Binding<Decimal?> {
        Binding<Decimal?>(
            get: { wrappedValue == 0 ? nil : wrappedValue },
            set: { wrappedValue = $0 ?? 0 })
    }
}
