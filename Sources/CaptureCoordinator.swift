import AppKit
import ScreenCaptureKit

@MainActor
final class CaptureCoordinator {
    static let shared = CaptureCoordinator()

    private var busy = false
    private var regionOverlay: RegionOverlayController?
    private var windowOverlay: WindowOverlayController?
    private var displayPick: DisplayPickController?

    private init() {}

    func captureScreen(waitForMenu: Bool = false) {
        Task { await run(.clickScreen, waitForMenu: waitForMenu) }
    }

    func captureRegion(waitForMenu: Bool = false) {
        Task { await run(.region, waitForMenu: waitForMenu) }
    }

    func captureWindow(waitForMenu: Bool = false) {
        Task { await run(.window, waitForMenu: waitForMenu) }
    }

    func captureDisplay(waitForMenu: Bool = false) {
        Task { await run(.display, waitForMenu: waitForMenu) }
    }

    private enum Mode {
        case clickScreen, region, window, display
    }

    private func run(_ mode: Mode, waitForMenu: Bool) async {
        guard !busy else { return }
        if waitForMenu {
            try? await Task.sleep(nanoseconds: 180_000_000)
        }
        OnboardingWindow.dismiss()
        if !Permissions.hasScreenRecording() {
            _ = Permissions.requestScreenRecording()
        }
        busy = true
        defer {
            busy = false
            regionOverlay = nil
            windowOverlay = nil
            displayPick = nil
        }
        do {
            switch mode {
            case .clickScreen:
                try await runClickScreen()
            case .region:
                try await runRegion()
            case .window:
                try await runWindow()
            case .display:
                try await runDisplay()
            }
        } catch CaptureError.cancelled {
            return
        } catch CaptureError.permissionDenied {
            Permissions.presentDenied()
        } catch {
            present(error)
        }
    }

    private func runClickScreen() async throws {
        let content = try await CaptureService.content()
        let picker = DisplayPickController()
        displayPick = picker
        let screen = try await picker.choose()
        displayPick = nil
        try? await Task.sleep(nanoseconds: 90_000_000)
        guard let display = Geometry.display(in: content, matching: screen) else {
            throw CaptureError.noDisplay
        }
        finishToClipboard(try await CaptureService.captureDisplay(display))
    }

    private func runRegion() async throws {
        let content = try await CaptureService.content()
        var shots: [(screen: NSScreen, bitmap: CaptureBitmap)] = []
        for screen in NSScreen.screens {
            guard let display = Geometry.display(in: content, matching: screen) else { continue }
            let bitmap = try await CaptureService.captureDisplay(display)
            shots.append((screen, bitmap))
        }
        guard !shots.isEmpty else { throw CaptureError.noDisplay }
        let overlay = RegionOverlayController()
        regionOverlay = overlay
        let picked = try await overlay.choose(shots: shots)
        regionOverlay = nil
        EditorController.shared.present(bitmap: picked)
    }

    private func runWindow() async throws {
        let content = try await CaptureService.content()
        let targets = CaptureService.capturableWindows(in: content)
        guard !targets.isEmpty else {
            throw CaptureError.failed("No windows to capture.")
        }
        let overlay = WindowOverlayController()
        windowOverlay = overlay
        let window = try await overlay.choose(targets: targets)
        windowOverlay = nil
        finishToClipboard(try await CaptureService.captureWindow(window))
    }

    private func runDisplay() async throws {
        let content = try await CaptureService.content()
        guard let display = Geometry.displayUnderPointer(in: content) else {
            throw CaptureError.noDisplay
        }
        finishToClipboard(try await CaptureService.captureDisplay(display))
    }

    private func finishToClipboard(_ bitmap: CaptureBitmap) {
        Export.copy(bitmap, annotations: [], framed: false)
        HistoryStore.shared.add(image: bitmap.image, scale: bitmap.scale)
        ToastHUD.showCopied(bitmap)
    }

    private func present(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Could not capture"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
