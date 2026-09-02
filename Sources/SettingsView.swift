import AppKit
import Carbon
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published var chords: [CaptureHotkey: String] = [:]
    @Published var recording: CaptureHotkey?
    @Published var launchAtLogin: Bool
    @Published var autoRedact: Bool
    @Published var hasScreenRecording: Bool
    @Published var loginError: String?
    @Published var bindError: String?

    private var monitor: Any?

    init() {
        launchAtLogin = LoginItem.isEnabled
        autoRedact = Preferences.autoRedact
        hasScreenRecording = Permissions.hasScreenRecording()
        refresh()
    }

    func refresh() {
        hasScreenRecording = Permissions.hasScreenRecording()
        launchAtLogin = LoginItem.isEnabled
        autoRedact = Preferences.autoRedact
        chords = [
            .screen: HotkeyCenter.describe(keyCode: Preferences.regionKeyCode, modifiers: Preferences.regionModifiers),
            .window: HotkeyCenter.describe(keyCode: Preferences.windowKeyCode, modifiers: Preferences.windowModifiers),
            .display: HotkeyCenter.describe(keyCode: Preferences.displayKeyCode, modifiers: Preferences.displayModifiers),
            .area: HotkeyCenter.describe(keyCode: Preferences.areaKeyCode, modifiers: Preferences.areaModifiers),
        ]
    }

    func setLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            launchAtLogin = LoginItem.isEnabled
            loginError = nil
        } catch {
            launchAtLogin = LoginItem.isEnabled
            loginError = error.localizedDescription
        }
    }

    func beginRecord(_ hotkey: CaptureHotkey) {
        recording = hotkey
        bindError = nil
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event)
                return nil
            }
        }
    }

    func resetHotkeys() {
        Preferences.resetHotkeys()
        HotkeyCenter.shared.reregister()
        AppDelegate.shared?.refreshMenu()
        refresh()
    }

    func stopRecording() {
        recording = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }
        let modifiers = HotkeyCenter.carbonModifiers(from: event.modifierFlags)
        let hasPrimary = modifiers & UInt32(cmdKey) != 0 || modifiers & UInt32(controlKey) != 0
        guard hasPrimary else {
            bindError = "Add ⌘ or ⌃ so it doesn’t steal typing."
            return
        }
        let key = UInt32(event.keyCode)
        if HotkeyCenter.isReservedSystemCapture(keyCode: key, modifiers: modifiers) {
            bindError = "That’s a system screenshot shortcut. Pick another."
            return
        }
        guard let recording else { return }
        switch recording {
        case .screen:
            Preferences.regionKeyCode = key
            Preferences.regionModifiers = modifiers
        case .window:
            Preferences.windowKeyCode = key
            Preferences.windowModifiers = modifiers
        case .display:
            Preferences.displayKeyCode = key
            Preferences.displayModifiers = modifiers
        case .area:
            Preferences.areaKeyCode = key
            Preferences.areaModifiers = modifiers
        }
        HotkeyCenter.shared.reregister()
        AppDelegate.shared?.refreshMenu()
        stopRecording()
        refresh()
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold, design: .rounded))

            section("Keyboard shortcuts") {
                ForEach(CaptureHotkey.allCases, id: \.rawValue) { hotkey in
                    hotkeyRow(hotkey)
                }
                if let bindError = model.bindError {
                    Text(bindError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                HStack {
                    Spacer()
                    Button("Reset shortcuts", action: model.resetHotkeys)
                }
            }

            section("Permissions") {
                HStack {
                    Image(systemName: model.hasScreenRecording ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.hasScreenRecording ? Color.green : Theme.swiftAccent)
                    Text(model.hasScreenRecording ? "Screen Recording allowed" : "Screen Recording needs a fresh grant")
                    Spacer()
                    Button(model.hasScreenRecording ? "Open Settings" : "Grant…") {
                        if model.hasScreenRecording {
                            Permissions.openScreenRecordingSettings()
                        } else {
                            Permissions.requestScreenRecording()
                            if !Permissions.hasScreenRecording() {
                                Permissions.openScreenRecordingSettings()
                            }
                            model.refresh()
                            AppDelegate.shared?.refreshMenu()
                        }
                    }
                }
                Text("Frame never uploads the screen. If the toggle in System Settings is already on, turn Frame off and on so this build can match.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            section("General") {
                Toggle("Hide secrets on copy", isOn: Binding(
                    get: { model.autoRedact },
                    set: {
                        Preferences.autoRedact = $0
                        model.autoRedact = $0
                    }
                ))
                Text("Blur emails and key-shaped strings before the clipboard. Stays on this Mac. Space after copy opens the editor if you need to undo.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLogin($0) }
                ))
                if let loginError = model.loginError {
                    Text(loginError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(24)
        .frame(width: 480)
        .frameGlass(cornerRadius: 24)
        .onAppear { model.refresh() }
        .onDisappear { model.stopRecording() }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func hotkeyRow(_ hotkey: CaptureHotkey) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hotkey.title)
                Text(hotkey.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                model.beginRecord(hotkey)
            } label: {
                Text(model.recording == hotkey ? "Press keys…" : (model.chords[hotkey] ?? ""))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frameGlass(cornerRadius: 8)
            }
            .buttonStyle(.plain)
            .help("Click, then press the shortcut")
        }
    }
}

@MainActor
enum SettingsWindow {
    private static var window: NSWindow?
    private static var model = SettingsModel()

    static func show() {
        model.refresh()
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(model: model))
            let win = GlassPanel.window(title: "Settings", content: host)
            win.center()
            window = win
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
