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
        tryRender(base: base, annotations: annotations, framed: framed)
            ?? (framed ? frame(base) : base)
    }

    static func tryRender(base: CGImage, annotations: [Annotation], framed: Bool) -> CGImage? {
        if annotations.isEmpty {
            return framed ? frame(base) : base
        }
        let annotated = annotate(base: base, annotations: annotations)
        if annotated === base { return nil }
        return framed ? frame(annotated) : annotated
    }

    static func annotate(base: CGImage, annotations: [Annotation]) -> CGImage {
        guard !annotations.isEmpty else { return base }
        let size = NSSize(width: base.width, height: base.height)
        return ShotDrawing.rasterize(size: size) { rect in
            ShotDrawing.draw(base, in: rect)
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            AnnotationDraw.render(annotations, over: base, in: ctx)
            return true
        } ?? base
    }

    static func frame(_ image: CGImage) -> CGImage {
        let layout = layout(for: image)
        return ShotDrawing.rasterize(size: layout.output) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            fillBackground(in: ctx, rect: rect)

            let card = layout.card
            let plate = NSBezierPath(roundedRect: card, xRadius: layout.radius, yRadius: layout.radius)
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: layout.shadow * 0.25),
                blur: layout.shadow,
                color: NSColor.black.withAlphaComponent(0.45).cgColor
            )
            NSColor.black.setFill()
            plate.fill()
            ctx.restoreGState()

            ctx.saveGState()
            plate.addClip()
            ShotDrawing.draw(image, in: card)
            ctx.restoreGState()
            return true
        } ?? image
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
}
