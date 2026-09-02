import AppKit
import Carbon
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published var regionChord: String
    @Published var windowChord: String
    @Published var displayChord: String
    @Published var recording: CaptureHotkey?
    @Published var launchAtLogin: Bool
    @Published var hasScreenRecording: Bool
    @Published var loginError: String?

    private var monitor: Any?

    init() {
        regionChord = HotkeyCenter.describe(keyCode: Preferences.regionKeyCode, modifiers: Preferences.regionModifiers)
        windowChord = HotkeyCenter.describe(keyCode: Preferences.windowKeyCode, modifiers: Preferences.windowModifiers)
        displayChord = HotkeyCenter.describe(keyCode: Preferences.displayKeyCode, modifiers: Preferences.displayModifiers)
        launchAtLogin = LoginItem.isEnabled
        hasScreenRecording = Permissions.hasScreenRecording()
    }

    func refresh() {
        hasScreenRecording = Permissions.hasScreenRecording()
        launchAtLogin = LoginItem.isEnabled
        regionChord = HotkeyCenter.describe(keyCode: Preferences.regionKeyCode, modifiers: Preferences.regionModifiers)
        windowChord = HotkeyCenter.describe(keyCode: Preferences.windowKeyCode, modifiers: Preferences.windowModifiers)
        displayChord = HotkeyCenter.describe(keyCode: Preferences.displayKeyCode, modifiers: Preferences.displayModifiers)
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
        guard hasPrimary else { return }
        let key = UInt32(event.keyCode)
        if HotkeyCenter.isReservedSystemCapture(keyCode: key, modifiers: modifiers) {
            return
        }
        guard let recording else { return }
        switch recording {
        case .region:
            Preferences.regionKeyCode = key
            Preferences.regionModifiers = modifiers
        case .window:
            Preferences.windowKeyCode = key
            Preferences.windowModifiers = modifiers
        case .display:
            Preferences.displayKeyCode = key
            Preferences.displayModifiers = modifiers
        }
        HotkeyCenter.shared.reregister()
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

            section("Capture") {
                hotkeyRow("Capture", chord: model.regionChord, which: .region)
                hotkeyRow("Window", chord: model.windowChord, which: .window)
                hotkeyRow("Display", chord: model.displayChord, which: .display)
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
        .frame(width: 460)
        .frameGlass(cornerRadius: 24)
        .onAppear { model.refresh() }
        .onDisappear { model.stopRecording() }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.swiftMuted)
            content()
        }
    }

    private func hotkeyRow(_ title: String, chord: String, which: CaptureHotkey) -> some View {
        HStack {
            Text(title)
                .frame(width: 72, alignment: .leading)
            Text(model.recording == which ? "Press a shortcut…" : chord)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
            Spacer()
            Button(model.recording == which ? "Listening" : "Change…") {
                model.beginRecord(which)
            }
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
