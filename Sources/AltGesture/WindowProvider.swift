import ApplicationServices
import AppKit
import CoreGraphics

final class WindowProvider {
    private let ownPID = getpid()

    func visibleWindowsOnly(log: Bool = true) -> [WindowInfo] {
        let windows = visibleWindows().sorted { lhs, rhs in
            lhs.order < rhs.order
        }
        if log {
            DebugLog.write("visible windows=\(windows.count)")
        }
        return windows
    }

    func windows(includeMinimized: Bool, includeHidden: Bool) -> [WindowInfo] {
        var windows = visibleWindowsOnly()

        if (includeMinimized || includeHidden), Accessibility.isTrusted() {
            let accessibilityWindows = accessibilityOnlyWindows(
                excluding: windows,
                includeMinimized: includeMinimized,
                includeHidden: includeHidden
            )
            DebugLog.write("accessibility-only windows=\(accessibilityWindows.count) includeMinimized=\(includeMinimized) includeHidden=\(includeHidden)")
            windows.append(contentsOf: accessibilityWindows)
        } else if includeMinimized || includeHidden {
            DebugLog.write("accessibility not trusted; minimized/hidden windows unavailable")
        }

        return windows.sorted { lhs, rhs in
            lhs.order < rhs.order
        }
    }

    func frontmostVisibleWindow(from windows: [WindowInfo]) -> WindowInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ownPID else {
            return windows.first
        }

        let candidates = windows.filter { $0.pid == app.processIdentifier }
        guard !candidates.isEmpty else {
            return nil
        }

        if Accessibility.isTrusted(),
           let focusedWindow = focusedWindowDetails(for: app.processIdentifier),
           let exactMatch = candidates.first(where: { matches($0, focusedWindow) }) {
            return exactMatch
        }

        return candidates.sorted { lhs, rhs in
            lhs.order < rhs.order
        }.first
    }

    private func visibleWindows() -> [WindowInfo] {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var windows: [WindowInfo] = []
        var seen = Set<CGWindowID>()

        for (order, dictionary) in rawWindows.enumerated() {
            guard let window = makeVisibleWindow(dictionary: dictionary, order: order) else {
                continue
            }

            guard !seen.contains(window.id) else {
                continue
            }

            seen.insert(window.id)
            windows.append(window)
        }

        return windows
    }

    private func makeVisibleWindow(dictionary: [String: Any], order: Int) -> WindowInfo? {
        guard let idNumber = dictionary[kCGWindowNumber as String] as? NSNumber else {
            return nil
        }

        let id = CGWindowID(idNumber.uint32Value)
        let layer = (dictionary[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        guard layer == 0 else {
            return nil
        }

        let alpha = (dictionary[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
        guard alpha > 0.02 else {
            return nil
        }

        guard let pidNumber = dictionary[kCGWindowOwnerPID as String] as? NSNumber else {
            return nil
        }

        let pid = pid_t(pidNumber.int32Value)
        guard pid != ownPID else {
            return nil
        }

        guard let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy != .prohibited else {
            return nil
        }

        guard let boundsDictionary = dictionary[kCGWindowBounds as String] as? NSDictionary else {
            return nil
        }

        var bounds = CGRect.zero
        guard CGRectMakeWithDictionaryRepresentation(boundsDictionary, &bounds) else {
            return nil
        }

        guard bounds.width >= 80, bounds.height >= 40 else {
            return nil
        }

        let appName = app.localizedName
            ?? dictionary[kCGWindowOwnerName as String] as? String
            ?? "未知应用"
        let title = dictionary[kCGWindowName as String] as? String ?? ""

        return WindowInfo(
            id: id,
            pid: pid,
            appName: appName,
            title: title,
            bounds: bounds,
            icon: app.icon,
            isOnScreen: true,
            isMinimized: false,
            isHidden: app.isHidden,
            order: order
        )
    }

    func accessibilityOnlyWindows(
        excluding visibleWindows: [WindowInfo],
        includeMinimized: Bool,
        includeHidden: Bool
    ) -> [WindowInfo] {
        let visibleKeys = Set(visibleWindows.map { $0.identityKey })
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ownPID && $0.activationPolicy != .prohibited }

        var results: [WindowInfo] = []
        var order = visibleWindows.count

        for app in apps {
            let axWindows = Accessibility.windows(for: app.processIdentifier)
            for (index, axWindow) in axWindows.enumerated() {
                let title = Accessibility.stringAttribute(axWindow, kAXTitleAttribute as CFString) ?? ""
                let minimized = Accessibility.boolAttribute(axWindow, kAXMinimizedAttribute as CFString) ?? false
                let bounds = Accessibility.rectAttribute(axWindow) ?? .zero

                guard (includeMinimized && minimized) || (includeHidden && app.isHidden) else {
                    continue
                }

                let candidate = WindowInfo(
                    id: syntheticWindowID(pid: app.processIdentifier, index: index),
                    pid: app.processIdentifier,
                    appName: app.localizedName ?? "未知应用",
                    title: title,
                    bounds: bounds,
                    icon: app.icon,
                    isOnScreen: false,
                    isMinimized: minimized,
                    isHidden: app.isHidden,
                    order: order
                )

                guard !visibleKeys.contains(candidate.identityKey) else {
                    continue
                }

                results.append(candidate)
                order += 1
            }
        }

        return results
    }

    private func syntheticWindowID(pid: pid_t, index: Int) -> CGWindowID {
        let pidBits = UInt32(bitPattern: Int32(pid)) & 0x00ff_ffff
        let indexBits = UInt32(index & 0xff) << 24
        return CGWindowID(indexBits | pidBits)
    }

    private func focusedWindowDetails(for pid: pid_t) -> (title: String, bounds: CGRect)? {
        let app = Accessibility.applicationElement(pid: pid)
        AXUIElementSetMessagingTimeout(app, 0.04)

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success,
              let rawValue = value,
              CFGetTypeID(rawValue) == AXUIElementGetTypeID() else {
            return nil
        }

        let focusedWindow = rawValue as! AXUIElement
        AXUIElementSetMessagingTimeout(focusedWindow, 0.04)
        let title = Accessibility.stringAttribute(focusedWindow, kAXTitleAttribute as CFString) ?? ""
        let bounds = Accessibility.rectAttribute(focusedWindow) ?? .zero
        return (title, bounds)
    }

    private func matches(_ window: WindowInfo, _ focusedWindow: (title: String, bounds: CGRect)) -> Bool {
        let focusedTitle = focusedWindow.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let windowTitle = window.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if !focusedTitle.isEmpty, focusedTitle == windowTitle {
            return true
        }

        let tolerance: CGFloat = 4
        return abs(window.bounds.origin.x - focusedWindow.bounds.origin.x) <= tolerance
            && abs(window.bounds.origin.y - focusedWindow.bounds.origin.y) <= tolerance
            && abs(window.bounds.width - focusedWindow.bounds.width) <= tolerance
            && abs(window.bounds.height - focusedWindow.bounds.height) <= tolerance
    }
}
