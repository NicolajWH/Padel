import Contacts
import ContactsUI
import SwiftUI

/// Uses the system contact picker, which gives the app access only to the
/// contacts explicitly selected by the user.
struct ContactPicker: UIViewControllerRepresentable {
    let onSelect: ([String]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onSelect: ([String]) -> Void

        init(onSelect: @escaping ([String]) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onSelect(contacts.compactMap {
                CNContactFormatter.string(from: $0, style: .fullName)
            })
        }
    }
}
