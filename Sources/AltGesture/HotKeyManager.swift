import Carbon
import Foundation

final class HotKeyManager {
    var onTab: ((Bool, Bool) -> Void)?
    var onSnap: ((WindowSnapDirection) -> Void)?
    var onCommand: ((WindowCommand) -> Void)?

    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef?] = []

    var isRunning: Bool {
        !hotKeys.isEmpty
    }

    func start(commandKeysEnabled: Bool = false) -> Bool {
        stop()
        DebugLog.write("starting Carbon hotkeys commandKeysEnabled=\(commandKeysEnabled)")

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventHandler,
            eventTypes.count,
            &eventTypes,
            refcon,
            &eventHandler
        )

        guard handlerStatus == noErr else {
            DebugLog.write("InstallEventHandler failed status=\(handlerStatus)")
            return false
        }

        guard registerHotKey(keyCode: UInt32(kVK_Tab), id: HotKeyID.forward, modifiers: UInt32(optionKey)),
              registerHotKey(keyCode: UInt32(kVK_Tab), id: HotKeyID.reverse, modifiers: UInt32(optionKey | shiftKey)),
              registerHotKey(keyCode: UInt32(kVK_LeftArrow), id: HotKeyID.snapLeft, modifiers: UInt32(optionKey)),
              registerHotKey(keyCode: UInt32(kVK_RightArrow), id: HotKeyID.snapRight, modifiers: UInt32(optionKey)),
              registerHotKey(keyCode: UInt32(kVK_ANSI_Grave), id: HotKeyID.reverseAlias, modifiers: UInt32(optionKey)),
              registerHotKey(keyCode: UInt32(kVK_ANSI_1), id: HotKeyID.snapLeftAlias, modifiers: UInt32(optionKey)),
              registerHotKey(keyCode: UInt32(kVK_ANSI_2), id: HotKeyID.snapRightAlias, modifiers: UInt32(optionKey)),
              registerHotKey(keyCode: UInt32(kVK_ANSI_3), id: HotKeyID.snapToggleFill, modifiers: UInt32(optionKey)),
              registerHotKey(keyCode: UInt32(kVK_UpArrow), id: HotKeyID.snapFill, modifiers: UInt32(optionKey)),
              registerHotKey(keyCode: UInt32(kVK_DownArrow), id: HotKeyID.snapRestore, modifiers: UInt32(optionKey)) else {
            DebugLog.write("RegisterEventHotKey failed")
            stop()
            return false
        }

        if commandKeysEnabled {
            guard registerHotKey(keyCode: UInt32(kVK_ANSI_Z), id: HotKeyID.undo, modifiers: UInt32(optionKey)),
                  registerHotKey(keyCode: UInt32(kVK_ANSI_A), id: HotKeyID.selectAll, modifiers: UInt32(optionKey)),
                  registerHotKey(keyCode: UInt32(kVK_ANSI_S), id: HotKeyID.save, modifiers: UInt32(optionKey)),
                  registerHotKey(keyCode: UInt32(kVK_ANSI_X), id: HotKeyID.cut, modifiers: UInt32(optionKey)),
                  registerHotKey(keyCode: UInt32(kVK_ANSI_C), id: HotKeyID.copy, modifiers: UInt32(optionKey)),
                  registerHotKey(keyCode: UInt32(kVK_ANSI_V), id: HotKeyID.paste, modifiers: UInt32(optionKey)),
                  registerHotKey(keyCode: UInt32(kVK_ANSI_W), id: HotKeyID.closeWindow, modifiers: UInt32(optionKey)),
                  registerHotKey(keyCode: UInt32(kVK_ANSI_Q), id: HotKeyID.quitApp, modifiers: UInt32(optionKey)) else {
                DebugLog.write("RegisterEventHotKey command keys failed")
                stop()
                return false
            }
        }

        DebugLog.write("Carbon hotkeys started")
        return true
    }

    func stop() {
        for hotKey in hotKeys {
            if let hotKey {
                UnregisterEventHotKey(hotKey)
            }
        }
        hotKeys.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    fileprivate func handle(event: EventRef?) -> OSStatus {
        guard let event else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == HotKeyID.signature else {
            return OSStatus(eventNotHandledErr)
        }

        DispatchQueue.main.async { [weak self] in
            switch hotKeyID.id {
            case HotKeyID.forward, HotKeyID.reverse, HotKeyID.reverseAlias:
                let reverse = hotKeyID.id == HotKeyID.reverse || hotKeyID.id == HotKeyID.reverseAlias
                let prefersImmediateDismissal = hotKeyID.id == HotKeyID.reverseAlias
                DebugLog.write("hotkey pressed reverse=\(reverse)")
                self?.onTab?(reverse, prefersImmediateDismissal)
            case HotKeyID.snapLeft, HotKeyID.snapLeftAlias:
                DebugLog.write("hotkey snap left")
                self?.onSnap?(.left)
            case HotKeyID.snapRight, HotKeyID.snapRightAlias:
                DebugLog.write("hotkey snap right")
                self?.onSnap?(.right)
            case HotKeyID.snapFill:
                DebugLog.write("hotkey snap fill")
                self?.onSnap?(.fill)
            case HotKeyID.snapRestore:
                DebugLog.write("hotkey snap restore")
                self?.onSnap?(.restore)
            case HotKeyID.snapToggleFill:
                DebugLog.write("hotkey snap toggle fill")
                self?.onSnap?(.toggleFill)
            case HotKeyID.undo:
                DebugLog.write("hotkey command undo")
                self?.onCommand?(.undo)
            case HotKeyID.selectAll:
                DebugLog.write("hotkey command selectAll")
                self?.onCommand?(.selectAll)
            case HotKeyID.save:
                DebugLog.write("hotkey command save")
                self?.onCommand?(.save)
            case HotKeyID.cut:
                DebugLog.write("hotkey command cut")
                self?.onCommand?(.cut)
            case HotKeyID.copy:
                DebugLog.write("hotkey command copy")
                self?.onCommand?(.copy)
            case HotKeyID.paste:
                DebugLog.write("hotkey command paste")
                self?.onCommand?(.paste)
            case HotKeyID.closeWindow:
                DebugLog.write("hotkey command close")
                self?.onCommand?(.close)
            case HotKeyID.quitApp:
                DebugLog.write("hotkey command quit")
                self?.onCommand?(.quit)
            default:
                break
            }
        }

        return noErr
    }

    private func registerHotKey(keyCode: UInt32, id: UInt32, modifiers: UInt32) -> Bool {
        let hotKeyID = EventHotKeyID(signature: HotKeyID.signature, id: id)
        var hotKey: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKey
        )

        guard status == noErr, let hotKey else {
            DebugLog.write("RegisterEventHotKey keyCode=\(keyCode) id=\(id) modifiers=\(modifiers) status=\(status)")
            return false
        }

        hotKeys.append(hotKey)
        return true
    }
}

private enum HotKeyID {
    static let signature = OSType(
        UInt32(UInt8(ascii: "T")) << 24
            | UInt32(UInt8(ascii: "A")) << 16
            | UInt32(UInt8(ascii: "T")) << 8
            | UInt32(UInt8(ascii: "B"))
    )
    static let forward: UInt32 = 1
    static let reverse: UInt32 = 2
    static let snapLeft: UInt32 = 3
    static let snapRight: UInt32 = 4
    static let snapFill: UInt32 = 5
    static let snapRestore: UInt32 = 6
    static let closeWindow: UInt32 = 7
    static let quitApp: UInt32 = 8
    static let snapLeftAlias: UInt32 = 9
    static let snapRightAlias: UInt32 = 10
    static let snapToggleFill: UInt32 = 11
    static let reverseAlias: UInt32 = 12
    static let undo: UInt32 = 13
    static let selectAll: UInt32 = 14
    static let save: UInt32 = 15
    static let cut: UInt32 = 16
    static let copy: UInt32 = 17
    static let paste: UInt32 = 18
}

private let hotKeyEventHandler: EventHandlerUPP = { _, event, refcon in
    guard let refcon else {
        return OSStatus(eventNotHandledErr)
    }

    let manager = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handle(event: event)
}
