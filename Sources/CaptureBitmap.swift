import AppKit
import CoreGraphics

struct CaptureBitmap {
    let image: CGImage
    let scale: CGFloat

    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    var pointSize: NSSize {
        NSSize(
            width: CGFloat(image.width) / max(scale, 1),
            height: CGFloat(image.height) / max(scale, 1)
        )
    }

    func nsImage() -> NSImage {
        Export.nsImage(image, scale: scale)
    }

    func cropped(to pixelRect: CGRect) -> CaptureBitmap? {
        let integral = pixelRect.integral.intersection(
            CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        guard integral.width >= 2, integral.height >= 2 else { return nil }
        guard let cut = image.cropping(to: integral) else { return nil }
        return CaptureBitmap(image: cut, scale: scale)
    }
}
