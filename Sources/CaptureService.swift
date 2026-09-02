import AppKit
import CoreVideo
import ScreenCaptureKit

enum CaptureError: LocalizedError {
    case permissionDenied
    case noDisplay
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording is required."
        case .noDisplay:
            return "Frame could not find a display to capture."
        case .cancelled:
            return nil
        case .failed(let message):
            return message
        }
    }
}

enum CaptureService {
    static func content() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            if !Permissions.hasScreenRecording() {
                throw CaptureError.permissionDenied
            }
            throw CaptureError.failed(error.localizedDescription)
        }
    }

    static func captureDisplay(_ display: SCDisplay) async throws -> CaptureBitmap {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = configuration(width: display.width, height: display.height)
        let image = try await screenshot(filter: filter, configuration: config)
        let screen = Geometry.screen(for: display)
        return CaptureBitmap(image: image, scale: screen?.backingScaleFactor ?? 2)
    }

    static func captureWindow(_ window: SCWindow) async throws -> CaptureBitmap {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = scale(for: window)
        let width = max(1, Int((window.frame.width * scale).rounded()))
        let height = max(1, Int((window.frame.height * scale).rounded()))
        let config = configuration(width: width, height: height)
        let image = try await screenshot(filter: filter, configuration: config)
        return CaptureBitmap(image: image, scale: scale)
    }

    static func capturableWindows(in content: SCShareableContent) -> [SCWindow] {
        content.windows.filter { isCapturable($0) }
    }

    private static func isCapturable(_ window: SCWindow) -> Bool {
        guard window.isOnScreen else { return false }
        guard window.frame.width >= 80, window.frame.height >= 80 else { return false }
        let bundle = window.owningApplication?.bundleIdentifier ?? ""
        if bundle == ProductIdentity.bundleIdentifier { return false }
        if bundle.hasPrefix("com.apple.controlcenter") { return false }
        if bundle == "com.apple.notificationcenterui" { return false }
        return true
    }

    private static func scale(for window: SCWindow) -> CGFloat {
        let cocoa = Geometry.cocoaRect(fromQuartz: window.frame)
        let center = CGPoint(x: cocoa.midX, y: cocoa.midY)
        return Geometry.screen(containing: center)?.backingScaleFactor ?? 2
    }

    private static func configuration(width: Int, height: Int) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = max(1, width)
        config.height = max(1, height)
        config.showsCursor = false
        config.scalesToFit = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        if #available(macOS 14.0, *) {
            config.captureResolution = .best
        }
        return config
    }

    private static func screenshot(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            if !Permissions.hasScreenRecording() {
                throw CaptureError.permissionDenied
            }
            throw CaptureError.failed(error.localizedDescription)
        }
    }
}
