import UIKit
import CoreImage
import Vision

enum BusinessCardImageProcessor {
    struct ProcessingResult {
        let image: UIImage
        let usedDetectedCardRegion: Bool
    }

    static func normalizedBusinessCardImage(from image: UIImage) -> UIImage {
        processedBusinessCardImage(from: image).image
    }

    static func processedBusinessCardImage(from image: UIImage) -> ProcessingResult {
        guard let cgImage = image.cgImage,
              let rectangle = detectBusinessCardRectangle(in: cgImage),
              let corrected = perspectiveCorrectedImage(from: cgImage, rectangle: rectangle) else {
            return ProcessingResult(image: image, usedDetectedCardRegion: false)
        }
        return ProcessingResult(image: corrected, usedDetectedCardRegion: true)
    }

    private static func detectBusinessCardRectangle(in cgImage: CGImage) -> VNRectangleObservation? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 5
        request.minimumConfidence = 0.35
        request.minimumSize = 0.18
        request.minimumAspectRatio = 0.45
        request.maximumAspectRatio = 0.75
        request.quadratureTolerance = 25

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return nil
        }

        return request.results?
            .filter { observation in
                let area = observation.boundingBox.width * observation.boundingBox.height
                return area >= 0.08
            }
            .max { lhs, rhs in
                rectangleScore(lhs) < rectangleScore(rhs)
            }
    }

    private static func rectangleScore(_ observation: VNRectangleObservation) -> CGFloat {
        let area = observation.boundingBox.width * observation.boundingBox.height
        let center = CGPoint(x: observation.boundingBox.midX, y: observation.boundingBox.midY)
        let centerDistance = hypot(center.x - 0.5, center.y - 0.5)
        return area + CGFloat(observation.confidence) * 0.18 - centerDistance * 0.08
    }

    private static func perspectiveCorrectedImage(from cgImage: CGImage, rectangle: VNRectangleObservation) -> UIImage? {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let input = CIImage(cgImage: cgImage)
        let parameters: [String: Any] = [
            "inputTopLeft": vector(for: rectangle.topLeft, width: width, height: height),
            "inputTopRight": vector(for: rectangle.topRight, width: width, height: height),
            "inputBottomLeft": vector(for: rectangle.bottomLeft, width: width, height: height),
            "inputBottomRight": vector(for: rectangle.bottomRight, width: width, height: height)
        ]
        let corrected = input.applyingFilter("CIPerspectiveCorrection", parameters: parameters)
        let extent = corrected.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let rendered = context.createCGImage(corrected, from: extent) else { return nil }
        return UIImage(cgImage: rendered)
    }

    private static func vector(for point: CGPoint, width: CGFloat, height: CGFloat) -> CIVector {
        CIVector(x: point.x * width, y: point.y * height)
    }
}
