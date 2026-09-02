import AppKit
import CoreGraphics

enum Permissions {
    static func hasScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestScreenRecording() -> Bool {
        if hasScreenRecording() { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func openScreenRecordingSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    @MainActor
    static func presentDenied() {
        AppDelegate.shared?.refreshMenu()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Screen Recording needs a fresh grant"
        alert.informativeText = "macOS still has an older Frame build on file. If Screen Recording already looks allowed, turn Frame off and on — or quit Frame and run make unlock. The image never leaves this Mac."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }
}
