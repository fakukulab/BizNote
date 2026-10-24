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
        guard let normalizedImage = renderedImage(from: image) else {
            return ProcessingResult(image: image, usedDetectedCardRegion: false)
        }

        let detectionImage = upscaledImageIfNeeded(normalizedImage)
        guard let cgImage = detectionImage.cgImage,
              let rectangle = detectBusinessCardRectangle(in: cgImage),
              let corrected = perspectiveCorrectedImage(from: cgImage, rectangle: rectangle) else {
            return ProcessingResult(image: detectionImage, usedDetectedCardRegion: false)
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

    private static func upscaledImageIfNeeded(_ image: UIImage) -> UIImage {
        let targetShortEdge: CGFloat = 900
        let shortEdge = min(image.size.width, image.size.height)
        guard shortEdge > 0, shortEdge < targetShortEdge else { return image }

        let scale = targetShortEdge / shortEdge
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: newSize)).fill()
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    static func enhancedImage(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let input = CIImage(cgImage: cgImage)
        let averageBrightness = averageBrightness(of: input)
        var output = input

        if averageBrightness < 0.38 {
            output = output.applyingFilter("CIColorInvert")
        }

        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0,
            kCIInputContrastKey: 1.18,
            kCIInputBrightnessKey: 0.03
        ])
        output = output.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: 0.45
        ])

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let rendered = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: .up)
    }

    private static func averageBrightness(of image: CIImage) -> CGFloat {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return 1 }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else { return 1 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (CGFloat(bitmap[0]) + CGFloat(bitmap[1]) + CGFloat(bitmap[2])) / (3 * 255)
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
