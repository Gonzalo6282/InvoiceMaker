import Contacts
import ContactsUI
import SwiftUI

/// The system contact picker: no permission prompt, the app only sees the
/// contact the user picks. Presented from a hidden host controller, since
/// CNContactPickerViewController can't live inside a SwiftUI sheet.
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let picked: (CNContact) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        DispatchQueue.main.async { host.present(picker, animated: true) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker
        init(parent: ContactPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.isPresented = false
            parent.picked(contact)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}

extension Client {
    /// Fills the client from a picked contact. A company contact becomes the
    /// client name with the person as contact.
    func fill(from contact: CNContact) {
        let person = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        if !contact.organizationName.isEmpty {
            name = contact.organizationName
            contactName = person
        } else {
            name = person
        }
        if let email = contact.emailAddresses.first?.value as String? { self.email = email }
        if let phone = contact.phoneNumbers.first?.value.stringValue { self.phone = phone }
        if let postal = contact.postalAddresses.first?.value {
            address = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
        }
    }
}
