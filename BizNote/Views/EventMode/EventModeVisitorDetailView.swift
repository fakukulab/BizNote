import SwiftUI
import SwiftData
import UIKit

struct EventModeVisitorDetailView: View {
    @Bindable var visitor: EventVisitor
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showCountryPicker = false
    @State private var showDeleteConfirm = false
    @State private var showCardImageViewer = false
    @State private var cardImage: UIImage?

    var body: some View {
        Form {
            if let cardImage {
                Section {
                    Button {
                        showCardImageViewer = true
                    } label: {
                        Image(uiImage: cardImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(.rect(cornerRadius: EventModeDesign.cardImageCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                LabeledContent(String(localized: "eventMode.field.name", defaultValue: "이름")) {
                    TextField("", text: $visitor.name).multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "eventMode.field.company", defaultValue: "회사명")) {
                    TextField("", text: $visitor.company).multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "eventMode.field.jobTitle", defaultValue: "직급")) {
                    TextField("", text: $visitor.jobTitle).multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "eventMode.field.email", defaultValue: "이메일")) {
                    TextField("", text: $visitor.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "eventMode.field.mobile", defaultValue: "휴대폰")) {
                    TextField("", text: $visitor.mobile)
                        .keyboardType(.phonePad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "eventMode.field.phone", defaultValue: "전화번호")) {
                    TextField("", text: $visitor.phone)
                        .keyboardType(.phonePad)
                        .multilineTextAlignment(.trailing)
                }
                Button {
                    showCountryPicker = true
                } label: {
                    LabeledContent(String(localized: "eventMode.field.country", defaultValue: "국가")) {
                        Text(countryDisplayName)
                    }
                }
                .foregroundStyle(.primary)
            }

            Section(String(localized: "eventMode.field.interestArea", defaultValue: "관심분야")) {
                if let interestArea = visitor.interestArea {
                    Label(interestArea.localizedName, systemImage: interestArea.iconName)
                        .font(.headline)
                        .foregroundStyle(interestArea.accentColor)
                } else {
                    Text(String(localized: "eventMode.country.unspecified", defaultValue: "선택 안 함"))
                        .foregroundStyle(.secondary)
                }
                Picker(String(localized: "eventMode.field.interestArea", defaultValue: "관심분야"), selection: $visitor.interestArea) {
                    Text(String(localized: "eventMode.country.unspecified", defaultValue: "선택 안 함")).tag(EventVisitorInterestArea?.none)
                    ForEach(EventVisitorInterestArea.allCases) { area in
                        Text(area.localizedName).tag(EventVisitorInterestArea?.some(area))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if let wantsMaterials = visitor.wantsMaterials {
                    Label(
                        wantsMaterials
                            ? String(localized: "eventMode.list.materialsRequested", defaultValue: "자료 요청함")
                            : String(localized: "eventMode.list.materialsNotRequested", defaultValue: "자료 요청 안 함"),
                        systemImage: wantsMaterials ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .font(.headline)
                    .foregroundStyle(wantsMaterials ? Color.green : Color.secondary)
                } else {
                    Text(String(localized: "eventMode.country.unspecified", defaultValue: "선택 안 함"))
                        .foregroundStyle(.secondary)
                }
                Picker(String(localized: "eventMode.field.wantsMaterials", defaultValue: "관심분야에 대한 자료를 요청하시겠습니까?"), selection: $visitor.wantsMaterials) {
                    Text(String(localized: "eventMode.country.unspecified", defaultValue: "선택 안 함")).tag(Bool?.none)
                    Text(String(localized: "action.yes", defaultValue: "예")).tag(Bool?.some(true))
                    Text(String(localized: "action.no", defaultValue: "아니오")).tag(Bool?.some(false))
                }
            }

            Section(String(localized: "eventMode.detail.memo", defaultValue: "메모")) {
                TextField(
                    String(localized: "eventMode.detail.memo", defaultValue: "메모"),
                    text: $visitor.memo,
                    axis: .vertical
                )
                .lineLimit(4...)
            }

            Section {
                LabeledContent(String(localized: "eventMode.detail.registeredAt", defaultValue: "등록일시")) {
                    Text(DateFormatter.exportTimestamp.string(from: visitor.createdAt))
                }
                LabeledContent(String(localized: "eventMode.detail.collectionMethod", defaultValue: "수집 방식")) {
                    Text(visitor.collectionMethod.localizedName)
                }
            }
            .foregroundStyle(.secondary)

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text(String(localized: "note.delete"))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(visitor.name.isEmpty ? String(localized: "note.untitled") : visitor.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCountryPicker) {
            EventCountryPickerView(selection: $visitor.countryCode)
        }
        .confirmationDialog(
            String(localized: "eventMode.detail.deleteConfirm", defaultValue: "이 방문객 정보를 삭제할까요?"),
            isPresented: $showDeleteConfirm
        ) {
            Button(String(localized: "note.delete"), role: .destructive) {
                context.delete(visitor)
                try? context.save()
                dismiss()
            }
            Button(String(localized: "action.cancel"), role: .cancel) {}
        }
        .onDisappear {
            try? context.save()
        }
        .task {
            guard !visitor.cardImagePath.isEmpty else { return }
            let url = FileManager.cardImagesDirectory().appending(path: visitor.cardImagePath)
            cardImage = UIImage(contentsOfFile: url.path)
        }
        .fullScreenCover(isPresented: $showCardImageViewer) {
            if let cardImage {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: cardImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Button(String(localized: "action.close", defaultValue: "닫기"), systemImage: "xmark.circle.fill") {
                        showCardImageViewer = false
                    }
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding()
                }
            }
        }
    }

    private var countryDisplayName: String {
        guard !visitor.countryCode.isEmpty else {
            return String(localized: "eventMode.country.unspecified", defaultValue: "선택 안 함")
        }
        return EventCountry(code: visitor.countryCode).localizedName
    }
}
