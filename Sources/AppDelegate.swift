import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var screenItem: NSMenuItem?
    private var windowItem: NSMenuItem?
    private var displayItem: NSMenuItem?
    private var areaItem: NSMenuItem?
    private var permissionItem: NSMenuItem?
    private var historyMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        HotkeyCenter.shared.start()
        installEditMenu()
        buildStatusItem()
        refreshMenu()
        if !Preferences.didOnboard {
            OnboardingWindow.show()
        }
    }

    func refreshMenu() {
        let allowed = Permissions.hasScreenRecording()
        permissionItem?.isHidden = allowed
        apply(screenItem, key: Preferences.regionKeyCode, modifiers: Preferences.regionModifiers)
        apply(windowItem, key: Preferences.windowKeyCode, modifiers: Preferences.windowModifiers)
        apply(displayItem, key: Preferences.displayKeyCode, modifiers: Preferences.displayModifiers)
        apply(areaItem, key: Preferences.areaKeyCode, modifiers: Preferences.areaModifiers)
        rebuildHistory()
        statusItem?.button?.toolTip = allowed
            ? "\(ProductIdentity.displayName) — click a display to copy"
            : "\(ProductIdentity.displayName) — Screen Recording required"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu()
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: ProductIdentity.displayName)
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.delegate = self

        let permission = NSMenuItem(
            title: "Screen Recording is required",
            action: #selector(openPermissionSettings),
            keyEquivalent: ""
        )
        permissionItem = permission
        menu.addItem(permission)

        let capture = NSMenuItem(title: "Capture", action: #selector(captureScreen), keyEquivalent: "2")
        screenItem = capture
        menu.addItem(capture)

        let window = NSMenuItem(title: "Capture Window", action: #selector(captureWindow), keyEquivalent: "3")
        windowItem = window
        menu.addItem(window)

        let display = NSMenuItem(title: "Capture Display Under Pointer", action: #selector(captureDisplay), keyEquivalent: "1")
        displayItem = display
        menu.addItem(display)

        let region = NSMenuItem(title: "Capture Region…", action: #selector(captureRegion), keyEquivalent: "r")
        areaItem = region
        menu.addItem(region)

        menu.addItem(.separator())

        let history = NSMenu()
        historyMenu = history
        let historyItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        historyItem.submenu = history
        menu.addItem(historyItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About \(ProductIdentity.displayName)", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(ProductIdentity.displayName)", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func rebuildHistory() {
        guard let historyMenu else { return }
        historyMenu.removeAllItems()
        let items = HistoryStore.shared.items
        if items.isEmpty {
            let empty = NSMenuItem(title: "No captures yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            historyMenu.addItem(empty)
            return
        }
        for (index, item) in items.enumerated() {
            let menuItem = NSMenuItem(title: item.title, action: #selector(openHistory(_:)), keyEquivalent: "")
            menuItem.representedObject = item.id.uuidString
            menuItem.tag = index
            menuItem.target = self
            historyMenu.addItem(menuItem)
        }
        historyMenu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        historyMenu.addItem(clear)
    }

    @objc private func captureScreen() { CaptureCoordinator.shared.captureScreen(waitForMenu: true) }
    @objc private func captureRegion() { CaptureCoordinator.shared.captureRegion(waitForMenu: true) }
    @objc private func captureWindow() { CaptureCoordinator.shared.captureWindow(waitForMenu: true) }
    @objc private func captureDisplay() { CaptureCoordinator.shared.captureDisplay(waitForMenu: true) }
    @objc private func showSettings() { SettingsWindow.show() }
    @objc private func showAbout() { AboutWindow.show() }
    @objc private func openPermissionSettings() {
        _ = Permissions.requestScreenRecording()
        if !Permissions.hasScreenRecording() {
            Permissions.openScreenRecordingSettings()
        }
        refreshMenu()
    }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openHistory(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw),
              let item = HistoryStore.shared.items.first(where: { $0.id == id })
        else { return }
        EditorController.shared.presentHistory(item)
    }

    @objc private func clearHistory() {
        HistoryStore.shared.clear()
        refreshMenu()
    }

    private func apply(_ item: NSMenuItem?, key: UInt32, modifiers: UInt32) {
        item?.isEnabled = true
        item?.keyEquivalent = HotkeyCenter.menuEquivalent(keyCode: key)
        item?.keyEquivalentModifierMask = HotkeyCenter.cocoaModifiers(from: modifiers)
    }

    private func installEditMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
