import AppKit
import CoreGraphics

enum Tool: String, CaseIterable, Identifiable {
    case arrow, rectangle, highlight, text, blur

    var id: String { rawValue }

    var title: String {
        switch self {
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .highlight: return "Highlight"
        case .text: return "Text"
        case .blur: return "Blur"
        }
    }

    var symbol: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .highlight: return "highlighter"
        case .text: return "textformat"
        case .blur: return "eye.slash"
        }
    }
}

struct Annotation: Identifiable, Equatable {
    enum Kind: Equatable {
        case arrow(CGPoint, CGPoint)
        case rectangle(CGRect)
        case highlight(CGRect)
        case text(CGPoint, String)
        case blur(CGRect)
    }

    let id: UUID
    var kind: Kind
    var swatch: Swatch

    init(id: UUID = UUID(), kind: Kind, swatch: Swatch) {
        self.id = id
        self.kind = kind
        self.swatch = swatch
    }
}

enum AnnotationDraw {
    static func render(
        _ annotations: [Annotation],
        over image: CGImage,
        in ctx: CGContext
    ) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(image.height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        for annotation in annotations {
            draw(annotation, image: image, in: ctx)
        }
        ctx.restoreGState()
    }

    private static func draw(_ annotation: Annotation, image: CGImage, in ctx: CGContext) {
        let color = annotation.swatch.color.cgColor
        switch annotation.kind {
        case .arrow(let start, let end):
            drawArrow(from: start, to: end, color: color, in: ctx)
        case .rectangle(let rect):
            ctx.setStrokeColor(color)
            ctx.setLineWidth(3)
            ctx.stroke(rect.insetBy(dx: 1.5, dy: 1.5))
        case .highlight(let rect):
            ctx.setFillColor(annotation.swatch.color.withAlphaComponent(0.32).cgColor)
            ctx.fill(rect)
        case .text(let origin, let string):
            drawText(string, at: origin, color: annotation.swatch.color, in: ctx)
        case .blur(let rect):
            drawBlur(rect, image: image, in: ctx)
        }
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, color: CGColor, in ctx: CGContext) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 1)
        let ux = dx / length
        let uy = dy / length
        let head: CGFloat = min(22, length * 0.28)
        let left = CGPoint(x: end.x - ux * head + -uy * head * 0.55, y: end.y - uy * head + ux * head * 0.55)
        let right = CGPoint(x: end.x - ux * head + uy * head * 0.55, y: end.y - uy * head + -ux * head * 0.55)
        ctx.setStrokeColor(color)
        ctx.setFillColor(color)
        ctx.setLineWidth(3.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
        ctx.move(to: end)
        ctx.addLine(to: left)
        ctx.addLine(to: right)
        ctx.closePath()
        ctx.fillPath()
    }

    private static func drawText(_ string: String, at origin: CGPoint, color: NSColor, in ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: color,
            .strokeColor: NSColor.black.withAlphaComponent(0.55),
            .strokeWidth: -2.0,
        ]
        let drawn = NSAttributedString(string: string, attributes: attrs)
        let size = drawn.size()
        let rect = CGRect(origin: origin, size: size)
        NSGraphicsContext.saveGraphicsState()
        let ns = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.current = ns
        drawn.draw(with: rect, options: [.usesLineFragmentOrigin])
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawBlur(_ rect: CGRect, image: CGImage, in ctx: CGContext) {
        let clipped = rect.integral.intersection(
            CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        guard clipped.width >= 2, clipped.height >= 2 else { return }
        guard let tile = pixelate(image: image, rect: clipped) else { return }
        ctx.draw(tile, in: clipped)
    }

    private static func pixelate(image: CGImage, rect: CGRect) -> CGImage? {
        guard let cropped = image.cropping(to: rect) else { return nil }
        let block = max(8, min(rect.width, rect.height) / 12)
        let smallW = max(1, Int(rect.width / block))
        let smallH = max(1, Int(rect.height / block))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let small = CGContext(
            data: nil,
            width: smallW,
            height: smallH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        small.interpolationQuality = .none
        small.draw(cropped, in: CGRect(x: 0, y: 0, width: smallW, height: smallH))
        guard let tiny = small.makeImage() else { return nil }
        guard let big = CGContext(
            data: nil,
            width: Int(rect.width),
            height: Int(rect.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        big.interpolationQuality = .none
        big.draw(tiny, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        return big.makeImage()
    }
}
