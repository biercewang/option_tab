import CoreGraphics

enum ScreenCapturePermission {
    static func requestIfNeeded() {
        guard !hasAccess() else {
            return
        }

        _ = CGRequestScreenCaptureAccess()
    }

    static func hasAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
}
