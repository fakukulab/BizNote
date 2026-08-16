import SwiftUI
import SwiftData
import VisionKit

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
            controller.dismiss(animated: true) { [parent] in
                parent.onFinish(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [parent] in
                parent.onCancel()
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true) { [parent] in
                parent.onCancel()
            }
        }
    }
}

struct BusinessCardScanFlow: View {
    var onSave: (BusinessCardDraft) throws -> Void
    var onComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var scannedImages: [UIImage] = []
    @State private var isProcessing: Bool = false
    @State private var processedDraft: BusinessCardDraft?
    @State private var errorMessage: String?
    @State private var processingTask: Task<Void, Never>?
    @State private var processingTimeoutTask: Task<Void, Never>?
    @State private var currentProcessingID: UUID?
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if processedDraft != nil {
                    BusinessCardDraftResultView(
                        draft: Binding(
                            get: { processedDraft ?? BusinessCardDraft() },
                            set: { processedDraft = $0 }
                        ),
                        onDone: { draft in finishScan(with: draft) },
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
        processedDraft = nil
        scannedImages = []
        errorMessage = nil
        saveErrorMessage = nil
    }

    @MainActor
    private func finishScan(with draft: BusinessCardDraft) {
        do {
            try onSave(draft)
            onComplete?()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func startProcessing(_ images: [UIImage]) {
        cancelProcessing()

        let processingID = UUID()
        currentProcessingID = processingID
        scannedImages = images
        processedDraft = nil
        errorMessage = nil
        isProcessing = true

        processingTask = Task.detached(priority: .userInitiated) {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            do {
                let draft = try await BusinessCardScanProcessor.process(images)
                await MainActor.run {
                    guard currentProcessingID == processingID else { return }
                    processingTimeoutTask?.cancel()
                    processingTimeoutTask = nil
                    isProcessing = false
                    currentProcessingID = nil
                    processingTask = nil
                    processedDraft = draft
                    finishScan(with: draft)
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

        processingTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(25))
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

private enum BusinessCardScanError: LocalizedError {
    case noScannedImage

    var errorDescription: String? {
        switch self {
        case .noScannedImage:
            return String(localized: "businessCard.noScannedImage")
        }
    }
}

private enum BusinessCardScanProcessor {
    static func process(_ images: [UIImage]) async throws -> BusinessCardDraft {
        guard let first = images.first else {
            throw BusinessCardScanError.noScannedImage
        }

        let ocr = OCRService()
        let lines = try await ocr.recognizeText(from: first)
        try Task.checkCancellation()

        let language = OCRService.detectPrimaryLanguage(from: lines)
        let parser = BusinessCardParser()
        var draft = parser.parse(lines: lines, language: language)

        if let url = saveImage(first, id: draft.id) {
            draft.imagePath = url.lastPathComponent
        }

        return draft
    }

    private static func saveImage(_ image: UIImage, id: UUID) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let dir = FileManager.cardImagesDirectory()
        let url = dir.appendingPathComponent("\(id.uuidString).jpg")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

private struct BusinessCardDraftResultView: View {
    @Binding var draft: BusinessCardDraft
    var onDone: (BusinessCardDraft) -> Void
    var onRescan: () -> Void

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
                TextField(String(localized: "businessCard.name"), text: $draft.name)
                TextField(String(localized: "businessCard.jobTitle"), text: $draft.jobTitle)
            }

            Section(String(localized: "businessCard.company")) {
                TextField(String(localized: "businessCard.company"), text: $draft.company)
                TextField(String(localized: "businessCard.department"), text: $draft.department)
            }

            Section(String(localized: "businessCard.contact")) {
                DraftLabeledField(label: String(localized: "businessCard.email"),
                                  text: $draft.email, keyboard: .emailAddress)
                DraftLabeledField(label: String(localized: "businessCard.phone"),
                                  text: $draft.phone, keyboard: .phonePad)
                DraftLabeledField(label: String(localized: "businessCard.officePhone"),
                                  text: $draft.officePhone, keyboard: .phonePad)
                DraftLabeledField(label: String(localized: "businessCard.fax"),
                                  text: $draft.fax, keyboard: .phonePad)
                DraftLabeledField(label: String(localized: "businessCard.website"),
                                  text: $draft.website, keyboard: .URL)
                DraftLabeledField(label: String(localized: "businessCard.address"),
                                  text: $draft.address, keyboard: .default)
            }

            Section(String(localized: "businessCard.memo")) {
                TextField(String(localized: "businessCard.memo"), text: $draft.memo, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle(String(localized: "businessCard.scanTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    onRescan()
                } label: {
                    Label(String(localized: "businessCard.rescan"), systemImage: "camera.rotate")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "action.save")) {
                    onDone(draft)
                }
            }
        }
    }

    private func loadImage() -> UIImage? {
        guard !draft.imagePath.isEmpty else { return nil }
        let url = FileManager.cardImagesDirectory().appendingPathComponent(draft.imagePath)
        return UIImage(contentsOfFile: url.path)
    }
}

private struct DraftLabeledField: View {
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

private enum BusinessCardScanLocalized {
    static let simulatorCameraUnavailable = String(localized: "businessCard.simulatorCameraUnavailable")
    static let simulatorSampleHint = String(localized: "businessCard.simulatorSampleHint")
    static let useSampleCard = String(localized: "businessCard.useSampleCard")
}

#if targetEnvironment(simulator)
private struct SimulatorScannerFallback: View {
    var onPick: ([UIImage]) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            Text(BusinessCardScanLocalized.simulatorCameraUnavailable)
                .font(.headline)
            Text(BusinessCardScanLocalized.simulatorSampleHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                onPick([sampleImage()])
            } label: {
                Label(BusinessCardScanLocalized.useSampleCard, systemImage: "doc.text.image")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func sampleImage() -> UIImage {
        let size = CGSize(width: 900, height: 540)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let lines = [
                "홍길동",
                "주식회사 비즈노트",
                "개발본부 팀장",
                "hong@biznote.co.kr",
                "010-1234-5678",
                "02-555-1234",
                "FAX: 02-555-1235",
                "www.biznote.co.kr",
                "서울시 강남구 테헤란로 123"
            ]
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32),
                .foregroundColor: UIColor.black
            ]
            for (i, line) in lines.enumerated() {
                let point = CGPoint(x: 40, y: 40 + i * 50)
                line.draw(at: point, withAttributes: attrs)
            }
        }
    }
}
#endif

extension FileManager {
    static func cardImagesDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("BusinessCards", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
