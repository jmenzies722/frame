import AppKit

@main
enum MakeIcon {
    static func main() {
        guard CommandLine.arguments.count >= 2 else {
            fputs("usage: make_icon <AppIcon.icns>\n", stderr)
            exit(1)
        }
        let dest = URL(fileURLWithPath: CommandLine.arguments[1])
        let tmp = dest.deletingLastPathComponent().appendingPathComponent("Frame.iconset")
        try? FileManager.default.removeItem(at: tmp)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let slots: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]
        for (name, side) in slots {
            try! png(render(pixels: side), to: tmp.appendingPathComponent(name))
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        task.arguments = ["-c", "icns", "-o", dest.path, tmp.path]
        try! task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            fputs("iconutil failed (\(task.terminationStatus)). Left \(tmp.path)\n", stderr)
            exit(task.terminationStatus)
        }
        try? FileManager.default.removeItem(at: tmp)
    }

    private static func render(pixels: Int) -> NSBitmapImageRep {
        let size = CGFloat(pixels)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: size, height: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high

        let inset = size * 0.07
        let box = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let radius = box.width * 0.22
        NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.20, alpha: 1).setFill()
        NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius).fill()

        let innerInset = size * 0.22
        let inner = NSRect(
            x: innerInset,
            y: innerInset + size * 0.03,
            width: size - innerInset * 2,
            height: size - innerInset * 2 - size * 0.04
        )
        let plate = NSBezierPath(roundedRect: inner, xRadius: inner.width * 0.12, yRadius: inner.width * 0.12)
        NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.32, alpha: 1).setFill()
        plate.fill()
        NSColor(calibratedRed: 0.93, green: 0.45, blue: 0.36, alpha: 1).setStroke()
        plate.lineWidth = max(1, size * 0.028)
        plate.stroke()

        let accent = NSRect(
            x: inner.minX + inner.width * 0.18,
            y: inner.minY + inner.height * 0.18,
            width: inner.width * 0.64,
            height: max(2, size * 0.035)
        )
        NSColor(calibratedRed: 0.93, green: 0.45, blue: 0.36, alpha: 0.9).setFill()
        NSBezierPath(roundedRect: accent, xRadius: accent.height / 2, yRadius: accent.height / 2).fill()

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func png(_ rep: NSBitmapImageRep, to url: URL) throws {
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "MakeIcon", code: 1)
        }
        try data.write(to: url)
    }
}
