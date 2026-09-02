import SwiftUI

enum FrameGlass {
    @ViewBuilder
    static func native<S: InsettableShape>(_ content: some View, in shape: S, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                content.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            content
                .background {
                    shape.fill(.ultraThinMaterial)
                    if let tint {
                        shape.fill(tint.opacity(0.18))
                    }
                }
                .overlay {
                    shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
        }
    }
}

extension View {
    func frameGlass(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return FrameGlass.native(self, in: shape, tint: tint)
    }

    func frameGlassCapsule(tint: Color? = nil) -> some View {
        FrameGlass.native(self, in: Capsule(), tint: tint)
    }

    @ViewBuilder
    func frameGlassGroup(spacing: CGFloat = 16) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

enum GlassPanel {
    @MainActor
    static func window(title: String, content: NSViewController) -> NSWindow {
        let window = NSWindow(contentViewController: content)
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        return window
    }
}
