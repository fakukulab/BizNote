import SwiftUI
import UIKit

enum BusinessCardScanError: LocalizedError {
    case noScannedImage
    case imageSaveFailed

    var errorDescription: String? {
        switch self {
        case .noScannedImage:
            return String(localized: "businessCard.noScannedImage")
        case .imageSaveFailed:
            return String(localized: "businessCard.imageSaveFailed", defaultValue: "Failed to save the business card image.")
        }
    }
}

enum BusinessCardScanProcessor {
    static func process(_ images: [UIImage], languages: [String]? = nil) async throws -> [BusinessCardDraft] {
        guard !images.isEmpty else {
            throw BusinessCardScanError.noScannedImage
        }

        var drafts: [BusinessCardDraft] = []
        for image in images {
            try Task.checkCancellation()
            drafts.append(try await processSingleImage(image, languages: languages))
        }
        return drafts
    }

    private static func processSingleImage(_ image: UIImage, languages: [String]?) async throws -> BusinessCardDraft {
        let processedImage = BusinessCardImageProcessor.normalizedBusinessCardImage(from: image)
        let ocr = OCRService()
        let parser = BusinessCardParser()
        let baseLanguages = languages ?? OCRService.defaultLanguages

        let processedLines = (try? await ocr.recognizeLines(from: processedImage, languages: baseLanguages)) ?? []
        try Task.checkCancellation()

        var draft = parse(lines: processedLines, parser: parser)
        var bestLines = processedLines
        // The image actually recognized against (may be a desaturated/inverted "enhanced" variant
        // used only to help Vision read glare or dark backgrounds).
        var bestRecognitionImage = processedImage
        // What gets saved to disk for the user to review — never the enhanced variant, since
        // inverting colors for OCR makes the saved photo look wrong.
        var bestDisplayImage = processedImage

        // Once the dominant script is known from the first pass, prioritize it for any retries
        // so Vision stops competing CJK languages against each other.
        let detectedLanguage = OCRService.detectPrimaryLanguage(from: processedLines.map(\.text))
        let retryLanguages = OCRService.prioritizedLanguages(detected: detectedLanguage, base: baseLanguages)

        if shouldRetryRecognition(for: draft, recognizedLines: processedLines) {
            let originalLines = try await ocr.recognizeLines(from: image, languages: retryLanguages)
            try Task.checkCancellation()
            let originalDraft = parse(lines: originalLines, parser: parser)
            if draftScore(originalDraft, recognizedLines: originalLines) > draftScore(draft, recognizedLines: bestLines) {
                draft = originalDraft
                bestLines = originalLines
                bestRecognitionImage = image
                bestDisplayImage = image
            }
        }

        if draftHasNoContactInfo(draft) {
            let enhancedImage = BusinessCardImageProcessor.enhancedImage(from: processedImage)
            let enhancedLines = try await ocr.recognizeLines(from: enhancedImage, languages: retryLanguages)
            try Task.checkCancellation()
            let enhancedDraft = parse(lines: enhancedLines, parser: parser)
            if draftScore(enhancedDraft, recognizedLines: enhancedLines) > draftScore(draft, recognizedLines: bestLines) {
                draft = enhancedDraft
                bestLines = enhancedLines
                bestRecognitionImage = enhancedImage
                // Keep showing the (non-inverted) perspective-corrected photo, not the enhanced one.
                bestDisplayImage = processedImage
            }
        }

        if missingContactField(draft) {
            let correctionOffLines = try? await ocr.recognizeLines(
                from: bestRecognitionImage,
                languages: retryLanguages,
                usesLanguageCorrection: false
            )
            try Task.checkCancellation()
            if let correctionOffLines, !correctionOffLines.isEmpty {
                let mergedLines = mergingCandidates(bestLines, with: correctionOffLines)
                let mergedDraft = parse(lines: mergedLines, parser: parser)
                if draftScore(mergedDraft, recognizedLines: mergedLines) >= draftScore(draft, recognizedLines: bestLines) {
                    draft = mergedDraft
                    bestLines = mergedLines
                }
            }
        }

        if draftHasNoContactInfo(draft), !bestLines.isEmpty {
            draft.memo = bestLines.map(\.text).joined(separator: "\n")
        }

        if let url = try? saveImage(bestDisplayImage, id: draft.id) {
            draft.imagePath = url.lastPathComponent
        } else if let url = try? saveImage(image, id: draft.id) {
            draft.imagePath = url.lastPathComponent
        }

        return draft
    }

    /// Merges text recognized with language correction disabled into the matching (by bounding box
    /// proximity) line from the primary pass, as an extra candidate. Language correction can mangle
    /// numbers, emails, and URLs, but it never overrides the primary text — it only gives the parser
    /// another candidate to fall back on when the primary text fails to match a contact pattern.
    private static func mergingCandidates(
        _ primaryLines: [RecognizedLine],
        with alternateLines: [RecognizedLine]
    ) -> [RecognizedLine] {
        let proximityThreshold = 0.03
        return primaryLines.map { primary in
            guard let match = alternateLines.min(by: {
                lineDistance($0, primary) < lineDistance($1, primary)
            }), lineDistance(match, primary) < proximityThreshold, match.text != primary.text else {
                return primary
            }
            return RecognizedLine(
                text: primary.text,
                candidateTexts: primary.candidateTexts + [match.text] + match.candidateTexts,
                confidence: primary.confidence,
                minX: primary.minX,
                minY: primary.minY,
                width: primary.width,
                height: primary.height
            )
        }
    }

    private static func lineDistance(_ lhs: RecognizedLine, _ rhs: RecognizedLine) -> Double {
        hypot(lhs.midY - rhs.midY, lhs.minX - rhs.minX)
    }

    private static func missingContactField(_ draft: BusinessCardDraft) -> Bool {
        draft.email.isEmpty || draft.phone.isEmpty || draft.website.isEmpty
    }

    private static func parse(lines recognizedLines: [RecognizedLine], parser: BusinessCardParser) -> BusinessCardDraft {
        let lines = recognizedLines.map(\.text)
        let language = OCRService.detectPrimaryLanguage(from: lines)
        return parser.parse(recognizedLines: recognizedLines, language: language)
    }

    private static func shouldRetryRecognition(for draft: BusinessCardDraft, recognizedLines: [RecognizedLine]) -> Bool {
        recognizedLines.isEmpty || draftHasNoContactInfo(draft)
    }

    private static func draftHasNoContactInfo(_ draft: BusinessCardDraft) -> Bool {
        [
            draft.name,
            draft.company,
            draft.jobTitle,
            draft.department,
            draft.email,
            draft.phone,
            draft.officePhone,
            draft.website
        ]
        .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func draftScore(_ draft: BusinessCardDraft, recognizedLines: [RecognizedLine]) -> Int {
        var score = 0
        if !draft.name.isEmpty { score += 4 }
        if !draft.company.isEmpty { score += 4 }
        if !draft.email.isEmpty { score += 3 }
        if !draft.phone.isEmpty { score += 3 }
        if !draft.officePhone.isEmpty { score += 2 }
        if !draft.jobTitle.isEmpty { score += 2 }
        if !draft.department.isEmpty { score += 2 }
        if !draft.website.isEmpty { score += 2 }
        score += min(recognizedLines.count, 8)
        return score
    }

    private static func saveImage(_ image: UIImage, id: UUID) throws -> URL {
        guard let data = jpegData(from: image) else {
            throw BusinessCardScanError.imageSaveFailed
        }

        do {
            let dir = try FileManager.ensureCardImagesDirectory()
            let url = dir.appendingPathComponent("\(id.uuidString).jpg")
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            return url
        } catch {
            throw BusinessCardScanError.imageSaveFailed
        }
    }

    private static func jpegData(from image: UIImage) -> Data? {
        if let renderedImage = renderedImage(from: image) {
            return renderedImage.jpegData(compressionQuality: 0.85)
        }

        return image.jpegData(compressionQuality: 0.85)
    }

    private static func renderedImage(from image: UIImage) -> UIImage? {
        if let cgImage = image.cgImage, image.imageOrientation == .up {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: image.size)).fill()
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

struct BusinessCardDraftsResultView: View {
    @Binding var drafts: [BusinessCardDraft]
    var onDone: ([BusinessCardDraft]) -> Void
    var onRescan: () -> Void

    var body: some View {
        Form {
            ForEach($drafts) { $draft in
                BusinessCardDraftEditorSection(draft: $draft)
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
                    onDone(drafts)
                }
                .disabled(drafts.isEmpty)
            }
        }
    }
}

private struct BusinessCardDraftEditorSection: View {
    @Binding var draft: BusinessCardDraft

    var body: some View {
        Section {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            TextField(String(localized: "businessCard.name"), text: $draft.name)
            LowConfidenceCaption(confidence: draft.fieldConfidence["name"], value: draft.name)
            TextField(String(localized: "businessCard.jobTitle"), text: $draft.jobTitle)
            LowConfidenceCaption(confidence: draft.fieldConfidence["jobTitle"], value: draft.jobTitle)
            TextField(String(localized: "businessCard.company"), text: $draft.company)
            LowConfidenceCaption(confidence: draft.fieldConfidence["company"], value: draft.company)
            TextField(String(localized: "businessCard.department"), text: $draft.department)
            LowConfidenceCaption(confidence: draft.fieldConfidence["department"], value: draft.department)

            DraftLabeledField(label: String(localized: "businessCard.email"),
                              text: $draft.email, keyboard: .emailAddress)
            LowConfidenceCaption(confidence: draft.fieldConfidence["email"], value: draft.email)
            DraftLabeledField(label: String(localized: "businessCard.phone"),
                              text: $draft.phone, keyboard: .phonePad)
            LowConfidenceCaption(confidence: draft.fieldConfidence["phone"], value: draft.phone)
            DraftLabeledField(label: String(localized: "businessCard.officePhone"),
                              text: $draft.officePhone, keyboard: .phonePad)
            LowConfidenceCaption(confidence: draft.fieldConfidence["officePhone"], value: draft.officePhone)
            DraftLabeledField(label: String(localized: "businessCard.website"),
                              text: $draft.website, keyboard: .URL)
            LowConfidenceCaption(confidence: draft.fieldConfidence["website"], value: draft.website)

            TextField(String(localized: "businessCard.memo"), text: $draft.memo, axis: .vertical)
                .lineLimit(2...6)


            BusinessCardContactActionsView(
                name: $draft.name,
                company: $draft.company,
                jobTitle: $draft.jobTitle,
                phone: $draft.phone,
                email: $draft.email
            )
        } header: {
            Text(draft.name.isEmpty ? String(localized: "businessCard.name") : draft.name)
        }
    }

    private func loadImage() -> UIImage? {
        guard !draft.imagePath.isEmpty else { return nil }
        let url = FileManager.cardImagesDirectory().appendingPathComponent(draft.imagePath)
        return UIImage(contentsOfFile: url.path)
    }
}

/// Shown under a field whose OCR confidence fell below the threshold, so the user knows to
/// double-check it against the card photo above rather than trusting it blindly.
private struct LowConfidenceCaption: View {
    let confidence: Double?
    let value: String

    private static let threshold = 0.5

    private var isLowConfidence: Bool {
        guard let confidence else { return false }
        return confidence < Self.threshold && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if isLowConfidence {
            Label(
                String(localized: "businessCard.lowConfidenceHint", defaultValue: "인식 신뢰도가 낮아요. 원본 이미지를 확인해 주세요."),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption2)
            .foregroundStyle(.orange)
        }
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
struct SimulatorScannerFallback: View {
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
        return base.appendingPathComponent("BusinessCards", isDirectory: true)
    }

    static func ensureCardImagesDirectory() throws -> URL {
        let dir = cardImagesDirectory()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        } else {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: dir.path
            )
        }
        return dir
    }
}
