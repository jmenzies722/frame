import Foundation

/// Caption is capability-gated. Absent on this OS / SDK until Foundation Models
/// can take a screenshot on-device. Do not show a stub control.
enum CaptionService {
    static var isAvailable: Bool { false }

    static func caption(for imageHint: String) async -> String? {
        _ = imageHint
        return nil
    }
}
