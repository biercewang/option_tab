import AppKit
import CoreGraphics

final class PrivacyShieldController {
    private var panels: [NSPanel] = []
    private var appKitCursorHidden = false
    private var displayCursorHidden = false
    private var mouseCursorDetached = false
    private var cursorKeepAliveTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    var isVisible: Bool {
        !panels.isEmpty
    }

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isVisible else {
                return
            }

            self.show()
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        hide()
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        hide()

        panels = NSScreen.screens.map { screen in
            let panel = PrivacyShieldPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = .black
            panel.contentView = PrivacyShieldView(frame: NSRect(origin: .zero, size: screen.frame.size))
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.backgroundColor = NSColor.black.cgColor
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            panel.isMovable = false
            panel.isOpaque = true
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .ignoresCycle,
                .stationary
            ]
            panel.orderFrontRegardless()
            if let contentView = panel.contentView {
                panel.invalidateCursorRects(for: contentView)
            }
            return panel
        }

        hideCursor()

        DebugLog.write("privacy shield shown screens=\(panels.count) cursorHidden=\(displayCursorHidden) cursorDetached=\(mouseCursorDetached)")
    }

    func hide() {
        guard !panels.isEmpty || appKitCursorHidden || displayCursorHidden else {
            return
        }

        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()

        showCursor()

        DebugLog.write("privacy shield hidden")
    }

    private func hideCursor() {
        PrivacyShieldView.enforceInvisibleCursor()

        if !mouseCursorDetached {
            let error = CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
            mouseCursorDetached = error == .success
            if error != .success {
                DebugLog.write("privacy shield mouse cursor detach failed error=\(error.rawValue)")
            }
        }

        if !appKitCursorHidden {
            NSCursor.hide()
            appKitCursorHidden = true
        }

        if !displayCursorHidden {
            let error = CGDisplayHideCursor(CGMainDisplayID())
            displayCursorHidden = error == .success
            if error != .success {
                DebugLog.write("privacy shield display cursor hide failed error=\(error.rawValue)")
            }
        }

        startCursorKeepAlive()
    }

    private func showCursor() {
        stopCursorKeepAlive()

        if mouseCursorDetached {
            let error = CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
            if error != .success {
                DebugLog.write("privacy shield mouse cursor reconnect failed error=\(error.rawValue)")
            }
            mouseCursorDetached = false
        }

        if displayCursorHidden {
            let error = CGDisplayShowCursor(CGMainDisplayID())
            if error != .success {
                DebugLog.write("privacy shield display cursor show failed error=\(error.rawValue)")
            }
            displayCursorHidden = false
        }

        if appKitCursorHidden {
            NSCursor.unhide()
            appKitCursorHidden = false
        }
    }

    private func startCursorKeepAlive() {
        cursorKeepAliveTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { _ in
            PrivacyShieldView.enforceInvisibleCursor()
        }
        cursorKeepAliveTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopCursorKeepAlive() {
        cursorKeepAliveTimer?.invalidate()
        cursorKeepAliveTimer = nil
    }
}

private final class PrivacyShieldPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class PrivacyShieldView: NSView {
    fileprivate static let invisibleCursor = NSCursor(
        image: NSImage(size: NSSize(width: 1, height: 1)),
        hotSpot: .zero
    )

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let newTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .cursorUpdate, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self
        )
        trackingArea = newTrackingArea
        addTrackingArea(newTrackingArea)

        super.updateTrackingAreas()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: Self.invisibleCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        Self.enforceInvisibleCursor()
    }

    override func mouseEntered(with event: NSEvent) {
        Self.enforceInvisibleCursor()
    }

    override func mouseMoved(with event: NSEvent) {
        Self.enforceInvisibleCursor()
    }

    override func rightMouseDragged(with event: NSEvent) {
        Self.enforceInvisibleCursor()
    }

    fileprivate static func enforceInvisibleCursor() {
        invisibleCursor.set()
    }
}
