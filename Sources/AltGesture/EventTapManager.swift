import CoreGraphics
import Foundation

final class EventTapManager {
    var onTab: ((Bool) -> Void)?
    var onTriggerReleased: (() -> Void)?
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?
    var isSwitcherVisible: () -> Bool = { false }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var triggerWasDown = false

    var isRunning: Bool {
        eventTap != nil
    }

    func start() -> Bool {
        stop()

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        triggerWasDown = false
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let triggerDown = flags.contains(.maskAlternate)

        if type == .flagsChanged {
            if triggerWasDown && !triggerDown {
                triggerWasDown = false
                DispatchQueue.main.async { [weak self] in
                    self?.onTriggerReleased?()
                }
            } else {
                triggerWasDown = triggerDown
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            triggerWasDown = triggerDown
            return Unmanaged.passUnretained(event)
        }

        triggerWasDown = triggerDown
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let reverse = flags.contains(.maskShift)

        if keyCode == KeyCode.tab && triggerDown {
            DispatchQueue.main.async { [weak self] in
                self?.onTab?(reverse)
            }
            return nil
        }

        if isSwitcherVisible() {
            switch keyCode {
            case KeyCode.escape:
                DispatchQueue.main.async { [weak self] in
                    self?.onCancel?()
                }
                return nil
            case KeyCode.returnKey, KeyCode.space:
                DispatchQueue.main.async { [weak self] in
                    self?.onConfirm?()
                }
                return nil
            case KeyCode.leftArrow, KeyCode.upArrow:
                DispatchQueue.main.async { [weak self] in
                    self?.onTab?(true)
                }
                return nil
            case KeyCode.rightArrow, KeyCode.downArrow:
                DispatchQueue.main.async { [weak self] in
                    self?.onTab?(false)
                }
                return nil
            default:
                break
            }
        }

        return Unmanaged.passUnretained(event)
    }
}

private enum KeyCode {
    static let tab: Int64 = 48
    static let escape: Int64 = 53
    static let returnKey: Int64 = 36
    static let space: Int64 = 49
    static let leftArrow: Int64 = 123
    static let rightArrow: Int64 = 124
    static let downArrow: Int64 = 125
    static let upArrow: Int64 = 126
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handle(type: type, event: event)
}
