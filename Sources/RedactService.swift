import CoreGraphics
import Vision

enum RedactService {
    static func secretRects(in image: CGImage) throws -> [CGRect] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        var rects: [CGRect] = []
        var inPEM = false

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let box = flippedRect(observation.boundingBox, image: image)

            if RedactPatterns.isPEMStart(text) {
                inPEM = true
            }
            if inPEM {
                rects.append(box.insetBy(dx: -4, dy: -3))
                if RedactPatterns.isPEMEnd(text) {
                    inPEM = false
                }
                continue
            }
            if RedactPatterns.containsSecret(text) {
                rects.append(box.insetBy(dx: -4, dy: -3))
            }
        }
        return rects
    }

    private static func flippedRect(_ normalized: CGRect, image: CGImage) -> CGRect {
        let full = VNImageRectForNormalizedRect(normalized, image.width, image.height)
        return CGRect(
            x: full.minX,
            y: CGFloat(image.height) - full.maxY,
            width: full.width,
            height: full.height
        )
    }
}
