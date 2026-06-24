import CoreGraphics

enum InputMonitoringPermission {
    static func requestIfNeeded() {
        if #available(macOS 10.15, *), !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }
    }

    static func hasAccess() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        }
        return true
    }
}
