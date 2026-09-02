import AppKit
import ImageIO
import UniformTypeIdentifiers

enum Export {
    static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    static func nsImage(_ image: CGImage, scale: CGFloat) -> NSImage {
        let size = NSSize(
            width: CGFloat(image.width) / max(scale, 1),
            height: CGFloat(image.height) / max(scale, 1)
        )
        return NSImage(cgImage: image, size: size)
    }

    static func copy(_ bitmap: CaptureBitmap, annotations: [Annotation], framed: Bool) {
        let image: CGImage
        if annotations.isEmpty && !framed {
            image = bitmap.image
        } else {
            image = FrameRenderer.render(base: bitmap.image, annotations: annotations, framed: framed)
        }
        copy(image, scale: bitmap.scale)
    }

    static func copy(_ image: CGImage, scale: CGFloat) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let data = pngData(image) {
            pasteboard.setData(data, forType: .png)
        }
        pasteboard.writeObjects([nsImage(image, scale: scale)])
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CaptureError.failed("Could not encode PNG.")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw CaptureError.failed("Could not encode PNG.")
        }
    }

    static func defaultSaveDirectory() -> URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        let folder = pictures.appendingPathComponent(ProductIdentity.saveFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func dragPNG(_ image: CGImage) -> URL? {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FrameDrag", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let stale = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) {
            let cutoff = Date().addingTimeInterval(-600)
            for url in stale {
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if date < cutoff {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        let url = folder.appendingPathComponent("Frame-\(UUID().uuidString).png")
        do {
            try writePNG(image, to: url)
            return url
        } catch {
            return nil
        }
    }

    static func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Frame \(formatter.string(from: Date())).png"
    }

    @MainActor
    static func savePanel(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.directoryURL = defaultSaveDirectory()
        panel.nameFieldStringValue = defaultName
        panel.title = "Save screenshot"
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }
}
