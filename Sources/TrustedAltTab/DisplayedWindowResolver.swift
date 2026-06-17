import ApplicationServices
import AppKit
import CoreGraphics

final class DisplayedWindowResolver {
    private let ownPID = getpid()

    func frontmostTarget() -> DisplayedWindowTarget? {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for dictionary in rawWindows {
            guard let target = makeDisplayedWindowTarget(dictionary: dictionary) else {
                continue
            }
            return target
        }

        return nil
    }

    func accessibilityWindow(for target: DisplayedWindowTarget) -> AXUIElement? {
        let windows = Accessibility.windows(for: target.pid)
        guard !windows.isEmpty else {
            return nil
        }

        if let exact = windows.first(where: { axWindow in
            titlesMatch(axWindow, target: target) && boundsMatch(axWindow, target: target)
        }) {
            return exact
        }

        if let byBounds = windows.first(where: { boundsMatch($0, target: target) }) {
            return byBounds
        }

        if let byTitle = windows.first(where: { titlesMatch($0, target: target) }) {
            return byTitle
        }

        return nil
    }

    func focusedWindow(for pid: pid_t) -> AXUIElement? {
        elementAttribute(Accessibility.applicationElement(pid: pid), kAXFocusedWindowAttribute as CFString)
    }

    func mainWindow(for pid: pid_t) -> AXUIElement? {
        elementAttribute(Accessibility.applicationElement(pid: pid), kAXMainWindowAttribute as CFString)
    }

    func isWindowStillOnScreen(_ target: DisplayedWindowTarget) -> Bool {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return true
        }

        for dictionary in rawWindows {
            guard let idNumber = dictionary[kCGWindowNumber as String] as? NSNumber,
                  CGWindowID(idNumber.uint32Value) == target.id else {
                continue
            }

            return (dictionary[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
        }

        return false
    }

    private func makeDisplayedWindowTarget(dictionary: [String: Any]) -> DisplayedWindowTarget? {
        guard let idNumber = dictionary[kCGWindowNumber as String] as? NSNumber else {
            return nil
        }

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

        return DisplayedWindowTarget(
            id: CGWindowID(idNumber.uint32Value),
            pid: pid,
            appName: app.localizedName
                ?? dictionary[kCGWindowOwnerName as String] as? String
                ?? String(pid),
            title: dictionary[kCGWindowName as String] as? String ?? "",
            bounds: bounds
        )
    }

    private func titlesMatch(_ axWindow: AXUIElement, target: DisplayedWindowTarget) -> Bool {
        let targetTitle = target.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetTitle.isEmpty else {
            return false
        }

        let axTitle = Accessibility.stringAttribute(axWindow, kAXTitleAttribute as CFString)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return axTitle == targetTitle
    }

    private func boundsMatch(_ axWindow: AXUIElement, target: DisplayedWindowTarget) -> Bool {
        guard let bounds = Accessibility.rectAttribute(axWindow) else {
            return false
        }

        let tolerance: CGFloat = 6
        return abs(bounds.origin.x - target.bounds.origin.x) <= tolerance
            && abs(bounds.origin.y - target.bounds.origin.y) <= tolerance
            && abs(bounds.width - target.bounds.width) <= tolerance
            && abs(bounds.height - target.bounds.height) <= tolerance
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        AXUIElementSetMessagingTimeout(element, 0.15)

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }
}

struct DisplayedWindowTarget {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let bounds: CGRect

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "无标题窗口" : trimmed
    }

    var identityKey: String {
        [
            String(pid),
            displayTitle,
            String(Int(bounds.origin.x.rounded())),
            String(Int(bounds.origin.y.rounded())),
            String(Int(bounds.width.rounded())),
            String(Int(bounds.height.rounded()))
        ].joined(separator: "|")
    }

    var appKey: String {
        "\(pid)|\(appName)"
    }
}
