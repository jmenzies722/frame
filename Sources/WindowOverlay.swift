import AppKit
import ScreenCaptureKit

@MainActor
final class WindowOverlayController {
    private var windows: [NSWindow] = []
    private var continuation: CheckedContinuation<SCWindow, Error>?
    private var escapeMonitor: Any?

    func choose(targets: [SCWindow]) async throws -> SCWindow {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            present(targets: targets)
        }
    }

    func cancel() {
        dismiss()
        finish(.failure(CaptureError.cancelled))
    }

    private func present(targets: [SCWindow]) {
        dismissWindows()
        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.setFrame(screen.frame, display: true)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            let view = WindowOverlayView(screen: screen, targets: targets)
            view.onComplete = { [weak self] target in
                self?.dismiss()
                self?.finish(.success(target))
            }
            view.onCancel = { [weak self] in
                self?.cancel()
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancel()
                return nil
            }
            return event
        }
    }

    private func dismiss() {
        NSCursor.arrow.set()
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        dismissWindows()
    }

    private func dismissWindows() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    private func finish(_ result: Result<SCWindow, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

final class WindowOverlayView: NSView {
    var onComplete: ((SCWindow) -> Void)?
    var onCancel: (() -> Void)?

    private let screen: NSScreen
    private let targets: [SCWindow]
    private var hovered: SCWindow?
    private var tracking: NSTrackingArea?

    init(screen: NSScreen, targets: [SCWindow]) {
        self.screen = screen
        self.targets = targets
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        updateTracking()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTracking()
    }

    private func updateTracking() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        hovered = target(at: NSEvent.mouseLocation)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if let target = target(at: NSEvent.mouseLocation) {
            onComplete?(target)
        } else {
            onCancel?()
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.42).setFill()
        bounds.fill()
        guard let hovered else { return }
        let cocoa = Geometry.cocoaRect(fromQuartz: hovered.frame)
        let rect = Geometry.viewRect(fromGlobal: cocoa, screen: screen, flipped: false)
        NSColor.white.withAlphaComponent(0.08).setFill()
        rect.fill()
        NSColor.white.setStroke()
        let stroke = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 6, yRadius: 6)
        stroke.lineWidth = 3
        stroke.stroke()
        drawLabel(for: hovered, in: rect)
    }

    private func target(at global: CGPoint) -> SCWindow? {
        let hits = targets.filter { Geometry.cocoaRect(fromQuartz: $0.frame).contains(global) }
        return hits.min { lhs, rhs in
            let a = Geometry.cocoaRect(fromQuartz: lhs.frame)
            let b = Geometry.cocoaRect(fromQuartz: rhs.frame)
            return a.width * a.height < b.width * b.height
        }
    }

    private func drawLabel(for window: SCWindow, in rect: CGRect) {
        let app = window.owningApplication?.applicationName ?? "Window"
        let title = window.title?.isEmpty == false ? "\(app) — \(window.title!)" : app
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let text = NSAttributedString(string: title, attributes: attrs)
        let size = text.size()
        var badge = CGRect(
            x: rect.minX + 10,
            y: rect.maxY - size.height - 18,
            width: size.width + 16,
            height: size.height + 10
        )
        if badge.maxY > bounds.maxY {
            badge.origin.y = rect.minY + 10
        }
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 6, yRadius: 6).fill()
        text.draw(at: CGPoint(x: badge.minX + 8, y: badge.minY + 5))
    }
}
