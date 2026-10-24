import SwiftUI
import SwiftData
import UIKit

private enum EventModeManualEntryField: Hashable {
    case name, company, jobTitle, email, mobile, phone
}

struct EventModeManualEntryView: View {
    @Bindable var preset: ExhibitionPreset
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft: EventVisitorDraft
    @State private var hasAgreedToConsent = false
    @State private var showCountryPicker = false
    @State private var showValidationError = false
    @State private var showSavedToast = false
    @FocusState private var focusedField: EventModeManualEntryField?

    private let initialCollectionMethod: EventVisitorCollectionMethod

    init(
        preset: ExhibitionPreset,
        initialDraft: EventVisitorDraft? = nil,
        initialCollectionMethod: EventVisitorCollectionMethod = .manualInput
    ) {
        self.preset = preset
        self._draft = State(initialValue: initialDraft ?? EventVisitorDraft())
        self.initialCollectionMethod = initialCollectionMethod
    }

    var body: some View {
        NavigationStack {
            Form {
                if !draft.cardImagePath.isEmpty {
                    Section {
                        cardImageView
                            .frame(maxWidth: .infinity)
                            .clipShape(.rect(cornerRadius: EventModeDesign.cardImageCornerRadius))
                    }
                }

                Section {
                    field(EventModeSettings.localized("eventMode.field.name", defaultValue: "이름"), text: $draft.name, field: .name, next: .company)
                        .textContentType(.name)
                    field(EventModeSettings.localized("eventMode.field.company", defaultValue: "회사명"), text: $draft.company, field: .company, next: .jobTitle)
                        .textContentType(.organizationName)
                    field(EventModeSettings.localized("eventMode.field.jobTitle", defaultValue: "직급"), text: $draft.jobTitle, field: .jobTitle, next: .email)
                        .textContentType(.jobTitle)
                    field(EventModeSettings.localized("eventMode.field.email", defaultValue: "이메일"), text: $draft.email, field: .email, next: .mobile)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    field(EventModeSettings.localized("eventMode.field.mobile", defaultValue: "휴대폰"), text: $draft.mobile, field: .mobile, next: .phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    field(EventModeSettings.localized("eventMode.field.phone", defaultValue: "전화번호"), text: $draft.phone, field: .phone, next: nil)
                        .keyboardType(.phonePad)

                    Button {
                        showCountryPicker = true
                    } label: {
                        HStack {
                            Text(EventModeSettings.localized("eventMode.field.country", defaultValue: "국가"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(countryDisplayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(EventModeSettings.localized("eventMode.field.footer", defaultValue: "이름과 이메일 또는 휴대폰 번호는 필수입니다."))
                }

                Section {
                    ForEach(EventVisitorInterestArea.allCases) { area in
                        EventModeRadioRow(
                            title: area.localizedName(locale: EventModeSettings.visitorLanguage.locale),
                            isSelected: draft.interestArea == area
                        ) {
                            draft.interestArea = area
                        }
                    }
                } header: {
                    Text(EventModeSettings.localized("eventMode.field.interestArea", defaultValue: "관심분야"))
                }

                Section {
                    EventModeRadioRow(
                        title: EventModeSettings.localized("action.yes", defaultValue: "예"),
                        isSelected: draft.wantsMaterials == true
                    ) {
                        draft.wantsMaterials = true
                    }
                    EventModeRadioRow(
                        title: EventModeSettings.localized("action.no", defaultValue: "아니오"),
                        isSelected: draft.wantsMaterials == false
                    ) {
                        draft.wantsMaterials = false
                    }
                } header: {
                    Text(EventModeSettings.localized("eventMode.field.wantsMaterials", defaultValue: "관심분야에 대한 자료를 요청하시겠습니까?"))
                }

                Section {
                    Toggle(isOn: $hasAgreedToConsent) {
                        Text(EventModeSettings.consentText)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(EventModeSettings.localized("eventMode.manualEntry.title", defaultValue: "방문객 정보 입력"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(EventModeSettings.localized("action.cancel", defaultValue: "취소")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(EventModeSettings.localized("action.save", defaultValue: "저장")) { attemptSave() }
                        .disabled(!draft.isValid || !hasAgreedToConsent)
                }
            }
            .overlay(alignment: .top) {
                if showSavedToast {
                    Text(EventModeSettings.localized("eventMode.collection.registered", defaultValue: "등록되었습니다"))
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 12)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .alert(
                EventModeSettings.localized("eventMode.manualEntry.invalidTitle", defaultValue: "입력값을 확인해 주세요"),
                isPresented: $showValidationError
            ) {
                Button(EventModeSettings.localized("action.done", defaultValue: "완료"), role: .cancel) {}
            } message: {
                Text(EventModeSettings.localized("eventMode.manualEntry.invalidMessage", defaultValue: "이름과 이메일 또는 휴대폰 번호를 입력하고, 개인정보 수집에 동의해 주세요."))
            }
            .sheet(isPresented: $showCountryPicker) {
                EventCountryPickerView(selection: $draft.countryCode, locale: EventModeSettings.visitorLanguage.locale)
            }
        }
        .onAppear {
            if draft.countryCode.isEmpty {
                draft.countryCode = EventModeSettings.defaultCountryCode
            }
            if draft.name.isEmpty {
                focusedField = .name
            }
        }
    }

    @ViewBuilder
    private var cardImageView: some View {
        if let image = UIImage(contentsOfFile: FileManager.cardImagesDirectory().appending(path: draft.cardImagePath).path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }

    private var countryDisplayName: String {
        guard !draft.countryCode.isEmpty else {
            return EventModeSettings.localized("eventMode.country.unspecified", defaultValue: "선택 안 함")
        }
        return EventCountry(code: draft.countryCode).localizedName(locale: EventModeSettings.visitorLanguage.locale)
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        field: EventModeManualEntryField,
        next: EventModeManualEntryField?
    ) -> some View {
        TextField(title, text: text)
            .focused($focusedField, equals: field)
            .submitLabel(next == nil ? .done : .next)
            .onSubmit {
                if let next {
                    focusedField = next
                } else {
                    attemptSave()
                }
            }
    }

    private func attemptSave() {
        guard draft.isValid, hasAgreedToConsent else {
            showValidationError = true
            return
        }

        let visitor = EventVisitor(
            draft: draft,
            collectionMethod: initialCollectionMethod,
            consentAt: .now,
            exhibitionPreset: preset
        )
        context.insert(visitor)
        try? context.save()

        focusedField = nil
        withAnimation { showSavedToast = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            draft = EventVisitorDraft()
            hasAgreedToConsent = false
            dismiss()
        }
    }
}
