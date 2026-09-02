import AppKit
import CoreGraphics

enum FrameRenderer {
    struct Layout {
        var pad: CGFloat
        var radius: CGFloat
        var shadow: CGFloat
        var output: CGSize
        var card: CGRect
    }

    static func layout(for image: CGImage) -> Layout {
        let pad = CGFloat(max(56, min(image.width, image.height) / 18))
        let radius = CGFloat(max(12, pad * 0.22))
        let shadow = pad * 0.28
        let width = CGFloat(image.width) + pad * 2
        let height = CGFloat(image.height) + pad * 2 + shadow * 0.4
        return Layout(
            pad: pad,
            radius: radius,
            shadow: shadow,
            output: CGSize(width: width, height: height),
            card: CGRect(x: pad, y: pad, width: CGFloat(image.width), height: CGFloat(image.height))
        )
    }

    static func render(base: CGImage, annotations: [Annotation], framed: Bool) -> CGImage {
        let annotated = annotate(base: base, annotations: annotations)
        return framed ? frame(annotated) : annotated
    }

    static func annotate(base: CGImage, annotations: [Annotation]) -> CGImage {
        let width = base.width
        let height = base.height
        guard let ctx = bitmap(width: width, height: height) else { return base }
        AnnotationDraw.render(annotations, over: base, in: ctx)
        return ctx.makeImage() ?? base
    }

    static func frame(_ image: CGImage) -> CGImage {
        let layout = layout(for: image)
        let width = Int(layout.output.width)
        let height = Int(layout.output.height)
        guard let ctx = bitmap(width: width, height: height) else { return image }

        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)

        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        fillBackground(in: ctx, rect: bounds)

        let card = layout.card
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: layout.shadow * 0.25),
            blur: layout.shadow,
            color: NSColor.black.withAlphaComponent(0.45).cgColor
        )
        let plate = CGPath(roundedRect: card, cornerWidth: layout.radius, cornerHeight: layout.radius, transform: nil)
        ctx.addPath(plate)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(plate)
        ctx.clip()
        ctx.draw(image, in: card)
        ctx.restoreGState()

        return ctx.makeImage() ?? image
    }

    private static func fillBackground(in ctx: CGContext, rect: CGRect) {
        let colors = [Theme.frameTop.cgColor, Theme.frameBottom.cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else {
            ctx.setFillColor(Theme.frameBottom.cgColor)
            ctx.fill(rect)
            return
        }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    static func bitmap(width: Int, height: Int) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: max(1, width),
            height: max(1, height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}
