import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import LocalAuthentication

struct EventModeSettingsView: View {
    @AppStorage(EventModeSettings.visitorLanguageKey) private var languageRaw: String = EventModeLanguage.korean.rawValue
    @AppStorage(EventModeSettings.defaultCountryCodeKey) private var defaultCountryCode: String = "KR"
    @State private var consentOverrideText = EventModeSettings.consentTextOverride ?? EventModeSettings.defaultConsentText
    @AppStorage(EventModeSettings.biometricUnlockEnabledKey) private var biometricUnlockEnabled = false

    @State private var showCountryPicker = false
    @State private var showPINSetup = false
    @State private var showResetVisitors = false
    @State private var pinExists = EventModeSettings.staffPIN != nil
    @State private var videoFilenames = EventModeSettings.promoVideoFilenames
    @AppStorage(EventModeSettings.promoVideoMutedKey) private var isVideoMuted = true
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var videoImportErrorMessage: String?
    @State private var biometryLabel: String = {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        case .touchID: return "Touch ID"
        default: return String(localized: "eventMode.settings.biometric", defaultValue: "생체 인증")
        }
    }()

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "eventMode.settings.language", defaultValue: "언어 설정"), selection: $languageRaw) {
                    ForEach(EventModeLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
            } footer: {
                Text(String(
                    localized: "eventMode.settings.language.footer",
                    defaultValue: "수집 화면과 직접 입력 화면에 표시되는 언어입니다."
                ))
            }

            Section(String(localized: "eventMode.settings.country", defaultValue: "방문객 국가 설정")) {
                Button {
                    showCountryPicker = true
                } label: {
                    LabeledContent(String(localized: "eventMode.settings.country.default", defaultValue: "기본 국가")) {
                        Text(EventCountry(code: defaultCountryCode).localizedName)
                    }
                }
                .foregroundStyle(.primary)
            }

            Section {
                LabeledContent(String(localized: "eventMode.settings.pin", defaultValue: "담당자 PIN")) {
                    Text(pinExists
                        ? String(localized: "eventMode.settings.pin.set", defaultValue: "설정됨")
                        : String(localized: "eventMode.settings.pin.unset", defaultValue: "설정 안 함"))
                        .foregroundStyle(.secondary)
                }
                Button(pinExists
                    ? String(localized: "eventMode.settings.pin.change", defaultValue: "PIN 변경")
                    : String(localized: "eventMode.settings.pin.setup", defaultValue: "PIN 설정")
                ) {
                    showPINSetup = true
                }
                if pinExists {
                    Button(role: .destructive) {
                        EventModeSettings.staffPIN = nil
                        pinExists = false
                        biometricUnlockEnabled = false
                    } label: {
                        Text(String(localized: "eventMode.settings.pin.remove", defaultValue: "PIN 해제"))
                    }

                    Toggle(isOn: $biometricUnlockEnabled) {
                        Text(String(format: String(localized: "eventMode.settings.biometric.toggle", defaultValue: "%@로 잠금 해제"), biometryLabel))
                    }
                }
            } footer: {
                Text(String(
                    localized: "eventMode.settings.pin.footer",
                    defaultValue: "PIN을 설정하지 않으면 수집 화면 우측 상단을 길게 눌러 바로 담당자 화면으로 진입합니다."
                ))
            }

            Section {
                TextField(
                    String(localized: "eventMode.settings.consent", defaultValue: "개인정보 동의 문구"),
                    text: $consentOverrideText,
                    axis: .vertical
                )
                .lineLimit(5...)
                .onChange(of: consentOverrideText) { _, newValue in
                    EventModeSettings.consentTextOverride = newValue
                }
            } header: {
                Text(String(localized: "eventMode.settings.consent", defaultValue: "개인정보 동의 문구"))
            } footer: {
                Text(String(
                    localized: "eventMode.settings.consent.footer",
                    defaultValue: "이 문구는 언어 설정이 한국어일 때 표시됩니다. 다른 언어는 자동으로 번역된 기본 문구가 표시됩니다."
                ))
            }

            Section {
                Toggle(isOn: $isVideoMuted) {
                    Text(String(localized: "eventMode.settings.video.muted", defaultValue: "무음으로 재생"))
                }

                if videoFilenames.isEmpty {
                    Text(String(localized: "eventMode.settings.video.empty", defaultValue: "선택된 영상이 없습니다. 영상이 없으면 기본 안내 화면이 표시됩니다."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(videoFilenames, id: \.self) { filename in
                        Text(filename)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            EventModeVideoStorage.remove(filename: videoFilenames[index])
                        }
                        videoFilenames.remove(atOffsets: indexSet)
                        EventModeSettings.promoVideoFilenames = videoFilenames
                    }
                }

                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: nil,
                    matching: .videos
                ) {
                    Text(String(localized: "eventMode.settings.video.fromPhotos", defaultValue: "사진 앱에서 선택"))
                }

                Button {
                    showFileImporter = true
                } label: {
                    Text(String(localized: "eventMode.settings.video.fromFiles", defaultValue: "파일 앱에서 선택"))
                }
            } header: {
                Text(String(localized: "eventMode.settings.video", defaultValue: "홍보 영상"))
            } footer: {
                Text(String(
                    localized: "eventMode.settings.video.footer",
                    defaultValue: "수집 화면에서 반복 재생됩니다. 여러 개 선택 시 순서대로 이어서 재생합니다."
                ))
            }

            Section {
                Button(role: .destructive) {
                    showResetVisitors = true
                } label: {
                    Text(String(localized: "eventMode.settings.resetVisitors", defaultValue: "방문객 목록 초기화"))
                }
            } header: {
                Text(String(localized: "eventMode.settings.dataReset", defaultValue: "데이터 초기화"))
            } footer: {
                Text(String(
                    localized: "eventMode.settings.resetVisitors.footer",
                    defaultValue: "행사 모드에서 수집한 방문객 정보만 삭제됩니다. 저장된 행사 정보, 일반 노트, 명함 데이터에는 영향을 주지 않습니다."
                ))
            }
        }
        .navigationTitle(String(localized: "eventMode.tab.settings", defaultValue: "설정"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCountryPicker) {
            EventCountryPickerView(selection: $defaultCountryCode)
        }
        .sheet(isPresented: $showPINSetup) {
            EventModePINSetupView {
                pinExists = EventModeSettings.staffPIN != nil
            }
        }
        .sheet(isPresented: $showResetVisitors) {
            EventModeResetVisitorsView()
        }
        .onChange(of: photoPickerItems) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                await AdService.shared.showInterstitial()
                var importedFilenames: [String] = []
                var hadFailure = false
                for item in newValue {
                    do {
                        if let movie = try await item.loadTransferable(type: EventModeTransferableMovie.self) {
                            importedFilenames.append(movie.importedFilename)
                        } else {
                            hadFailure = true
                        }
                    } catch {
                        hadFailure = true
                    }
                }
                videoFilenames.append(contentsOf: importedFilenames)
                EventModeSettings.promoVideoFilenames = videoFilenames
                photoPickerItems = []
                if hadFailure {
                    videoImportErrorMessage = String(localized: "eventMode.settings.video.importFailed", defaultValue: "영상을 가져오지 못했습니다.")
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    await AdService.shared.showInterstitial()
                    var hadFailure = false
                    let importedFilenames: [String] = urls.compactMap { url in
                        do {
                            return try EventModeVideoStorage.importVideo(from: url)
                        } catch {
                            hadFailure = true
                            return nil
                        }
                    }
                    videoFilenames.append(contentsOf: importedFilenames)
                    EventModeSettings.promoVideoFilenames = videoFilenames
                    if hadFailure {
                        videoImportErrorMessage = String(localized: "eventMode.settings.video.importFailed", defaultValue: "영상을 가져오지 못했습니다.")
                    }
                }
            case .failure:
                videoImportErrorMessage = String(localized: "eventMode.settings.video.importFailed", defaultValue: "영상을 가져오지 못했습니다.")
            }
        }
        .alert(
            String(localized: "eventMode.settings.video.importFailedTitle", defaultValue: "가져오기 실패"),
            isPresented: Binding(
                get: { videoImportErrorMessage != nil },
                set: { if !$0 { videoImportErrorMessage = nil } }
            )
        ) {
            Button(String(localized: "action.done"), role: .cancel) {}
        } message: {
            Text(videoImportErrorMessage ?? "")
        }
    }
}
