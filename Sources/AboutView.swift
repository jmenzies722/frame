import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text(ProductIdentity.displayName)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("Version \(ProductIdentity.appVersion)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(ProductIdentity.tagline)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Local only. No account. No upload.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 320)
        .frameGlass(cornerRadius: 22)
    }
}

@MainActor
enum AboutWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let host = NSHostingController(rootView: AboutView())
            let win = GlassPanel.window(title: "About \(ProductIdentity.displayName)", content: host)
            win.center()
            window = win
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
