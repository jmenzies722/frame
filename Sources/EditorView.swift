import SwiftUI

struct EditorView: View {
    @ObservedObject var state: EditorState
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                toolRail
                    .frameGlass(cornerRadius: 16)
                ZStack(alignment: .top) {
                    EditorCanvas(state: state)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    if let toast = state.toast {
                        Text(toast)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .frameGlassCapsule()
                            .padding(.top, 16)
                    }
                }
            }
            if state.placingText != nil {
                textBar
                    .frameGlass(cornerRadius: 14)
            }
            bottomBar
                .frameGlass(cornerRadius: 16)
        }
        .padding(12)
        .frame(minWidth: 760, minHeight: 520)
        .frameGlassGroup(spacing: 10)
    }

    private var toolRail: some View {
        VStack(spacing: 8) {
            ForEach(Tool.allCases) { tool in
                railButton(tool)
            }
            Spacer()
            ForEach(Swatch.allCases) { swatch in
                Button {
                    state.swatch = swatch
                } label: {
                    Circle()
                        .fill(swatch.swiftColor)
                        .frame(width: 16, height: 16)
                        .overlay {
                            Circle()
                                .stroke(state.swatch == swatch ? Color.primary : Color.primary.opacity(0.15), lineWidth: state.swatch == swatch ? 2 : 1)
                        }
                }
                .buttonStyle(.plain)
                .help(swatch.rawValue.capitalized)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .frame(width: 58)
    }

    private func railButton(_ tool: Tool) -> some View {
        Button {
            state.tool = tool
        } label: {
            Image(systemName: tool.symbol)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 34, height: 34)
                .foregroundStyle(state.tool == tool ? Color.white : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(state.tool == tool ? Theme.swiftAccent : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tool.title)
    }

    private var textBar: some View {
        HStack(spacing: 10) {
            Text("Label")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("What should it say?", text: $state.textDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commitText() }
            Button("Add", action: commitText)
                .keyboardShortcut(.defaultAction)
            Button("Cancel") {
                state.cancelDraft()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Toggle("Frame", isOn: $state.frameEnabled)
                .toggleStyle(.switch)
                .onChange(of: state.frameEnabled) { _, value in
                    if !state.historyBaked {
                        Preferences.frameEnabled = value
                    }
                }

            Button("Redact") {
                state.redact()
            }
            .help("Blur emails and keys on this image. Stays on this Mac.")

            Spacer()

            Label("Drag", systemImage: "square.and.arrow.up")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .onDrag {
                    if let url = state.writeTempPNG() {
                        return NSItemProvider(contentsOf: url) ?? NSItemProvider()
                    }
                    return NSItemProvider()
                }

            Button("Save") {
                state.saveToDisk()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Copy") {
                state.copyToClipboard()
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("Copy & Close") {
                state.copyToClipboard()
                onClose()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func commitText() {
        guard let origin = state.placingText else { return }
        let text = state.textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        state.placingText = nil
        state.textDraft = ""
        guard !text.isEmpty else { return }
        state.commit(Annotation(kind: .text(origin, text), swatch: state.swatch))
    }
}
