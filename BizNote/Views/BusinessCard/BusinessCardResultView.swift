import SwiftUI
import SwiftData

struct BusinessCardResultView: View {
    @Bindable var card: BusinessCard
    var attachedNote: Note?
    var onDone: (() -> Void)?
    var onRescan: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            if let image = loadImage() {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Section(String(localized: "businessCard.name")) {
                TextField(String(localized: "businessCard.name"), text: $card.name)
                TextField(String(localized: "businessCard.jobTitle"), text: $card.jobTitle)
            }

            Section(String(localized: "businessCard.company")) {
                TextField(String(localized: "businessCard.company"), text: $card.company)
                TextField(String(localized: "businessCard.department"), text: $card.department)
            }

            Section(String(localized: "businessCard.contact")) {
                LabeledField(label: String(localized: "businessCard.email"),
                             text: $card.email, keyboard: .emailAddress)
                LabeledField(label: String(localized: "businessCard.phone"),
                             text: $card.phone, keyboard: .phonePad)
                LabeledField(label: String(localized: "businessCard.officePhone"),
                             text: $card.officePhone, keyboard: .phonePad)
                LabeledField(label: String(localized: "businessCard.website"),
                             text: $card.website, keyboard: .URL)
            }

            Section(String(localized: "businessCard.memo")) {
                TextField(String(localized: "businessCard.memo"), text: $card.memo, axis: .vertical).lineLimit(2...6)
            }

            BusinessCardDuplicateSection(
                name: card.name,
                company: card.company,
                phone: card.phone,
                officePhone: card.officePhone,
                email: card.email,
                website: card.website
            )

            BusinessCardContactActionsView(
                name: $card.name,
                company: $card.company,
                jobTitle: $card.jobTitle,
                phone: $card.phone,
                email: $card.email
            )
        }
        .navigationTitle(String(localized: "businessCard.scanTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onRescan {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        onRescan()
                    } label: {
                        Label(String(localized: "businessCard.rescan"), systemImage: "camera.rotate")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "action.save")) {
                    try? context.save()
                    if let onDone {
                        onDone()
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }

    private func loadImage() -> UIImage? {
        guard !card.imagePath.isEmpty else { return nil }
        let url = FileManager.cardImagesDirectory().appendingPathComponent(card.imagePath)
        return UIImage(contentsOfFile: url.path)
    }
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        LabeledContent(label) {
            TextField(label, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
        }
    }
}
