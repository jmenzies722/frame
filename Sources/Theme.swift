import AppKit
import SwiftUI

enum Theme {
    static let ink = NSColor(srgbRed: 0.086, green: 0.094, blue: 0.118, alpha: 1)
    static let canvas = NSColor(srgbRed: 0.055, green: 0.059, blue: 0.075, alpha: 1)
    static let rail = NSColor(srgbRed: 0.110, green: 0.118, blue: 0.145, alpha: 1)
    static let stroke = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    static let text = NSColor(srgbRed: 0.93, green: 0.93, blue: 0.95, alpha: 1)
    static let muted = NSColor(srgbRed: 0.62, green: 0.64, blue: 0.70, alpha: 1)
    static let accent = NSColor(srgbRed: 0.93, green: 0.45, blue: 0.36, alpha: 1)
    static let frameTop = NSColor(srgbRed: 0.145, green: 0.176, blue: 0.255, alpha: 1)
    static let frameBottom = NSColor(srgbRed: 0.078, green: 0.098, blue: 0.157, alpha: 1)

    static var swiftInk: Color { Color(nsColor: ink) }
    static var swiftCanvas: Color { Color(nsColor: canvas) }
    static var swiftRail: Color { Color(nsColor: rail) }
    static var swiftText: Color { Color(nsColor: text) }
    static var swiftMuted: Color { Color(nsColor: muted) }
    static var swiftAccent: Color { Color(nsColor: accent) }
}

enum Swatch: String, CaseIterable, Identifiable {
    case coral, amber, lime, sky, violet, white

    var id: String { rawValue }

    var color: NSColor {
        switch self {
        case .coral: return NSColor(srgbRed: 0.93, green: 0.45, blue: 0.36, alpha: 1)
        case .amber: return NSColor(srgbRed: 0.96, green: 0.74, blue: 0.28, alpha: 1)
        case .lime: return NSColor(srgbRed: 0.55, green: 0.86, blue: 0.40, alpha: 1)
        case .sky: return NSColor(srgbRed: 0.40, green: 0.72, blue: 0.98, alpha: 1)
        case .violet: return NSColor(srgbRed: 0.67, green: 0.55, blue: 0.98, alpha: 1)
        case .white: return NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        }
    }

    var swiftColor: Color { Color(nsColor: color) }
}
