import Carbon
import Foundation

enum PrefKey {
    static let didOnboard = "didOnboard"
    static let frameEnabled = "frameEnabled"
    static let launchAtLogin = "launchAtLogin"
    static let regionKeyCode = "regionKeyCode"
    static let windowKeyCode = "windowKeyCode"
    static let displayKeyCode = "displayKeyCode"
    static let areaKeyCode = "areaKeyCode"
    static let regionModifiers = "regionModifiers"
    static let windowModifiers = "windowModifiers"
    static let displayModifiers = "displayModifiers"
    static let areaModifiers = "areaModifiers"
    static let autoRedact = "autoRedact"
}

enum HotkeyDefaults {
    static let regionKey: UInt32 = UInt32(kVK_ANSI_2)
    static let windowKey: UInt32 = UInt32(kVK_ANSI_3)
    static let displayKey: UInt32 = UInt32(kVK_ANSI_1)
    static let areaKey: UInt32 = UInt32(kVK_ANSI_R)
    static let modifiers: UInt32 = UInt32(controlKey | shiftKey | cmdKey)
}

enum Preferences {
    private static var defaults: UserDefaults { .standard }

    static var autoRedact: Bool {
        get {
            if defaults.object(forKey: PrefKey.autoRedact) == nil { return true }
            return defaults.bool(forKey: PrefKey.autoRedact)
        }
        set { defaults.set(newValue, forKey: PrefKey.autoRedact) }
    }

    static var didOnboard: Bool {
        get { defaults.bool(forKey: PrefKey.didOnboard) }
        set { defaults.set(newValue, forKey: PrefKey.didOnboard) }
    }

    static var frameEnabled: Bool {
        get {
            if defaults.object(forKey: PrefKey.frameEnabled) == nil { return true }
            return defaults.bool(forKey: PrefKey.frameEnabled)
        }
        set { defaults.set(newValue, forKey: PrefKey.frameEnabled) }
    }

    static var regionKeyCode: UInt32 {
        get { uint(PrefKey.regionKeyCode, HotkeyDefaults.regionKey) }
        set { defaults.set(Int(newValue), forKey: PrefKey.regionKeyCode) }
    }

    static var windowKeyCode: UInt32 {
        get { uint(PrefKey.windowKeyCode, HotkeyDefaults.windowKey) }
        set { defaults.set(Int(newValue), forKey: PrefKey.windowKeyCode) }
    }

    static var displayKeyCode: UInt32 {
        get { uint(PrefKey.displayKeyCode, HotkeyDefaults.displayKey) }
        set { defaults.set(Int(newValue), forKey: PrefKey.displayKeyCode) }
    }

    static var regionModifiers: UInt32 {
        get { uint(PrefKey.regionModifiers, HotkeyDefaults.modifiers) }
        set { defaults.set(Int(newValue), forKey: PrefKey.regionModifiers) }
    }

    static var windowModifiers: UInt32 {
        get { uint(PrefKey.windowModifiers, HotkeyDefaults.modifiers) }
        set { defaults.set(Int(newValue), forKey: PrefKey.windowModifiers) }
    }

    static var displayModifiers: UInt32 {
        get { uint(PrefKey.displayModifiers, HotkeyDefaults.modifiers) }
        set { defaults.set(Int(newValue), forKey: PrefKey.displayModifiers) }
    }

    static var areaKeyCode: UInt32 {
        get { uint(PrefKey.areaKeyCode, HotkeyDefaults.areaKey) }
        set { defaults.set(Int(newValue), forKey: PrefKey.areaKeyCode) }
    }

    static var areaModifiers: UInt32 {
        get { uint(PrefKey.areaModifiers, HotkeyDefaults.modifiers) }
        set { defaults.set(Int(newValue), forKey: PrefKey.areaModifiers) }
    }

    static func resetHotkeys() {
        regionKeyCode = HotkeyDefaults.regionKey
        windowKeyCode = HotkeyDefaults.windowKey
        displayKeyCode = HotkeyDefaults.displayKey
        areaKeyCode = HotkeyDefaults.areaKey
        regionModifiers = HotkeyDefaults.modifiers
        windowModifiers = HotkeyDefaults.modifiers
        displayModifiers = HotkeyDefaults.modifiers
        areaModifiers = HotkeyDefaults.modifiers
    }

    private static func uint(_ key: String, _ fallback: UInt32) -> UInt32 {
        guard let stored = defaults.object(forKey: key) as? Int else { return fallback }
        return UInt32(stored)
    }
}
