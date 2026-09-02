import Contacts
import Foundation

enum ContactsService {
    static let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor
    ]

    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return (try? await store.requestAccess(for: .contacts)) ?? false
        case .restricted, .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func fetchAllContacts() -> [CNContact] {
        let store = CNContactStore()
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var results: [CNContact] = []
        try? store.enumerateContacts(with: request) { contact, _ in
            results.append(contact)
        }
        return results.sorted {
            ($0.givenName + $0.familyName).localizedCompare($1.givenName + $1.familyName) == .orderedAscending
        }
    }

    static func makeMutableContact(name: String, company: String, jobTitle: String,
                                    phone: String, email: String) -> CNMutableContact {
        let contact = CNMutableContact()
        let parts = name.split(separator: " ", maxSplits: 1)
        if parts.count > 1 {
            contact.givenName = String(parts[0])
            contact.familyName = String(parts[1])
        } else {
            contact.givenName = name
        }
        contact.organizationName = company
        contact.jobTitle = jobTitle
        if !phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: phone))]
        }
        if !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        return contact
    }
}

extension CNContact {
    var displayName: String {
        let full = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? organizationName : full
    }
    var primaryPhone: String { phoneNumbers.first?.value.stringValue ?? "" }
    var primaryEmail: String { emailAddresses.first.map { $0.value as String } ?? "" }
}
