import Foundation

/// All user-visible and bundle-facing names live here so the product can be renamed in one place.
enum ProductIdentity: Sendable {
    static let displayName = "Frame"
    static let bundleIdentifier = "com.shualabs.frame"
    static let appVersion = "0.1.1"
    static let tagline = "Click a display. It’s on the clipboard."
    static let saveFolderName = "Frame"
    static let historyFolderName = "History"
    static let supportFolderName = "Frame"

    static let screenRecordingUsage =
        "Frame captures the screen region, window, or display you choose. The image stays on this Mac — Frame never uploads it."
}
