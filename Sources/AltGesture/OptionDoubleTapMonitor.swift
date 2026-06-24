import CoreGraphics
import Foundation

final class OptionDoubleTapMonitor {
    var onDoubleTap: (() -> Void)?
    var onOptionReleased: (() -> Void)?
    var isEnabled = true

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var optionIsDown = false
    private var optionWasCombined = false
    private var optionDownTime: TimeInterval?
    private var lastTapTime: TimeInterval?

    private let doubleTapInterval: TimeInterval = 0.34
    private let maxTapDuration: TimeInterval = 0.42

    func start() -> Bool {
        stop()

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: optionDoubleTapCallback,
            userInfo: refcon
        ) else {
            DebugLog.write("Option double-tap monitor failed to start")
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            DebugLog.write("Option double-tap monitor failed to create runloop source")
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        DebugLog.write("Option double-tap monitor started")
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
        resetState()
    }

    func cancelPendingTap() {
        optionWasCombined = true
        lastTapTime = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .keyDown:
            handleKeyDown(event)
        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard isOptionKey(keyCode) else {
            return
        }

        let optionDown = event.flags.contains(.maskAlternate)
        let now = event.timestampSeconds

        if optionDown && !optionIsDown {
            optionIsDown = true
            optionWasCombined = hasNonOptionModifier(event.flags)
            optionDownTime = now
            return
        }

        if !optionDown && optionIsDown {
            optionIsDown = false
            DispatchQueue.main.async { [weak self] in
                self?.onOptionReleased?()
            }

            guard isEnabled else {
                resetTap()
                return
            }

            guard let downTime = optionDownTime,
                  now - downTime <= maxTapDuration,
                  !optionWasCombined else {
                resetTap()
                return
            }

            if let lastTapTime, now - lastTapTime <= doubleTapInterval {
                resetTap()
                DebugLog.write("double Option detected")
                DispatchQueue.main.async { [weak self] in
                    self?.onDoubleTap?()
                }
            } else {
                lastTapTime = now
                optionDownTime = nil
                optionWasCombined = false
            }
        }
    }

    private func handleKeyDown(_ event: CGEvent) {
        guard optionIsDown, event.flags.contains(.maskAlternate) else {
            return
        }

        optionWasCombined = true
        lastTapTime = nil
    }

    private func hasNonOptionModifier(_ flags: CGEventFlags) -> Bool {
        let relevant: CGEventFlags = [.maskShift, .maskControl, .maskCommand]
        return !flags.intersection(relevant).isEmpty
    }

    private func resetTap() {
        optionDownTime = nil
        optionWasCombined = false
        lastTapTime = nil
    }

    private func resetState() {
        optionIsDown = false
        resetTap()
    }

    private func isOptionKey(_ keyCode: Int64) -> Bool {
        keyCode == 58 || keyCode == 61
    }
}

private extension CGEvent {
    var timestampSeconds: TimeInterval {
        TimeInterval(timestamp) / 1_000_000_000
    }
}

private let optionDoubleTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<OptionDoubleTapMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
