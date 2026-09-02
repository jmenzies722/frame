import AppKit
import SwiftUI

@MainActor
enum ToastHUD {
    private static var window: NSWindow?
    private static var hideWork: DispatchWorkItem?
    private static var keyMonitor: Any?
    private static var original: CaptureBitmap?
    private static var preview: CaptureBitmap?
    private static var redactions: [Annotation] = []
    private static var previousApp: NSRunningApplication?
    private static var copiedToClipboard = true

    static func showCopied(
        _ preview: CaptureBitmap,
        original: CaptureBitmap,
        redactions: [Annotation] = []
    ) {
        present(
            preview: preview,
            original: original,
            redactions: redactions,
            copied: true
        )
    }

    static func showScanFailed(_ bitmap: CaptureBitmap) {
        present(preview: bitmap, original: bitmap, redactions: [], copied: false)
    }

    private static func present(
        preview: CaptureBitmap,
        original: CaptureBitmap,
        redactions: [Annotation],
        copied: Bool
    ) {
        dismiss(restore: false)
        self.preview = preview
        self.original = original
        self.redactions = redactions
        copiedToClipboard = copied
        rememberFrontApp()

        let chip = ToastChipView(
            bitmap: preview,
            secrets: redactions.count,
            copied: copied,
            onEdit: { edit() },
            onHover: { hovering in
                if hovering {
                    hold()
                    becomeKey()
                } else {
                    resignToPreviousApp()
                    scheduleHide()
                }
            },
            onDragBegan: { hold() },
            onDragEnded: { stillHovering in
                if stillHovering {
                    hold()
                    becomeKey()
                } else {
                    resignToPreviousApp()
                    scheduleHide()
                }
            }
        )
        let fitted = chip.preferredSize
        let size = NSSize(width: max(fitted.width, 280), height: max(fitted.height, 56))
        chip.frame = NSRect(origin: .zero, size: size)

        let win = ToastPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .statusBar
        win.isFloatingPanel = true
        win.hidesOnDeactivate = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false
        win.contentView = chip

        let screen = NSScreen.main?.visibleFrame ?? .zero
        win.setFrameOrigin(NSPoint(
            x: screen.midX - size.width / 2,
            y: screen.minY + 28
        ))
        win.orderFront(nil)
        window = win
        listenForKeys()
        if chip.isPointerInside {
            hold()
            becomeKey()
        } else {
            scheduleHide()
        }
    }

    static func dismiss() {
        dismiss(restore: true)
    }

    private static func dismiss(restore: Bool) {
        hideWork?.cancel()
        hideWork = nil
        stopListening()
        window?.close()
        window = nil
        original = nil
        preview = nil
        redactions = []
        copiedToClipboard = true
        if restore {
            resignToPreviousApp()
        }
        previousApp = nil
    }

    private static func hold() {
        hideWork?.cancel()
        hideWork = nil
    }

    private static func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { dismiss() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6, execute: work)
    }

    private static func edit() {
        guard let original else { return }
        let marks = redactions
        dismiss(restore: false)
        EditorController.shared.present(bitmap: original, annotations: marks)
    }

    private static func rememberFrontApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != ProductIdentity.bundleIdentifier {
            previousApp = front
        }
    }

    private static func becomeKey() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private static func resignToPreviousApp() {
        guard let previousApp else { return }
        NSApp.yieldActivation(to: previousApp)
        previousApp.activate()
    }

    private static func listenForKeys() {
        stopListening()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard window?.isKeyWindow == true else { return event }
            if event.keyCode == 49, isBare(event) {
                edit()
                return nil
            }
            if event.keyCode == 1, isBare(event), copiedToClipboard {
                save()
                return nil
            }
            if event.keyCode == 53 {
                dismiss()
                return nil
            }
            return event
        }
    }

    private static func stopListening() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private static func isBare(_ event: NSEvent) -> Bool {
        event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
            .isEmpty
    }

    private static func save() {
        guard let preview, copiedToClipboard else { return }
        hold()
        stopListening()
        becomeKey()
        guard let url = Export.savePanel(defaultName: Export.defaultFilename()) else {
            listenForKeys()
            scheduleHide()
            return
        }
        do {
            try Export.writePNG(preview.image, to: url)
            HistoryStore.shared.add(image: preview.image, scale: preview.scale)
            dismiss()
        } catch {
            listenForKeys()
            scheduleHide()
        }
    }
}

final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class ToastChipView: NSView, NSDraggingSource {
    var onEdit: () -> Void
    var onHover: (Bool) -> Void
    var onDragBegan: () -> Void
    var onDragEnded: (Bool) -> Void

    private let bitmap: CaptureBitmap
    private let allowsDrag: Bool
    private let host: NSHostingView<CopiedToast>
    private var dragStart: NSPoint?
    private var didDrag = false
    private var tracking: NSTrackingArea?

    init(
        bitmap: CaptureBitmap,
        secrets: Int,
        copied: Bool,
        onEdit: @escaping () -> Void,
        onHover: @escaping (Bool) -> Void,
        onDragBegan: @escaping () -> Void,
        onDragEnded: @escaping (Bool) -> Void
    ) {
        self.bitmap = bitmap
        self.allowsDrag = copied
        self.onEdit = onEdit
        self.onHover = onHover
        self.onDragBegan = onDragBegan
        self.onDragEnded = onDragEnded
        self.host = NSHostingView(rootView: CopiedToast(bitmap: bitmap, secrets: secrets, copied: copied))
        super.init(frame: .zero)
        addSubview(host)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var preferredSize: NSSize { host.fittingSize }

    var isPointerInside: Bool {
        guard let window else { return false }
        let local = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        return bounds.contains(local)
    }

    override func layout() {
        super.layout()
        host.frame = bounds
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        var options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .inVisibleRect]
        if isPointerInside {
            options.insert(.assumeInside)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        guard !didDrag else { return }
        onHover(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard allowsDrag, let dragStart, !didDrag else { return }
        let now = convert(event.locationInWindow, from: nil)
        guard hypot(now.x - dragStart.x, now.y - dragStart.y) > 4 else { return }
        guard let url = Export.dragPNG(bitmap.image) else { return }
        didDrag = true
        onDragBegan()
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        item.setDraggingFrame(bounds, contents: bitmap.nsImage())
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onEdit()
        }
        dragStart = nil
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        didDrag = false
        onDragEnded(isPointerInside)
    }
}

struct CopiedToast: View {
    let bitmap: CaptureBitmap
    var secrets: Int
    var copied: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: bitmap.nsImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 280)
        .allowsHitTesting(false)
        .frameGlassCapsule()
    }

    private var title: String {
        if !copied { return "Couldn't hide secrets" }
        if secrets == 0 { return "Copied" }
        let noun = secrets == 1 ? "secret" : "secrets"
        return "Copied · \(secrets) \(noun) hidden"
    }

    private var subtitle: String {
        copied ? "Drag · Space edit · S save" : "Click or Space to edit"
    }
}
