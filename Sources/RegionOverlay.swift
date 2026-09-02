import AppKit

@MainActor
final class RegionOverlayController {
    private var windows: [NSWindow] = []
    private var continuation: CheckedContinuation<CaptureBitmap, Error>?
    private var escapeMonitor: Any?

    func choose(shots: [(screen: NSScreen, bitmap: CaptureBitmap)]) async throws -> CaptureBitmap {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            present(shots: shots)
        }
    }

    func cancel() {
        dismiss()
        finish(.failure(CaptureError.cancelled))
    }

    private func present(shots: [(screen: NSScreen, bitmap: CaptureBitmap)]) {
        dismissWindows()
        for shot in shots {
            let window = OverlayWindow(
                contentRect: shot.screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: shot.screen
            )
            window.setFrame(shot.screen.frame, display: true)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            let view = RegionOverlayView(bitmap: shot.bitmap)
            view.onComplete = { [weak self] bitmap in
                self?.dismiss()
                self?.finish(.success(bitmap))
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
        NSCursor.crosshair.set()
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

    private func finish(_ result: Result<CaptureBitmap, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

final class RegionOverlayView: NSView {
    var onComplete: ((CaptureBitmap) -> Void)?
    var onCancel: (() -> Void)?

    private let bitmap: CaptureBitmap
    private var start: CGPoint?
    private var current: CGPoint?
    private var tracking: NSTrackingArea?

    init(bitmap: CaptureBitmap) {
        self.bitmap = bitmap
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
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
        if let tracking {
            removeTrackingArea(tracking)
        }
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
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        start = point
        current = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let selection, selection.width >= 2, selection.height >= 2 else {
            start = nil
            needsDisplay = true
            return
        }
        let pixel = pixelRect(from: selection)
        guard let cropped = bitmap.cropped(to: pixel) else {
            start = nil
            needsDisplay = true
            return
        }
        onComplete?(cropped)
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
        ShotDrawing.draw(bitmap.image, in: bounds)
        NSColor.black.withAlphaComponent(0.48).setFill()
        bounds.fill()

        if let selection, selection.width > 1, selection.height > 1 {
            NSGraphicsContext.current?.cgContext.saveGState()
            NSGraphicsContext.current?.cgContext.clip(to: selection)
            ShotDrawing.draw(bitmap.image, in: bounds)
            NSGraphicsContext.current?.cgContext.restoreGState()
            NSColor.white.setStroke()
            let stroke = NSBezierPath(rect: selection.insetBy(dx: 1, dy: 1))
            stroke.lineWidth = 2
            stroke.stroke()
            if let ctx = NSGraphicsContext.current?.cgContext {
                drawBadge(for: selection, in: ctx)
            }
        } else if let current, let ctx = NSGraphicsContext.current?.cgContext {
            drawCrosshair(at: current, in: ctx)
        }
    }

    private var selection: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    private func pixelRect(from viewRect: CGRect) -> CGRect {
        let sx = CGFloat(bitmap.image.width) / bounds.width
        let sy = CGFloat(bitmap.image.height) / bounds.height
        return CGRect(
            x: viewRect.minX * sx,
            y: viewRect.minY * sy,
            width: viewRect.width * sx,
            height: viewRect.height * sy
        )
    }

    private func drawCrosshair(at point: CGPoint, in ctx: CGContext) {
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 0, y: point.y))
        ctx.addLine(to: CGPoint(x: bounds.width, y: point.y))
        ctx.move(to: CGPoint(x: point.x, y: 0))
        ctx.addLine(to: CGPoint(x: point.x, y: bounds.height))
        ctx.strokePath()
    }

    private func drawBadge(for selection: CGRect, in ctx: CGContext) {
        let pixel = pixelRect(from: selection)
        let label = "\(Int(pixel.width.rounded())) × \(Int(pixel.height.rounded()))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let text = NSAttributedString(string: label, attributes: attrs)
        let size = text.size()
        var origin = CGPoint(x: selection.minX, y: selection.maxY + 8)
        if origin.y + size.height + 8 > bounds.height {
            origin.y = selection.minY - size.height - 14
        }
        if origin.y < 8 { origin.y = selection.minY + 8 }
        let badge = CGRect(
            x: origin.x,
            y: origin.y,
            width: size.width + 14,
            height: size.height + 8
        )
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.72).cgColor)
        ctx.addPath(CGPath(roundedRect: badge, cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.fillPath()
        text.draw(at: CGPoint(x: badge.minX + 7, y: badge.minY + 4))
    }
}
