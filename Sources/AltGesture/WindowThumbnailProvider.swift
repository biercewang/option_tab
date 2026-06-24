import AppKit
import CoreGraphics

final class WindowThumbnailProvider {
    static let shared = WindowThumbnailProvider()

    private let cache = NSCache<NSNumber, NSImage>()

    private init() {}

    func thumbnail(for window: WindowInfo) -> NSImage? {
        guard AppSettings.shared.showThumbnails,
              window.isOnScreen,
              ScreenCapturePermission.hasAccess() else {
            return window.icon
        }

        let key = NSNumber(value: window.id)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            window.id,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return window.icon
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: key)
        return image
    }
}
