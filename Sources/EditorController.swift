import AppKit
import SwiftUI

@MainActor
final class EditorController: NSObject, NSWindowDelegate {
    static let shared = EditorController()

    private var window: NSWindow?
    private var state: EditorState?

    func present(bitmap: CaptureBitmap, historyBaked: Bool = false) {
        window?.close()
        let state = EditorState(bitmap: bitmap, historyBaked: historyBaked)
        self.state = state
        let root = EditorView(state: state) { [weak self] in
            self?.window?.close()
        }
        let host = NSHostingController(rootView: root)
        let window = GlassPanel.window(title: ProductIdentity.displayName, content: host)
        window.styleMask.insert([.miniaturizable, .resizable])
        window.setContentSize(preferredSize(for: bitmap))
        window.minSize = NSSize(width: 760, height: 520)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func presentHistory(_ item: HistoryItem) {
        guard let image = HistoryStore.shared.image(for: item) else { return }
        present(bitmap: CaptureBitmap(image: image, scale: item.scale), historyBaked: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        state = nil
    }

    private func preferredSize(for bitmap: CaptureBitmap) -> NSSize {
        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1280, height: 800)
        let maxW = min(screen.width - 120, 1280)
        let maxH = min(screen.height - 140, 860)
        let image = bitmap.pointSize
        let width = min(maxW, max(760, image.width + 220))
        let height = min(maxH, max(520, image.height + 160))
        return NSSize(width: width, height: height)
    }
}
