import ApplicationServices
import AppKit
import Foundation

enum WindowSnapDirection {
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center
    case fill
    case restore
    case toggleFill

    var logName: String {
        switch self {
        case .left:
            return "left"
        case .right:
            return "right"
        case .top:
            return "top"
        case .bottom:
            return "bottom"
        case .topLeft:
            return "topLeft"
        case .topRight:
            return "topRight"
        case .bottomLeft:
            return "bottomLeft"
        case .bottomRight:
            return "bottomRight"
        case .center:
            return "center"
        case .fill:
            return "fill"
        case .restore:
            return "restore"
        case .toggleFill:
            return "toggleFill"
        }
    }

    init?(rightGestureActionName name: String) {
        switch name.lowercased() {
        case "left", "lefthalf":
            self = .left
        case "right", "righthalf":
            self = .right
        case "top", "up", "tophalf":
            self = .top
        case "bottom", "down", "bottomhalf":
            self = .bottom
        case "topleft", "upperleft":
            self = .topLeft
        case "topright", "upperright":
            self = .topRight
        case "bottomleft", "lowerleft":
            self = .bottomLeft
        case "bottomright", "lowerright":
            self = .bottomRight
        case "center", "centre":
            self = .center
        case "fill", "maximize", "maximise":
            self = .fill
        case "restore":
            self = .restore
        case "togglefill", "togglemaximize", "togglemaximise":
            self = .toggleFill
        default:
            return nil
        }
    }
}

final class WindowSnapper {
    private let resolver = DisplayedWindowResolver()
    private var restoreFrames: [String: CGRect] = [:]

    func snapFrontmostWindow(to direction: WindowSnapDirection) -> Bool {
        guard Accessibility.isTrusted(prompt: true) else {
            DebugLog.write("snap failed: accessibility not trusted")
            return false
        }

        guard let target = resolver.frontmostTarget() else {
            DebugLog.write("snap failed: no frontmost displayed window direction=\(direction.logName)")
            return false
        }

        guard let window = resolver.accessibilityWindow(for: target)
            ?? resolver.focusedWindow(for: target.pid)
            ?? resolver.mainWindow(for: target.pid) else {
            DebugLog.write("snap failed: no matching/focused/main window app=\(target.appName) title=\(target.displayTitle) direction=\(direction.logName)")
            return false
        }

        if Accessibility.boolAttribute(window, kAXMinimizedAttribute as CFString) == true {
            Accessibility.setBool(window, kAXMinimizedAttribute as CFString, value: false)
        }

        if direction == .restore {
            return restore(window, target: target)
        }

        if direction == .toggleFill {
            return toggleFill(window, target: target)
        }

        saveRestoreFrameIfNeeded(window, target: target)

        let frame = snapFrame(for: target, direction: direction)
        set(window, to: frame)

        if confirm(window, frame: frame) {
            DebugLog.write("snapped displayed window app=\(target.appName) title=\(target.displayTitle) direction=\(direction.logName)")
            return true
        }

        DebugLog.write("snap requested but not confirmed app=\(target.appName) title=\(target.displayTitle) direction=\(direction.logName)")
        return false
    }

    private func saveRestoreFrameIfNeeded(_ window: AXUIElement, target: DisplayedWindowTarget) {
        let key = restoreKey(for: target)
        guard restoreFrames[key] == nil else {
            return
        }

        restoreFrames[key] = Accessibility.rectAttribute(window) ?? target.bounds
    }

    private func restore(_ window: AXUIElement, target: DisplayedWindowTarget) -> Bool {
        let key = restoreKey(for: target)
        guard let frame = restoreFrames[key] else {
            DebugLog.write("restore failed: no saved frame app=\(target.appName) title=\(target.displayTitle)")
            return false
        }

        set(window, to: frame)

        if confirm(window, frame: frame) {
            restoreFrames.removeValue(forKey: key)
            DebugLog.write("restored displayed window app=\(target.appName) title=\(target.displayTitle)")
            return true
        }

        DebugLog.write("restore requested but not confirmed app=\(target.appName) title=\(target.displayTitle)")
        return false
    }

    private func toggleFill(_ window: AXUIElement, target: DisplayedWindowTarget) -> Bool {
        let fillFrame = snapFrame(for: target, direction: .fill)
        let currentFrame = Accessibility.rectAttribute(window) ?? target.bounds

        if isClose(currentFrame, to: fillFrame) {
            return restore(window, target: target)
        }

        saveRestoreFrameIfNeeded(window, target: target)
        set(window, to: fillFrame)

        if confirm(window, frame: fillFrame) {
            DebugLog.write("toggle-filled displayed window app=\(target.appName) title=\(target.displayTitle)")
            return true
        }

        DebugLog.write("toggle fill requested but not confirmed app=\(target.appName) title=\(target.displayTitle)")
        return false
    }

    private func set(_ window: AXUIElement, to frame: CGRect) {
        AXUIElementSetMessagingTimeout(window, 0.15)

        Accessibility.setPoint(window, kAXPositionAttribute as CFString, value: frame.origin)
        Accessibility.setSize(window, kAXSizeAttribute as CFString, value: frame.size)
        Accessibility.setPoint(window, kAXPositionAttribute as CFString, value: frame.origin)
    }

    private func confirm(_ window: AXUIElement, frame: CGRect) -> Bool {
        for _ in 0..<6 {
            if let current = Accessibility.rectAttribute(window), isClose(current, to: frame) {
                return true
            }

            Thread.sleep(forTimeInterval: 0.02)
        }

        return false
    }

    private func snapFrame(for target: DisplayedWindowTarget, direction: WindowSnapDirection) -> CGRect {
        let visibleFrame = visibleFrameForTarget(target)
        let leftWidth = floor(visibleFrame.width / 2)
        let rightWidth = visibleFrame.width - leftWidth
        let topHeight = floor(visibleFrame.height / 2)
        let bottomHeight = visibleFrame.height - topHeight

        switch direction {
        case .left:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: leftWidth,
                height: visibleFrame.height
            ).integral
        case .right:
            return CGRect(
                x: visibleFrame.minX + leftWidth,
                y: visibleFrame.minY,
                width: rightWidth,
                height: visibleFrame.height
            ).integral
        case .top:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width,
                height: topHeight
            ).integral
        case .bottom:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY + topHeight,
                width: visibleFrame.width,
                height: bottomHeight
            ).integral
        case .topLeft:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: leftWidth,
                height: topHeight
            ).integral
        case .topRight:
            return CGRect(
                x: visibleFrame.minX + leftWidth,
                y: visibleFrame.minY,
                width: rightWidth,
                height: topHeight
            ).integral
        case .bottomLeft:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY + topHeight,
                width: leftWidth,
                height: bottomHeight
            ).integral
        case .bottomRight:
            return CGRect(
                x: visibleFrame.minX + leftWidth,
                y: visibleFrame.minY + topHeight,
                width: rightWidth,
                height: bottomHeight
            ).integral
        case .center:
            let currentWidth = min(max(target.bounds.width, visibleFrame.width * 0.35), visibleFrame.width)
            let currentHeight = min(max(target.bounds.height, visibleFrame.height * 0.35), visibleFrame.height)
            return CGRect(
                x: visibleFrame.midX - currentWidth / 2,
                y: visibleFrame.midY - currentHeight / 2,
                width: currentWidth,
                height: currentHeight
            ).integral
        case .fill:
            return visibleFrame.integral
        case .restore:
            return target.bounds.integral
        case .toggleFill:
            return visibleFrame.integral
        }
    }

    private func restoreKey(for target: DisplayedWindowTarget) -> String {
        "\(target.pid)|\(target.id)"
    }

    private func visibleFrameForTarget(_ target: DisplayedWindowTarget) -> CGRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return target.bounds
        }

        let scored = screens.map { screen in
            let visibleFrame = accessibilityVisibleFrame(for: screen)
            return (visibleFrame: visibleFrame, area: intersectionArea(visibleFrame, target.bounds))
        }

        if let best = scored.max(by: { $0.area < $1.area }), best.area > 0 {
            return best.visibleFrame
        }

        if let main = NSScreen.main {
            return accessibilityVisibleFrame(for: main)
        }

        return accessibilityVisibleFrame(for: screens[0])
    }

    private func accessibilityVisibleFrame(for screen: NSScreen) -> CGRect {
        let frame = screen.frame
        let visibleFrame = screen.visibleFrame
        let topInset = frame.maxY - visibleFrame.maxY

        return CGRect(
            x: visibleFrame.minX,
            y: frame.minY + topInset,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else {
            return 0
        }
        return intersection.width * intersection.height
    }

    private func isClose(_ lhs: CGRect, to rhs: CGRect) -> Bool {
        let tolerance: CGFloat = 24
        return abs(lhs.origin.x - rhs.origin.x) <= tolerance
            && abs(lhs.origin.y - rhs.origin.y) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
