import AppKit
import SwiftUI

@MainActor
enum ToastHUD {
    private static var window: NSWindow?
    private static var hideWork: DispatchWorkItem?

    static func showCopied(_ bitmap: CaptureBitmap) {
        hideWork?.cancel()
        window?.close()

        let host = NSHostingController(rootView: CopiedToast(bitmap: bitmap) {
            dismiss()
            EditorController.shared.present(bitmap: bitmap)
        })
        let win = OverlayWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 72),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .statusBar
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false
        win.contentViewController = host
        win.setContentSize(host.view.fittingSize)

        let screen = NSScreen.main?.visibleFrame ?? .zero
        let size = win.frame.size
        let origin = NSPoint(
            x: screen.midX - size.width / 2,
            y: screen.minY + 28
        )
        win.setFrameOrigin(origin)
        win.orderFront(nil)
        window = win

        let work = DispatchWorkItem {
            dismiss()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
    }

    static func dismiss() {
        hideWork?.cancel()
        hideWork = nil
        window?.close()
        window = nil
    }
}

struct CopiedToast: View {
    let bitmap: CaptureBitmap
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(nsImage: bitmap.nsImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Copied")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Click to edit")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 260)
        }
        .buttonStyle(.plain)
        .frameGlassCapsule()
    }
}
