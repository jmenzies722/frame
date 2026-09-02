import AppKit
import ScreenCaptureKit

enum Geometry {
    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    static func screen(for display: SCDisplay) -> NSScreen? {
        NSScreen.screens.first { displayID(of: $0) == display.displayID }
    }

    static func screen(containing globalPoint: CGPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(globalPoint, $0.frame, false) }
            ?? NSScreen.main
    }

    static func display(in content: SCShareableContent, matching screen: NSScreen) -> SCDisplay? {
        guard let id = displayID(of: screen) else { return nil }
        return content.displays.first { $0.displayID == id }
    }

    static func displayName(for screen: NSScreen) -> String {
        let name = screen.localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        if let id = displayID(of: screen),
           let index = NSScreen.screens.firstIndex(where: { displayID(of: $0) == id }) {
            return index == 0 ? "Built-in" : "Display \(index + 1)"
        }
        return "Display"
    }

    static func displayUnderPointer(in content: SCShareableContent) -> SCDisplay? {
        let screen = screen(containing: NSEvent.mouseLocation)
        if let screen, let match = display(in: content, matching: screen) {
            return match
        }
        return content.displays.first
    }

    /// ScreenCaptureKit / Quartz window bounds are top-left on the primary display.
    /// Cocoa (`NSEvent.mouseLocation`, `NSScreen.frame`) is bottom-left on the primary display.
    static func cocoaRect(fromQuartz quartz: CGRect, primaryMaxY: CGFloat? = nil) -> CGRect {
        let maxY = primaryMaxY ?? NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(
            x: quartz.origin.x,
            y: maxY - quartz.origin.y - quartz.height,
            width: quartz.width,
            height: quartz.height
        )
    }

    static func aspectFit(_ image: CGSize, in bounds: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0, bounds.width > 0, bounds.height > 0 else {
            return .zero
        }
        let scale = min(bounds.width / image.width, bounds.height / image.height)
        let width = image.width * scale
        let height = image.height * scale
        return CGRect(
            x: (bounds.width - width) / 2,
            y: (bounds.height - height) / 2,
            width: width,
            height: height
        )
    }

    static func viewRect(fromGlobal global: CGRect, screen: NSScreen, flipped: Bool) -> CGRect {
        let x = global.minX - screen.frame.minX
        if flipped {
            let y = screen.frame.height - (global.minY - screen.frame.minY) - global.height
            return CGRect(x: x, y: y, width: global.width, height: global.height)
        }
        return CGRect(
            x: x,
            y: global.minY - screen.frame.minY,
            width: global.width,
            height: global.height
        )
    }
}
