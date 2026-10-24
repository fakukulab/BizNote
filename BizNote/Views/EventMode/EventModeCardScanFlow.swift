import SwiftUI
import UIKit
import PhotosUI

struct EventModeCardScanFlow: View {
    var onScanned: (EventVisitorDraft) -> Void
    var onCancel: () -> Void

    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var processingTask: Task<Void, Never>?
    @State private var processingTimeoutTask: Task<Void, Never>?
    @State private var photoPickerItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Group {
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(String(localized: "businessCard.ocrProcessing"))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView(
                        errorMessage,
                        systemImage: "exclamationmark.triangle",
                        description: Text(String(localized: "businessCard.retryHint"))
                    )
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(String(localized: "businessCard.rescan")) { self.errorMessage = nil }
                        }
                    }
                } else {
                    #if targetEnvironment(simulator)
                    SimulatorScannerFallback(
                        onPick: { images in startProcessing(images) },
                        onCancel: onCancel
                    )
                    #else
                    BusinessCardScanView(
                        onFinish: { images in
                            guard !images.isEmpty else {
                                errorMessage = BusinessCardScanError.noScannedImage.localizedDescription
                                return
                            }
                            startProcessing(images)
                        },
                        onCancel: onCancel
                    )
                    .ignoresSafeArea()
                    #endif
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) {
                        cancelProcessing()
                        onCancel()
                    }
                }
                if !isProcessing && errorMessage == nil {
                    ToolbarItem(placement: .primaryAction) {
                        PhotosPicker(selection: $photoPickerItems, maxSelectionCount: 2, matching: .images) {
                            Image(systemName: "photo.on.rectangle")
                        }
                        .accessibilityLabel(String(localized: "businessCard.importFromPhotos", defaultValue: "사진 보관함에서 가져오기"))
                    }
                }
            }
            .onChange(of: photoPickerItems) { _, newValue in
                guard !newValue.isEmpty else { return }
                Task {
                    var images: [UIImage] = []
                    for item in newValue {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    if !images.isEmpty {
                        startProcessing(images)
                    }
                    photoPickerItems = []
                }
            }
        }
        .onDisappear { cancelProcessing() }
    }

    private func startProcessing(_ images: [UIImage]) {
        cancelProcessing()
        isProcessing = true
        errorMessage = nil

        let languages = EventModeOCR.recognitionLanguages(prioritizing: EventModeSettings.visitorLanguage)
        let countryCode = EventModeSettings.defaultCountryCode
        let processingID = UUID()
        let currentID = processingID

        processingTask = Task(priority: .userInitiated) {
            do {
                let drafts = try await BusinessCardScanProcessor.process(images, languages: languages)
                let merged = EventVisitorDraft.merging(businessCardDrafts: drafts, countryCode: countryCode)
                guard currentID == processingID else { return }
                processingTimeoutTask?.cancel()
                processingTimeoutTask = nil
                isProcessing = false
                processingTask = nil
                onScanned(merged)
            } catch {
                guard currentID == processingID else { return }
                processingTimeoutTask?.cancel()
                processingTimeoutTask = nil
                errorMessage = error.localizedDescription
                isProcessing = false
                processingTask = nil
            }
        }

        let timeoutSeconds = max(45, images.count * 70)
        processingTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            guard isProcessing else { return }
            processingTask?.cancel()
            processingTask = nil
            errorMessage = OCRService.OCRError.timedOut.localizedDescription
            isProcessing = false
        }
    }

    private func cancelProcessing() {
        processingTask?.cancel()
        processingTimeoutTask?.cancel()
        processingTask = nil
        processingTimeoutTask = nil
        isProcessing = false
    }
}
