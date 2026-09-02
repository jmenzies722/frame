import AppKit

enum ShotDrawing {
    static func draw(_ image: CGImage, in rect: CGRect) {
        NSImage(cgImage: image, size: rect.size).draw(
            in: rect,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    /// 1× rasterize in capture-pixel space. Origin is the top-left of the image,
    /// matching the flipped editor canvas and Vision boxes.
    static func rasterize(size: NSSize, draw: (CGRect) -> Bool) -> CGImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        let ok = draw(CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        guard ok else { return nil }
        return ctx.makeImage()
    }
}
