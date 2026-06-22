import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Foundation

final class RightGestureController {
    private let settings: AppSettings
    private let configStore = RightGestureConfigStore()
    private var config: RightGestureConfig
    private let privacyShield: PrivacyShieldController
    private let engine: RightGestureEngine

    var configURL: URL {
        configStore.url
    }

    var state: RightGestureEngine.State {
        engine.state
    }

    init(settings: AppSettings = .shared) {
        self.settings = settings
        let loadedConfig = configStore.load()
        let shield = PrivacyShieldController()
        config = loadedConfig
        privacyShield = shield
        engine = RightGestureEngine(config: loadedConfig)
        engine.onTripleContextClick = { shield.toggle() }
        engine.shouldReplayContextClick = { !shield.isVisible }
    }

    func startIfEnabled() {
        guard settings.rightGestureEnabled else {
            engine.stop()
            return
        }

        requestPermissionsIfNeeded()
        restart()
    }

    func restart() {
        guard settings.rightGestureEnabled else {
            engine.stop()
            return
        }

        engine.stop()
        let didStart = engine.start()
        DebugLog.write("right gesture listener start result=\(didStart)")
    }

    func reloadConfigAndRestart() {
        config = configStore.load()
        engine.updateConfig(config)
        restart()
    }

    func stop() {
        engine.stop()
        privacyShield.hide()
    }

    func requestPermissionsIfNeeded() {
        _ = Accessibility.isTrusted(prompt: true)
        InputMonitoringPermission.requestIfNeeded()
    }
}

final class RightGestureShortcutSender {
    private let source = CGEventSource(stateID: .hidSystemState)
    private let windowSnapper = WindowSnapper()

    func send(_ action: RightGestureShortcutAction) {
        if let windowAction = action.windowAction, sendWindowAction(windowAction) {
            return
        }

        for stroke in action.keys {
            if action.delivery == "systemEvents" {
                sendViaSystemEvents(stroke)
                usleep(20_000)
                continue
            }

            let flags = eventFlags(for: stroke.modifiers)
            let modifierKeyCodes = keyCodes(forModifiers: stroke.modifiers)

            for keyCode in modifierKeyCodes {
                postKey(CGKeyCode(keyCode), keyDown: true, flags: flags)
                usleep(8_000)
            }

            usleep(12_000)
            postKey(CGKeyCode(stroke.keyCode), keyDown: true, flags: flags)
            usleep(20_000)
            postKey(CGKeyCode(stroke.keyCode), keyDown: false, flags: flags)
            usleep(12_000)

            for keyCode in modifierKeyCodes.reversed() {
                postKey(CGKeyCode(keyCode), keyDown: false, flags: [])
                usleep(8_000)
            }

            usleep(20_000)
        }
    }

    private func sendWindowAction(_ name: String) -> Bool {
        guard let direction = WindowSnapDirection(rightGestureActionName: name) else {
            DebugLog.write("right gesture unknown window action: \(name)")
            return false
        }

        let ok = windowSnapper.snapFrontmostWindow(to: direction)
        if !ok {
            NSSound.beep()
        }
        return true
    }

    private func postKey(_ keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else {
            return
        }

        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private func sendViaSystemEvents(_ stroke: RightGestureShortcutAction.KeyStroke) {
        let modifiers = stroke.modifiers.compactMap { modifier in
            appleScriptModifierName(for: modifier).map { "\($0) down" }
        }
        let usingClause = modifiers.isEmpty ? "" : " using {\(modifiers.joined(separator: ", "))}"
        let source = "tell application \"System Events\" to key code \(stroke.keyCode)\(usingClause)"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            DebugLog.write("right gesture System Events shortcut failed: \(error)")
        }
    }

    private func appleScriptModifierName(for name: String) -> String? {
        switch name.lowercased() {
        case "command", "cmd", "meta":
            return "command"
        case "shift":
            return "shift"
        case "option", "alt":
            return "option"
        case "control", "ctrl":
            return "control"
        default:
            return nil
        }
    }

    private func keyCodes(forModifiers names: [String]) -> [Int] {
        names.compactMap { name in
            switch name.lowercased() {
            case "command", "cmd", "meta":
                return kVK_Command
            case "shift":
                return kVK_Shift
            case "option", "alt":
                return kVK_Option
            case "control", "ctrl":
                return kVK_Control
            default:
                return nil
            }
        }
    }

    private func eventFlags(for names: [String]) -> CGEventFlags {
        var flags = CGEventFlags()
        for name in names {
            switch name.lowercased() {
            case "command", "cmd", "meta":
                flags.insert(.maskCommand)
            case "shift":
                flags.insert(.maskShift)
            case "option", "alt":
                flags.insert(.maskAlternate)
            case "control", "ctrl":
                flags.insert(.maskControl)
            default:
                break
            }
        }
        return flags
    }
}

final class RightGestureEngine {
    enum State {
        case stopped
        case running
        case permissionDenied
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var rightButtonDown = false
    private var performedMouseChord = false
    private var startPoint = CGPoint.zero
    private var lastPoint = CGPoint.zero
    private var rawPoints: [CGPoint] = []
    private var directions: [RightGestureDirection] = []
    private let minSegmentDistance: CGFloat = 36
    private let maxContextClickDistance: CGFloat = 12
    private let replayEventMarker: Int64 = 0xA176_357
    private let replaySource = CGEventSource(stateID: .hidSystemState)
    private let sender = RightGestureShortcutSender()
    private var config: RightGestureConfig
    var onTripleContextClick: (() -> Void)?
    var shouldReplayContextClick: (() -> Bool)?
    private var contextClickTimes: [TimeInterval] = []
    private var pendingContextClick: DispatchWorkItem?
    private var replayPassthroughUntil = Date.distantPast
    private var replayPassthroughPoint = CGPoint.zero
    private let contextClickReplayDelay: TimeInterval = 0.42
    private let tripleContextClickWindow: TimeInterval = 0.62
    private let replayPassthroughDistance: CGFloat = 4
    private(set) var state: State = .stopped

    init(config: RightGestureConfig) {
        self.config = config
    }

    func updateConfig(_ config: RightGestureConfig) {
        self.config = config
    }

    @discardableResult
    func start() -> Bool {
        state = .stopped
        let mask =
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }

            let engine = Unmanaged<RightGestureEngine>.fromOpaque(refcon).takeUnretainedValue()
            return engine.handle(proxy: proxy, type: type, event: event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            state = .permissionDenied
            DebugLog.write("right gesture event tap creation failed")
            showPermissionAlert()
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        state = .running
        DebugLog.write("right gesture event tap started")
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        cancelPendingContextClick()
        contextClickTimes.removeAll()
        state = .stopped
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == replayEventMarker ||
            isReplayPassthroughEvent(type: type, event: event) {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .rightMouseDown:
            rightButtonDown = true
            performedMouseChord = false
            startPoint = event.location
            lastPoint = startPoint
            rawPoints = [startPoint]
            directions.removeAll(keepingCapacity: true)
            return nil

        case .rightMouseDragged:
            guard rightButtonDown else {
                return Unmanaged.passUnretained(event)
            }
            rawPoints.append(event.location)
            appendDirection(from: lastPoint, to: event.location)
            return nil

        case .rightMouseUp:
            guard rightButtonDown else {
                return Unmanaged.passUnretained(event)
            }
            rightButtonDown = false
            defer {
                rawPoints.removeAll(keepingCapacity: true)
                directions.removeAll(keepingCapacity: true)
            }
            if performedMouseChord {
                return nil
            }
            if let action = matchTemplate() {
                cancelContextClickSequence()
                DebugLog.write("right gesture matched template: \(action.name)")
                sender.send(action)
                return nil
            }
            let code = directions.map(\.rawValue).joined()
            if let action = config.gestures[code] {
                cancelContextClickSequence()
                DebugLog.write("right gesture matched \(code): \(action.name)")
                sender.send(action)
                return nil
            }
            if isContextClickCandidate() {
                registerContextClick(at: event.location, timestamp: Date().timeIntervalSinceReferenceDate)
            }
            return nil

        case .leftMouseDown:
            guard rightButtonDown else {
                return Unmanaged.passUnretained(event)
            }
            performMouseChord("R+Left")
            return nil

        case .otherMouseDown:
            guard rightButtonDown else {
                return Unmanaged.passUnretained(event)
            }
            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            performMouseChord(chordName(for: buttonNumber))
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func appendDirection(from oldPoint: CGPoint, to newPoint: CGPoint) {
        let dx = newPoint.x - oldPoint.x
        let dy = newPoint.y - oldPoint.y
        guard hypot(dx, dy) >= minSegmentDistance else {
            return
        }

        let direction: RightGestureDirection
        if abs(dx) > abs(dy) {
            direction = dx > 0 ? .right : .left
        } else {
            direction = dy > 0 ? .down : .up
        }

        if directions.last != direction {
            directions.append(direction)
        }
        lastPoint = newPoint
    }

    private func performMouseChord(_ name: String) {
        performedMouseChord = true
        cancelContextClickSequence()
        rawPoints.removeAll(keepingCapacity: true)
        directions.removeAll(keepingCapacity: true)
        if let action = config.mouseButtons[name] {
            DebugLog.write("right gesture matched mouse chord \(name): \(action.name)")
            sender.send(action)
        }
    }

    private func matchTemplate() -> RightGestureShortcutAction? {
        guard let templates = config.templates,
              !templates.isEmpty,
              rawPoints.count >= 2,
              maxDistanceFromStart() >= minSegmentDistance else {
            return nil
        }

        let input = normalize(rawPoints)
        var bestAction: RightGestureShortcutAction?
        var bestScore = CGFloat.greatestFiniteMagnitude

        for template in templates {
            let points = points(from: template.points)
            guard points.count >= 2 else {
                continue
            }
            let score = pathDistance(input, normalize(points))
            if score < bestScore {
                bestScore = score
                bestAction = template.action
            }
        }

        return bestScore <= 0.28 ? bestAction : nil
    }

    private func points(from values: [Double]) -> [CGPoint] {
        stride(from: 0, to: values.count - 1, by: 2).map {
            CGPoint(x: values[$0], y: values[$0 + 1])
        }
    }

    private func normalize(_ points: [CGPoint], targetCount: Int = 32) -> [CGPoint] {
        let sampled = resample(points, targetCount: targetCount)
        let minX = sampled.map(\.x).min() ?? 0
        let maxX = sampled.map(\.x).max() ?? 1
        let minY = sampled.map(\.y).min() ?? 0
        let maxY = sampled.map(\.y).max() ?? 1
        let width = max(maxX - minX, 1)
        let height = max(maxY - minY, 1)
        let scale = max(width, height)
        let centered = sampled.map { CGPoint(x: ($0.x - minX) / scale, y: ($0.y - minY) / scale) }
        let centroid = centered.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let count = CGFloat(centered.count)
        return centered.map { CGPoint(x: $0.x - centroid.x / count, y: $0.y - centroid.y / count) }
    }

    private func resample(_ points: [CGPoint], targetCount: Int) -> [CGPoint] {
        guard points.count > 1 else {
            return points
        }
        let total = pathLength(points)
        guard total > 0 else {
            return Array(repeating: points[0], count: targetCount)
        }
        let interval = total / CGFloat(targetCount - 1)
        var result = [points[0]]
        var previous = points[0]
        var distanceRemainder: CGFloat = 0
        var index = 1

        while index < points.count {
            let current = points[index]
            let segment = hypot(current.x - previous.x, current.y - previous.y)
            if distanceRemainder + segment >= interval {
                let ratio = (interval - distanceRemainder) / segment
                let interpolated = CGPoint(
                    x: previous.x + ratio * (current.x - previous.x),
                    y: previous.y + ratio * (current.y - previous.y)
                )
                result.append(interpolated)
                previous = interpolated
                distanceRemainder = 0
            } else {
                distanceRemainder += segment
                previous = current
                index += 1
            }
        }

        while result.count < targetCount {
            result.append(points.last!)
        }
        return result
    }

    private func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else {
            return 0
        }
        return zip(points, points.dropFirst()).reduce(CGFloat(0)) { total, pair in
            total + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
    }

    private func pathDistance(_ lhs: [CGPoint], _ rhs: [CGPoint]) -> CGFloat {
        guard lhs.count == rhs.count else {
            return .greatestFiniteMagnitude
        }
        let total = zip(lhs, rhs).reduce(CGFloat(0)) { sum, pair in
            sum + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
        return total / CGFloat(lhs.count)
    }

    private func isContextClickCandidate() -> Bool {
        directions.isEmpty && maxDistanceFromStart() <= maxContextClickDistance
    }

    private func registerContextClick(at point: CGPoint, timestamp: TimeInterval) {
        contextClickTimes = contextClickTimes.filter {
            timestamp - $0 <= tripleContextClickWindow
        }
        contextClickTimes.append(timestamp)

        if contextClickTimes.count >= 3 {
            cancelPendingContextClick()
            contextClickTimes.removeAll()
            DebugLog.write("right gesture triple context click toggled privacy shield")
            DispatchQueue.main.async { [weak self] in
                self?.onTripleContextClick?()
            }
            return
        }

        scheduleContextClickReplay(at: point)
    }

    private func scheduleContextClickReplay(at point: CGPoint) {
        cancelPendingContextClick()
        guard shouldReplayContextClick?() ?? true else {
            return
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            self.pendingContextClick = nil
            self.contextClickTimes.removeAll()
            guard self.shouldReplayContextClick?() ?? true else {
                return
            }
            self.replayContextClick(at: point)
        }
        pendingContextClick = item
        DispatchQueue.main.asyncAfter(deadline: .now() + contextClickReplayDelay, execute: item)
    }

    private func cancelContextClickSequence() {
        cancelPendingContextClick()
        contextClickTimes.removeAll()
    }

    private func cancelPendingContextClick() {
        pendingContextClick?.cancel()
        pendingContextClick = nil
    }

    private func maxDistanceFromStart() -> CGFloat {
        rawPoints.reduce(CGFloat(0)) { distance, point in
            max(distance, hypot(point.x - startPoint.x, point.y - startPoint.y))
        }
    }

    private func replayContextClick(at point: CGPoint) {
        replayPassthroughPoint = point
        replayPassthroughUntil = Date().addingTimeInterval(1.0)
        postReplayMouseEvent(type: .rightMouseDown, at: point)
        usleep(12_000)
        postReplayMouseEvent(type: .rightMouseUp, at: point)
        DebugLog.write("right gesture replayed context click")
    }

    private func isReplayPassthroughEvent(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .rightMouseDown || type == .rightMouseUp,
              Date() <= replayPassthroughUntil else {
            return false
        }

        return hypot(
            event.location.x - replayPassthroughPoint.x,
            event.location.y - replayPassthroughPoint.y
        ) <= replayPassthroughDistance
    }

    private func postReplayMouseEvent(type: CGEventType, at point: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: replaySource,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .right
        ) else {
            return
        }

        event.setIntegerValueField(.eventSourceUserData, value: replayEventMarker)
        event.post(tap: .cghidEventTap)
    }

    private func chordName(for buttonNumber: Int64) -> String {
        switch buttonNumber {
        case 2:
            return "R+Middle"
        case 3:
            return "R+Mouse4"
        case 4:
            return "R+Mouse5"
        default:
            return "R+Mouse\(buttonNumber + 1)"
        }
    }

    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "AltGesture 需要右键手势权限"
            alert.informativeText = "请在“系统设置 -> 隐私与安全性”里允许辅助功能和输入监控，然后重新打开 app 或在菜单栏里重启右键手势。"
            alert.addButton(withTitle: "打开辅助功能")
            alert.addButton(withTitle: "打开输入监控")
            alert.addButton(withTitle: "稍后")

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                SettingsOpener.openAccessibility()
            case .alertSecondButtonReturn:
                SettingsOpener.openInputMonitoring()
            default:
                break
            }
        }
    }
}
