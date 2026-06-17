import AppKit

final class WindowFocuser {
    func focus(_ window: WindowInfo) {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else {
            return
        }

        app.unhide()

        let hasAccessibility = Accessibility.isTrusted()
        if hasAccessibility, let axWindow = bestAccessibilityMatch(for: window) {
            if Accessibility.boolAttribute(axWindow, kAXMinimizedAttribute as CFString) == true {
                Accessibility.setBool(axWindow, kAXMinimizedAttribute as CFString, value: false)
            }

            app.activate(options: [.activateIgnoringOtherApps])

            let axApp = Accessibility.applicationElement(pid: window.pid)
            Accessibility.setElement(axApp, kAXFocusedWindowAttribute as CFString, value: axWindow)
            Accessibility.setElement(axApp, kAXMainWindowAttribute as CFString, value: axWindow)
            Accessibility.raise(axWindow)
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
            if !hasAccessibility {
                _ = Accessibility.isTrusted(prompt: true)
            }
        }
    }

    private func bestAccessibilityMatch(for target: WindowInfo) -> AXUIElement? {
        let windows = Accessibility.windows(for: target.pid)
        guard !windows.isEmpty else {
            return nil
        }

        let scored = windows.map { window in
            (window: window, score: score(window, against: target))
        }

        return scored.max { lhs, rhs in
            lhs.score < rhs.score
        }?.window
    }

    private func score(_ window: AXUIElement, against target: WindowInfo) -> Int {
        var score = 0

        let title = Accessibility.stringAttribute(window, kAXTitleAttribute as CFString) ?? ""
        if !target.title.isEmpty && title == target.title {
            score += 80
        } else if !target.title.isEmpty && title.localizedCaseInsensitiveContains(target.title) {
            score += 30
        }

        if let bounds = Accessibility.rectAttribute(window), isClose(bounds, to: target.bounds) {
            score += 70
        }

        if Accessibility.boolAttribute(window, kAXMinimizedAttribute as CFString) == target.isMinimized {
            score += 10
        }

        if score == 0, target.title.isEmpty {
            score = 1
        }

        return score
    }

    private func isClose(_ lhs: CGRect, to rhs: CGRect) -> Bool {
        guard rhs != .zero else {
            return false
        }

        let tolerance: CGFloat = 24
        return abs(lhs.origin.x - rhs.origin.x) <= tolerance
            && abs(lhs.origin.y - rhs.origin.y) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
