import ApplicationServices
import CoreGraphics

enum Accessibility {
    static func isTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        }
        return AXIsProcessTrusted()
    }

    static func applicationElement(pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    static func windows(for pid: pid_t) -> [AXUIElement] {
        let app = applicationElement(pid: pid)
        AXUIElementSetMessagingTimeout(app, 0.08)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else {
            return []
        }
        return windows
    }

    static func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }
        return value as? String
    }

    static func boolAttribute(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }
        return value as? Bool
    }

    static func rectAttribute(_ element: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(element, kAXPositionAttribute as CFString),
              let size = sizeAttribute(element, kAXSizeAttribute as CFString) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    static func setPoint(_ element: AXUIElement, _ attribute: CFString, value: CGPoint) {
        var point = value
        guard let axValue = AXValueCreate(.cgPoint, &point) else {
            return
        }
        AXUIElementSetAttributeValue(element, attribute, axValue)
    }

    static func setSize(_ element: AXUIElement, _ attribute: CFString, value: CGSize) {
        var size = value
        guard let axValue = AXValueCreate(.cgSize, &size) else {
            return
        }
        AXUIElementSetAttributeValue(element, attribute, axValue)
    }

    static func setBool(_ element: AXUIElement, _ attribute: CFString, value: Bool) {
        let boolValue: CFBoolean = (value ? kCFBooleanTrue : kCFBooleanFalse)!
        AXUIElementSetAttributeValue(element, attribute, boolValue)
    }

    static func setElement(_ element: AXUIElement, _ attribute: CFString, value: AXUIElement) {
        AXUIElementSetAttributeValue(element, attribute, value)
    }

    static func raise(_ element: AXUIElement) {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    private static func pointAttribute(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success,
              let rawValue = value,
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = rawValue as! AXValue
        guard AXValueGetType(axValue) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private static func sizeAttribute(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success,
              let rawValue = value,
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = rawValue as! AXValue
        guard AXValueGetType(axValue) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            return nil
        }
        return size
    }
}
