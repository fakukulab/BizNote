import SwiftUI
import UIKit
import VisionKit
import PhotosUI

struct BusinessCardScanView: UIViewControllerRepresentable {
    var onFinish: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: BusinessCardScanView
        init(_ parent: BusinessCardScanView) { self.parent = parent }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            parent.onFinish(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onCancel()
        }
    }
}

struct BusinessCardScanFlow: View {
    var onSave: ([BusinessCardDraft]) throws -> Void
    var onComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var scannedImages: [UIImage] = []
    @State private var isProcessing: Bool = false
    @State private var processedDrafts: [BusinessCardDraft] = []
    @State private var errorMessage: String?
    @State private var processingTask: Task<Void, Never>?
    @State private var processingTimeoutTask: Task<Void, Never>?
    @State private var currentProcessingID: UUID?
    @State private var saveErrorMessage: String?
    @State private var photoPickerItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Group {
                if !processedDrafts.isEmpty {
                    BusinessCardDraftsResultView(
                        drafts: $processedDrafts,
                        onDone: { drafts in finishScan(with: drafts) },
                        onRescan: { restartScan() }
                    )
                } else if isProcessing {
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
                            Button(String(localized: "businessCard.rescan")) { restartScan() }
                        }
                    }
                } else {
                    #if targetEnvironment(simulator)
                    SimulatorScannerFallback(
                        onPick: { images in
                            startProcessing(images)
                        },
                        onCancel: { dismiss() }
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
                        onCancel: { dismiss() }
                    )
                    .ignoresSafeArea()
                    #endif
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) {
                        cancelProcessing()
                        dismiss()
                    }
                }
                if processedDrafts.isEmpty && !isProcessing && errorMessage == nil {
                    ToolbarItem(placement: .primaryAction) {
                        PhotosPicker(selection: $photoPickerItems, maxSelectionCount: nil, matching: .images) {
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
                    await MainActor.run {
                        if !images.isEmpty {
                            startProcessing(images)
                        }
                        photoPickerItems = []
                    }
                }
            }
            .alert(String(localized: "businessCard.saveFailed"), isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button(String(localized: "action.done"), role: .cancel) {
                    saveErrorMessage = nil
                }
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    private func restartScan() {
        cancelProcessing()
        processedDrafts = []
        scannedImages = []
        errorMessage = nil
        saveErrorMessage = nil
    }

    @MainActor
    private func finishScan(with drafts: [BusinessCardDraft]) {
        do {
            try onSave(drafts)
            if let onComplete {
                onComplete()
            } else {
                dismiss()
            }
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func startProcessing(_ images: [UIImage]) {
        cancelProcessing()

        let processingID = UUID()
        currentProcessingID = processingID
        scannedImages = images
        processedDrafts = []
        errorMessage = nil
        isProcessing = true

        processingTask = Task.detached(priority: .userInitiated) {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            do {
                let drafts = try await BusinessCardScanProcessor.process(images)
                await MainActor.run {
                    guard currentProcessingID == processingID else { return }
                    processingTimeoutTask?.cancel()
                    processingTimeoutTask = nil
                    isProcessing = false
                    currentProcessingID = nil
                    processingTask = nil
                    processedDrafts = drafts
                }
            } catch {
                await MainActor.run {
                    guard currentProcessingID == processingID else { return }
                    processingTimeoutTask?.cancel()
                    processingTimeoutTask = nil
                    errorMessage = error.localizedDescription
                    isProcessing = false
                    currentProcessingID = nil
                    processingTask = nil
                }
            }
        }

        let timeoutSeconds = max(45, images.count * 70)
        processingTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            guard currentProcessingID == processingID, isProcessing else { return }
            processingTask?.cancel()
            processingTask = nil
            errorMessage = OCRService.OCRError.timedOut.localizedDescription
            isProcessing = false
            currentProcessingID = nil
        }
    }

    private func cancelProcessing() {
        processingTask?.cancel()
        processingTimeoutTask?.cancel()
        processingTask = nil
        processingTimeoutTask = nil
        currentProcessingID = nil
        isProcessing = false
    }
}
