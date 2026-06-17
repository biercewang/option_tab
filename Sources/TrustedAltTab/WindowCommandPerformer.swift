import ApplicationServices
import AppKit
import Carbon
import CoreGraphics
import Foundation

enum WindowCommand {
    case close
    case quit

    var logName: String {
        switch self {
        case .close:
            return "close"
        case .quit:
            return "quit"
        }
    }

    var keyCode: CGKeyCode {
        switch self {
        case .close:
            return CGKeyCode(kVK_ANSI_W)
        case .quit:
            return CGKeyCode(kVK_ANSI_Q)
        }
    }

    var menuCommandCharacter: String {
        switch self {
        case .close:
            return "W"
        case .quit:
            return "Q"
        }
    }
}

final class WindowCommandPerformer {
    private let resolver = DisplayedWindowResolver()

    func perform(_ command: WindowCommand) -> Bool {
        guard let target = resolver.frontmostTarget() else {
            DebugLog.write("command failed: no frontmost displayed window command=\(command.logName)")
            return false
        }

        guard let app = NSRunningApplication(processIdentifier: target.pid),
              app.activationPolicy != .prohibited else {
            DebugLog.write("command failed: no target app command=\(command.logName) pid=\(target.pid)")
            return false
        }

        focus(target, app: app)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self, weak app] in
            guard let self, let app else {
                return
            }

            if self.performMenuCommand(command, pid: target.pid) {
                DebugLog.write("performed menu command app=\(target.appName) title=\(target.displayTitle) command=\(command.logName)")
                return
            }

            if command == .quit, app.terminate() {
                DebugLog.write("requested app terminate app=\(target.appName) title=\(target.displayTitle)")
                return
            }

            self.postCommandKey(command.keyCode)
            DebugLog.write("posted fallback command key app=\(target.appName) title=\(target.displayTitle) command=\(command.logName)")
        }

        return true
    }

    private func focus(_ target: DisplayedWindowTarget, app: NSRunningApplication) {
        app.activate(options: [.activateIgnoringOtherApps])

        guard Accessibility.isTrusted(),
              let window = resolver.accessibilityWindow(for: target)
                ?? resolver.focusedWindow(for: target.pid)
                ?? resolver.mainWindow(for: target.pid) else {
            return
        }

        let axApp = Accessibility.applicationElement(pid: target.pid)
        Accessibility.setElement(axApp, kAXFocusedWindowAttribute as CFString, value: window)
        Accessibility.setElement(axApp, kAXMainWindowAttribute as CFString, value: window)
        Accessibility.raise(window)
    }

    private func performMenuCommand(_ command: WindowCommand, pid: pid_t) -> Bool {
        guard Accessibility.isTrusted() else {
            return false
        }

        let axApp = Accessibility.applicationElement(pid: pid)
        AXUIElementSetMessagingTimeout(axApp, 0.15)

        guard let menuBar = elementAttribute(axApp, kAXMenuBarAttribute as CFString),
              let item = findMenuItem(
                in: menuBar,
                commandCharacter: command.menuCommandCharacter,
                depth: 0
              ) else {
            return false
        }

        let result = AXUIElementPerformAction(item, kAXPressAction as CFString)
        return result == .success
    }

    private func findMenuItem(
        in element: AXUIElement,
        commandCharacter: String,
        depth: Int
    ) -> AXUIElement? {
        guard depth < 8 else {
            return nil
        }

        if isMatchingCommandItem(element, commandCharacter: commandCharacter) {
            return element
        }

        for child in children(of: element) {
            if let match = findMenuItem(in: child, commandCharacter: commandCharacter, depth: depth + 1) {
                return match
            }
        }

        return nil
    }

    private func isMatchingCommandItem(_ element: AXUIElement, commandCharacter: String) -> Bool {
        let char = Accessibility.stringAttribute(element, kAXMenuItemCmdCharAttribute as CFString) ?? ""
        guard char.caseInsensitiveCompare(commandCharacter) == .orderedSame else {
            return false
        }

        let modifiers = numberAttribute(element, kAXMenuItemCmdModifiersAttribute as CFString) ?? 0
        guard modifiers == 0 else {
            return false
        }

        if let enabled = Accessibility.boolAttribute(element, kAXEnabledAttribute as CFString), !enabled {
            return false
        }

        return true
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard result == .success, let children = value as? [AXUIElement] else {
            return []
        }
        return children
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func numberAttribute(_ element: AXUIElement, _ attribute: CFString) -> Int? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        return nil
    }

    private func postCommandKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }
}
