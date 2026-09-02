import AppKit
import UniformTypeIdentifiers

enum Export {
    static func pngData(_ image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }

    static func copy(_ bitmap: CaptureBitmap, annotations: [Annotation], framed: Bool) {
        let rendered = FrameRenderer.render(base: bitmap.image, annotations: annotations, framed: framed)
        copy(rendered, scale: bitmap.scale)
    }

    static func copy(_ image: CGImage, scale: CGFloat) {
        let size = NSSize(
            width: CGFloat(image.width) / max(scale, 1),
            height: CGFloat(image.height) / max(scale, 1)
        )
        let ns = NSImage(size: size)
        ns.addRepresentation(NSBitmapImageRep(cgImage: image))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([ns])
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let data = pngData(image) else {
            throw CaptureError.failed("Could not encode PNG.")
        }
        try data.write(to: url, options: .atomic)
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
