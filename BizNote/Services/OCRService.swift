@preconcurrency import Vision
import ImageIO
import UIKit

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
        languages: [String] = ["ko-KR", "en-US"],
        timeout: Duration = .seconds(20)
    ) async throws -> [String] {
        let raceState = OCRRaceState<[String]>()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                raceState.start(continuation: continuation)

                let recognitionTask = Task.detached(priority: .userInitiated) {
                    do {
                        let lines = try await self.performRecognition(from: image, languages: languages)
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

    private func performRecognition(
        from image: UIImage,
        languages: [String]
    ) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let requestBox = RequestBox()
        let recognitionState = OCRRaceState<[String]>()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                recognitionState.start(continuation: continuation)

                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        recognitionState.finish(.failure(error))
                        return
                    }
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let strings = observations.compactMap { $0.topCandidates(1).first?.string }
                    recognitionState.finish(.success(strings))
                }
                request.recognitionLanguages = languages
                request.recognitionLevel = .fast
                request.usesLanguageCorrection = false
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
