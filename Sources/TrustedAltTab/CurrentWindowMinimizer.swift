import ApplicationServices
import Foundation

final class CurrentWindowMinimizer {
    private let resolver = DisplayedWindowResolver()

    func minimizeFrontmostWindow() -> DisplayedWindowTarget? {
        guard Accessibility.isTrusted(prompt: true) else {
            DebugLog.write("minimize failed: accessibility not trusted")
            return nil
        }

        guard let target = resolver.frontmostTarget() else {
            DebugLog.write("minimize failed: no frontmost displayed window")
            return nil
        }

        guard let window = resolver.accessibilityWindow(for: target)
            ?? resolver.focusedWindow(for: target.pid)
            ?? resolver.mainWindow(for: target.pid) else {
            DebugLog.write("minimize failed: no matching/focused/main window app=\(target.appName) title=\(target.displayTitle)")
            return nil
        }

        Accessibility.setBool(window, kAXMinimizedAttribute as CFString, value: true)

        if confirmMinimized(window, target: target) {
            DebugLog.write("minimized displayed window app=\(target.appName) title=\(target.displayTitle)")
            return target
        }

        DebugLog.write("minimize requested but not confirmed app=\(target.appName) title=\(target.displayTitle)")
        return nil
    }

    private func confirmMinimized(_ axWindow: AXUIElement, target: DisplayedWindowTarget) -> Bool {
        for _ in 0..<6 {
            if Accessibility.boolAttribute(axWindow, kAXMinimizedAttribute as CFString) == true {
                return true
            }

            if !resolver.isWindowStillOnScreen(target) {
                return true
            }

            Thread.sleep(forTimeInterval: 0.02)
        }

        return false
    }
}
