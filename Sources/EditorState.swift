import AppKit
import SwiftUI

@MainActor
final class EditorState: ObservableObject {
    let bitmap: CaptureBitmap
    let historyBaked: Bool

    @Published var annotations: [Annotation] = []
    @Published var draft: Annotation?
    @Published var tool: Tool = .arrow
    @Published var swatch: Swatch = .coral
    @Published var frameEnabled: Bool
    @Published var toast: String?
    @Published var textDraft: String = ""
    @Published var placingText: CGPoint?
    @Published var didExport = false

    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []
    private var toastWork: DispatchWorkItem?

    init(bitmap: CaptureBitmap, historyBaked: Bool) {
        self.bitmap = bitmap
        self.historyBaked = historyBaked
        self.frameEnabled = historyBaked ? false : Preferences.frameEnabled
    }

    var working: [Annotation] {
        if let draft { return annotations + [draft] }
        return annotations
    }

    var rendered: CGImage {
        FrameRenderer.render(base: bitmap.image, annotations: working, framed: frameEnabled)
    }

    func commit(_ annotation: Annotation) {
        pushUndo()
        annotations.append(annotation)
        draft = nil
        redoStack.removeAll()
    }

    func beginDraft(_ annotation: Annotation) {
        draft = annotation
    }

    func updateDraft(_ annotation: Annotation) {
        draft = annotation
    }

    func cancelDraft() {
        draft = nil
        placingText = nil
        textDraft = ""
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = last
        draft = nil
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        draft = nil
    }

    func redact() {
        do {
            let rects = try RedactService.secretRects(in: bitmap.image)
            guard !rects.isEmpty else {
                flash("Nothing to redact")
                return
            }
            pushUndo()
            for rect in rects {
                annotations.append(Annotation(kind: .blur(rect), swatch: .white))
            }
            redoStack.removeAll()
            flash("Redacted \(rects.count) \(rects.count == 1 ? "secret" : "secrets")")
        } catch {
            flash("Could not read text on this image")
        }
    }

    func copyToClipboard() {
        Export.copy(bitmap, annotations: annotations, framed: frameEnabled)
        rememberExport()
        flash("Copied")
    }

    func saveToDisk() {
        let name = Export.defaultFilename()
        guard let url = Export.savePanel(defaultName: name) else { return }
        let image = rendered
        do {
            try Export.writePNG(image, to: url)
            rememberExport()
            flash("Saved")
        } catch {
            flash(error.localizedDescription)
        }
    }

    func writeTempPNG() -> URL? {
        Export.dragPNG(rendered)
    }

    func flash(_ message: String) {
        toast = message
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.toast = nil
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private func pushUndo() {
        undoStack.append(annotations)
        if undoStack.count > 40 {
            undoStack.removeFirst()
        }
    }

    private func rememberExport() {
        didExport = true
        HistoryStore.shared.add(image: rendered, scale: bitmap.scale)
    }
}
