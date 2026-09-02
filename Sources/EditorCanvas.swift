import AppKit
import SwiftUI

struct EditorCanvas: NSViewRepresentable {
    @ObservedObject var state: EditorState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> CanvasView {
        let view = CanvasView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: CanvasView, context: Context) {
        context.coordinator.state = state
        view.coordinator = context.coordinator
        view.needsDisplay = true
    }

    @MainActor
    final class Coordinator {
        var state: EditorState
        init(state: EditorState) { self.state = state }
    }
}

final class CanvasView: NSView {
    weak var coordinator: EditorCanvas.Coordinator?
    private var dragStart: CGPoint?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.canvas.setFill()
        bounds.fill()
        guard let state = coordinator?.state else { return }
        let image = state.rendered
        let fitted = fittedRect(for: image)
        NSGraphicsContext.current?.imageInterpolation = .high
        ShotDrawing.draw(image, in: fitted)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let state = coordinator?.state else { return }
        guard let point = imagePoint(from: event) else { return }
        if state.tool == .text {
            state.placingText = point
            state.textDraft = ""
            return
        }
        dragStart = point
        state.beginDraft(makeAnnotation(from: point, to: point, state: state))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let state = coordinator?.state, let start = dragStart else { return }
        guard let point = imagePoint(from: event) else { return }
        state.updateDraft(makeAnnotation(from: start, to: point, state: state))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let state = coordinator?.state, let start = dragStart else { return }
        dragStart = nil
        guard let point = imagePoint(from: event) else {
            state.cancelDraft()
            return
        }
        let annotation = makeAnnotation(from: start, to: point, state: state)
        if isMeaningful(annotation) {
            state.commit(annotation)
        } else {
            state.cancelDraft()
        }
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            coordinator?.state.cancelDraft()
            window?.close()
            return
        }
        interpretKeyEvents([event])
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let canvasIsFocus = window?.firstResponder === self
        if flags == .command, event.charactersIgnoringModifiers == "c" {
            guard canvasIsFocus, coordinator?.state.placingText == nil else { return false }
            coordinator?.state.copyToClipboard()
            return true
        }
        if flags == .command, event.charactersIgnoringModifiers == "s" {
            coordinator?.state.saveToDisk()
            return true
        }
        if flags == .command, event.charactersIgnoringModifiers == "w" {
            window?.close()
            return true
        }
        if flags == [.command, .shift], event.charactersIgnoringModifiers == "z" {
            coordinator?.state.redo()
            needsDisplay = true
            return true
        }
        if flags == .command, event.charactersIgnoringModifiers == "z" {
            coordinator?.state.undo()
            needsDisplay = true
            return true
        }
        if flags == [.command], event.keyCode == 36 {
            if coordinator?.state.copyToClipboard() == true {
                window?.close()
            }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    func commitTextIfNeeded() {
        guard let state = coordinator?.state, let origin = state.placingText else { return }
        let text = state.textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        state.placingText = nil
        state.textDraft = ""
        guard !text.isEmpty else { return }
        state.commit(Annotation(kind: .text(origin, text), swatch: state.swatch))
        needsDisplay = true
    }

    private func makeAnnotation(from start: CGPoint, to end: CGPoint, state: EditorState) -> Annotation {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        switch state.tool {
        case .arrow:
            return Annotation(kind: .arrow(start, end), swatch: state.swatch)
        case .rectangle:
            return Annotation(kind: .rectangle(rect), swatch: state.swatch)
        case .highlight:
            return Annotation(kind: .highlight(rect), swatch: .amber)
        case .blur:
            return Annotation(kind: .blur(rect), swatch: state.swatch)
        case .text:
            return Annotation(kind: .text(start, ""), swatch: state.swatch)
        }
    }

    private func isMeaningful(_ annotation: Annotation) -> Bool {
        switch annotation.kind {
        case .arrow(let a, let b):
            return hypot(b.x - a.x, b.y - a.y) >= 6
        case .rectangle(let r), .highlight(let r), .blur(let r):
            return r.width >= 4 && r.height >= 4
        case .text(_, let s):
            return !s.isEmpty
        }
    }

    private func imagePoint(from event: NSEvent) -> CGPoint? {
        guard let state = coordinator?.state else { return nil }
        let rendered = state.rendered
        let fitted = fittedRect(for: rendered)
        let view = convert(event.locationInWindow, from: nil)
        guard fitted.contains(view) else { return nil }
        let renderedPoint = CGPoint(
            x: (view.x - fitted.minX) / fitted.width * CGFloat(rendered.width),
            y: (view.y - fitted.minY) / fitted.height * CGFloat(rendered.height)
        )
        if state.frameEnabled {
            let card = FrameRenderer.layout(for: state.bitmap.image).card
            guard card.contains(renderedPoint) else { return nil }
            return CGPoint(x: renderedPoint.x - card.minX, y: renderedPoint.y - card.minY)
        }
        return renderedPoint
    }

    private func fittedRect(for image: CGImage) -> CGRect {
        let inset: CGFloat = 28
        return Geometry.aspectFit(
            CGSize(width: image.width, height: image.height),
            in: bounds.insetBy(dx: inset, dy: inset).size
        ).offsetBy(dx: inset, dy: inset)
    }
}
