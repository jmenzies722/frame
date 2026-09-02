import AppKit
import SwiftUI

@MainActor
final class DisplayPickController {
    private var windows: [NSWindow] = []
    private var continuation: CheckedContinuation<NSScreen, Error>?
    private var escapeMonitor: Any?

    func choose() async throws -> NSScreen {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            present()
        }
    }

    func cancel() {
        dismiss()
        finish(.failure(CaptureError.cancelled))
    }

    private func present() {
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
            let view = DisplayPickView(screen: screen)
            view.onPick = { [weak self] picked in
                self?.dismiss()
                self?.finish(.success(picked))
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

    private func finish(_ result: Result<NSScreen, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

final class DisplayPickView: NSView {
    var onPick: ((NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    private let screen: NSScreen
    private var hovered = false
    private var tracking: NSTrackingArea?
    private let chrome: NSHostingView<DisplayPickChrome>

    init(screen: NSScreen) {
        self.screen = screen
        self.chrome = NSHostingView(rootView: DisplayPickChrome(hovered: false))
        super.init(frame: .zero)
        wantsLayer = true
        chrome.frame = NSRect(x: 0, y: 0, width: 220, height: 44)
        addSubview(chrome)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func layout() {
        super.layout()
        let size = chrome.fittingSize
        chrome.frame = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

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
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(false)
    }

    override func mouseMoved(with event: NSEvent) {
        setHovered(true)
    }

    override func mouseUp(with event: NSEvent) {
        onPick?(screen)
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
        NSColor.black.withAlphaComponent(hovered ? 0.16 : 0.42).setFill()
        bounds.fill()
        NSColor.white.withAlphaComponent(hovered ? 0.18 : 0.06).setStroke()
        let inset = bounds.insetBy(dx: 18, dy: 18)
        let path = NSBezierPath(roundedRect: inset, xRadius: 22, yRadius: 22)
        path.lineWidth = hovered ? 2.5 : 1
        path.stroke()
    }

    private func setHovered(_ value: Bool) {
        guard hovered != value else { return }
        hovered = value
        chrome.rootView = DisplayPickChrome(hovered: value)
        needsDisplay = true
    }
}

struct DisplayPickChrome: View {
    var hovered: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: hovered ? "clipboard" : "display")
                .font(.system(size: 14, weight: .semibold))
            Text(hovered ? "Click to copy" : "Click a display")
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frameGlassCapsule()
    }
}
