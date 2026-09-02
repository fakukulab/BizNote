@preconcurrency import Vision
import ImageIO
import UIKit

struct RecognizedLine: Sendable {
    let text: String
    let candidateTexts: [String]
    let confidence: Float
    let minX: Double
    let minY: Double
    let width: Double
    let height: Double

    init(
        text: String,
        candidateTexts: [String] = [],
        confidence: Float,
        minX: Double,
        minY: Double,
        width: Double,
        height: Double
    ) {
        self.text = text
        self.candidateTexts = candidateTexts
        self.confidence = confidence
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }

    var maxY: Double { minY + height }
    var midY: Double { minY + height / 2 }
}

final class OCRService: @unchecked Sendable {
    enum OCRError: LocalizedError {
        case invalidImage
        case timedOut
        var errorDescription: String? {
            switch self {
            case .invalidImage: return String(localized: "ocr.error.invalidImage")
            case .timedOut: return String(localized: "ocr.error.timedOut")
            }
        }
    }

    func recognizeText(
        from image: UIImage,
        languages: [String] = ["ko-KR", "en-US", "ja-JP", "zh-Hans", "zh-Hant"],
        timeout: Duration = .seconds(30)
    ) async throws -> [String] {
        try await recognizeLines(from: image, languages: languages, timeout: timeout).map(\.text)
    }

    func recognizeLines(
        from image: UIImage,
        languages: [String] = ["ko-KR", "en-US", "ja-JP", "zh-Hans", "zh-Hant"],
        timeout: Duration = .seconds(30)
    ) async throws -> [RecognizedLine] {
        let raceState = OCRRaceState<[RecognizedLine]>()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                raceState.start(continuation: continuation)

                let recognitionTask = Task.detached(priority: .userInitiated) {
                    do {
                        let lines = try await self.performRecognitionLines(from: image, languages: languages)
                        raceState.finish(.success(lines))
                    } catch {
                        raceState.finish(.failure(error))
                    }
                }
                let timeoutTask = Task.detached(priority: .userInitiated) {
                    do {
                        try await Task.sleep(for: timeout)
                        raceState.finish(.failure(OCRError.timedOut))
                    } catch {
                        raceState.finish(.failure(error))
                    }
                }

                raceState.setTasks(recognitionTask: recognitionTask, timeoutTask: timeoutTask)
            }
        } onCancel: {
            raceState.cancel()
        }
    }

    private func performRecognitionLines(
        from image: UIImage,
        languages: [String]
    ) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let requestBox = RequestBox()
        let recognitionState = OCRRaceState<[RecognizedLine]>()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                recognitionState.start(continuation: continuation)

                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        recognitionState.finish(.failure(error))
                        return
                    }
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let lines = observations.compactMap { observation -> RecognizedLine? in
                        let candidates = observation.topCandidates(3)
                        guard let candidate = self.preferredCandidate(from: candidates) else { return nil }
                        let box = observation.boundingBox
                        return RecognizedLine(
                            text: candidate.string,
                            candidateTexts: candidates.map(\.string),
                            confidence: candidate.confidence,
                            minX: Double(box.minX),
                            minY: Double(box.minY),
                            width: Double(box.width),
                            height: Double(box.height)
                        )
                    }
                    .sorted {
                        let yDifference = abs($0.midY - $1.midY)
                        if yDifference > 0.025 {
                            return $0.midY > $1.midY
                        }
                        return $0.minX < $1.minX
                    }
                    recognitionState.finish(.success(lines))
                }
                request.recognitionLanguages = languages
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                requestBox.request = request

                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: CGImagePropertyOrientation(image.imageOrientation),
                    options: [:]
                )
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try handler.perform([request])
                    } catch {
                        recognitionState.finish(.failure(error))
                    }
                }
            }
        } onCancel: {
            requestBox.request?.cancel()
            recognitionState.cancel()
        }
    }

    private func preferredCandidate(from candidates: [VNRecognizedText]) -> VNRecognizedText? {
        candidates.max {
            candidateScore($0) < candidateScore($1)
        }
    }

    private func candidateScore(_ candidate: VNRecognizedText) -> Double {
        let text = candidate.string
        var score = Double(candidate.confidence)

        if looksLikeEmail(text) {
            score += 0.45
        }
        if looksLikePhoneNumber(text) {
            score += 0.35
        }
        if looksLikeURL(text) {
            score += 0.3
        }
        if containsContactLabel(text) {
            score += 0.12
        }

        return score
    }

    private func looksLikeEmail(_ text: String) -> Bool {
        let pattern = #"[A-Za-z0-9._%+\-]+[@＠][A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private func looksLikePhoneNumber(_ text: String) -> Bool {
        let normalized = text
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "o", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "l", with: "1")
        let pattern = #"(?:\+\d{1,3}[-\s]?|0)\d{1,3}[-\s]?\d{3,4}[-\s]?\d{4}"#
        return normalized.range(of: pattern, options: .regularExpression) != nil
    }

    private func looksLikeURL(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("www.") ||
            lowercased.contains("http://") ||
            lowercased.contains("https://") ||
            lowercased.range(of: #"\.[a-z0-9]{2,4}\b"#, options: .regularExpression) != nil
    }

    private func containsContactLabel(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return ["tel", "phone", "mobile", "cell", "fax", "email", "mail", "www"].contains {
            lowercased.contains($0)
        }
    }

    static func detectPrimaryLanguage(from lines: [String]) -> String {
        let combined = lines.joined(separator: " ")
        let koreanCount = combined.unicodeScalars.filter {
            (0xAC00...0xD7AF).contains($0.value)
        }.count
        let chineseCount = combined.unicodeScalars.filter {
            (0x4E00...0x9FFF).contains($0.value)
        }.count

        if koreanCount > 3 { return "ko" }
        if chineseCount > 3 { return "zh" }
        return "en"
    }
}

private final class OCRRaceState<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var recognitionTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var didFinish = false

    func start(continuation: CheckedContinuation<Value, Error>) {
        lock.withLock {
            self.continuation = continuation
        }
    }

    func setTasks(recognitionTask: Task<Void, Never>, timeoutTask: Task<Void, Never>) {
        let shouldCancel: Bool = lock.withLock {
            self.recognitionTask = recognitionTask
            self.timeoutTask = timeoutTask
            return didFinish
        }

        if shouldCancel {
            recognitionTask.cancel()
            timeoutTask.cancel()
        }
    }

    func finish(_ result: Result<Value, Error>) {
        let continuationToResume: CheckedContinuation<Value, Error>? = lock.withLock {
            guard !didFinish else { return nil }
            didFinish = true
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }

        recognitionTask?.cancel()
        timeoutTask?.cancel()

        switch result {
        case .success(let value):
            continuationToResume?.resume(returning: value)
        case .failure(let error):
            continuationToResume?.resume(throwing: error)
        }
    }

    func cancel() {
        finish(.failure(CancellationError()))
    }
}

/// Bridges the in-flight VNRequest to the cancellation handler, which may run
/// concurrently with the closure that creates the request.
private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: VNRequest?

    var request: VNRequest? {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
