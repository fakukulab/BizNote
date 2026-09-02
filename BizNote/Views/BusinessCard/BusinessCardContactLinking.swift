import SwiftUI
import Contacts
import ContactsUI

/// Wraps the system contact picker so a business card's fields can be
/// filled in from an existing Contacts entry. `CNContactPickerViewController`
/// runs out-of-process, so no Contacts permission is required to show it.
struct ContactPickerView: UIViewControllerRepresentable {
    var onSelect: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (CNContact) -> Void
        init(onSelect: @escaping (CNContact) -> Void) { self.onSelect = onSelect }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
        }
    }
}

/// Section offering to import fields from an existing system contact, or
/// save the current card's fields as a new contact. Only empty fields are
/// filled on import so OCR results aren't clobbered.
struct BusinessCardContactActionsView: View {
    @Binding var name: String
    @Binding var company: String
    @Binding var jobTitle: String
    @Binding var phone: String
    @Binding var email: String

    @State private var showContactPicker = false
    @State private var showAddSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Button {
                showContactPicker = true
            } label: {
                Label(String(localized: "contacts.import", defaultValue: "주소록에서 불러오기"),
                      systemImage: "person.crop.circle.badge.magnifyingglass")
            }
            Button {
                addToContacts()
            } label: {
                Label(String(localized: "contacts.add", defaultValue: "주소록에 추가"),
                      systemImage: "person.crop.circle.badge.plus")
            }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { contact in
                apply(contact)
                showContactPicker = false
            }
        }
        .alert(String(localized: "contacts.add.success", defaultValue: "주소록에 추가되었습니다"),
               isPresented: $showAddSuccess) {
            Button(String(localized: "action.ok", defaultValue: "확인"), role: .cancel) {}
        }
        .alert(String(localized: "contacts.add.error", defaultValue: "주소록에 추가하지 못했습니다"),
               isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
               )) {
            Button(String(localized: "action.ok", defaultValue: "확인"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func apply(_ contact: CNContact) {
        if name.isEmpty { name = contact.displayName }
        if company.isEmpty { company = contact.organizationName }
        if jobTitle.isEmpty { jobTitle = contact.jobTitle }
        if phone.isEmpty { phone = contact.primaryPhone }
        if email.isEmpty { email = contact.primaryEmail }
    }

    private func addToContacts() {
        Task {
            let granted = await ContactsService.requestAccess()
            guard granted else {
                errorMessage = String(localized: "contacts.access.denied", defaultValue: "주소록 접근 권한이 필요합니다.")
                return
            }
            let contact = ContactsService.makeMutableContact(
                name: name, company: company, jobTitle: jobTitle, phone: phone, email: email
            )
            let request = CNSaveRequest()
            request.add(contact, toContainerWithIdentifier: nil)
            do {
                try CNContactStore().execute(request)
                showAddSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Section that checks the system address book for contacts that may
/// already represent this business card, surfacing a name/reason list so
/// duplicates aren't saved twice. Never prompts for Contacts access on its
/// own — it only auto-checks once access has already been granted elsewhere;
/// otherwise it shows a button the user can tap to opt in explicitly.
struct BusinessCardDuplicateSection: View {
    let name: String
    let company: String
    let phone: String
    let officePhone: String
    let email: String
    let website: String

    @State private var candidates: [BusinessCardDuplicateCandidate] = []
    @State private var isChecking = false

    private var isAuthorized: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    private var hasEnoughInfo: Bool {
        !name.isEmpty || !email.isEmpty || !phone.isEmpty || !officePhone.isEmpty
    }

    var body: some View {
        Group {
            if !candidates.isEmpty {
                Section(String(localized: "businessCard.duplicate.title", defaultValue: "중복 확인")) {
                    ForEach(candidates.prefix(3)) { candidate in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.displayName)
                                .font(.subheadline.bold())
                            if !candidate.organizationName.isEmpty {
                                Text(candidate.organizationName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(candidate.reasons.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(candidate.strength == .strong ? .red : .orange)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else if isChecking {
                Section(String(localized: "businessCard.duplicate.title", defaultValue: "중복 확인")) {
                    ProgressView()
                }
            } else if hasEnoughInfo && !isAuthorized {
                Section(String(localized: "businessCard.duplicate.title", defaultValue: "중복 확인")) {
                    Button {
                        Task { await checkDuplicates() }
                    } label: {
                        Label(String(localized: "businessCard.duplicate.check", defaultValue: "주소록에서 중복 확인"),
                              systemImage: "person.crop.circle.badge.questionmark")
                    }
                }
            }
        }
        .task(id: checkKey) {
            if isAuthorized { await checkDuplicates() }
        }
    }

    private var checkKey: String {
        "\(name)|\(email)|\(phone)|\(officePhone)|\(company)|\(website)"
    }

    private func checkDuplicates() async {
        guard hasEnoughInfo else {
            candidates = []
            return
        }
        isChecking = true
        defer { isChecking = false }
        let granted = await ContactsService.requestAccess()
        guard granted else { return }

        var draft = BusinessCardDraft()
        draft.name = name
        draft.company = company
        draft.phone = phone
        draft.officePhone = officePhone
        draft.email = email
        draft.website = website

        let found = await Task.detached(priority: .userInitiated) { () -> [BusinessCardDuplicateCandidate] in
            let contacts = ContactsService.fetchAllContacts()
            return BusinessCardDuplicateDetector.candidates(for: draft, contacts: contacts)
        }.value

        candidates = found.filter { $0.strength != .newCandidate }
    }
}
