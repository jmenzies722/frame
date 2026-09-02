import SwiftUI

struct OnboardingView: View {
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(ProductIdentity.displayName)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(ProductIdentity.tagline)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Click any display. Frame copies the shot and stays on this Mac. Screen Recording is the only permission.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Get Started") {
                    Preferences.didOnboard = true
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 400)
        .frameGlass(cornerRadius: 24)
    }
}

@MainActor
enum OnboardingWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let host = NSHostingController(rootView: OnboardingView {
                window?.close()
                window = nil
            })
            let win = GlassPanel.window(title: ProductIdentity.displayName, content: host)
            win.center()
            window = win
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func dismiss() {
        window?.close()
        window = nil
    }
}
