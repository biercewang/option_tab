import AppKit
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKeys = HotKeyManager()
    private let optionDoubleTap = OptionDoubleTapMonitor()
    private let windowProvider = WindowProvider()
    private let focuser = WindowFocuser()
    private let currentWindowMinimizer = CurrentWindowMinimizer()
    private let windowSnapper = WindowSnapper()
    private let windowCommandPerformer = WindowCommandPerformer()
    private let recentWindowTracker = RecentWindowTracker()
    private let loginItemManager = LoginItemManager()
    private let overlay = SwitcherOverlay()
    private let settings = AppSettings.shared
    private let accessibilityWindowQueue = DispatchQueue(label: "local.trusted-alt-tab.accessibility-windows", qos: .userInitiated)

    private var statusItem: NSStatusItem?
    private var currentWindows: [WindowInfo] = []
    private var optionReleaseTimer: Timer?
    private var accessibilityCacheTimer: Timer?
    private var recentWindowTimer: Timer?
    private var cachedAccessibilityWindows: [WindowInfo] = []
    private var lastMinimizedWindow: WindowInfo?
    private var preferImmediateOverlayDismissalOnConfirm = false
    private var isRefreshingAccessibilityCache = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLog.write("applicationDidFinishLaunching")
        settings.applySpeedDefaultsIfNeeded()
        buildStatusMenu()
        wireSwitcher()
        requestPermissions()
        startKeyboardCapture()
        startOptionDoubleTap()
        startAccessibilityCache()
        startRecentWindowTracking()
    }

    private func wireSwitcher() {
        hotKeys.onTab = { [weak self] reverse, prefersImmediateDismissal in
            self?.optionDoubleTap.cancelPendingTap()
            self?.handleOptionTab(reverse: reverse, prefersImmediateDismissal: prefersImmediateDismissal)
        }

        hotKeys.onSnap = { [weak self] direction in
            self?.optionDoubleTap.cancelPendingTap()
            self?.handleWindowSnap(direction: direction)
        }

        hotKeys.onCommand = { [weak self] command in
            self?.optionDoubleTap.cancelPendingTap()
            self?.handleWindowCommand(command)
        }

        overlay.onConfirm = { [weak self] window in
            self?.completeSelection(window)
        }
    }

    private func requestPermissions() {
        if settings.includeMinimizedWindows
            || settings.includeHiddenWindows
            || settings.minimizeOnDoubleOption
            || settings.optionCommandKeysEnabled {
            _ = Accessibility.isTrusted(prompt: true)
        }

        if settings.showThumbnails {
            ScreenCapturePermission.requestIfNeeded()
        }
    }

    private func startKeyboardCapture() {
        guard hotKeys.start(commandKeysEnabled: settings.optionCommandKeysEnabled) else {
            showHotKeyAlert()
            return
        }
        DebugLog.write("keyboard capture ready")
        updateStatusItemTitle()
    }

    private func startOptionDoubleTap() {
        optionDoubleTap.isEnabled = settings.minimizeOnDoubleOption
        optionDoubleTap.onDoubleTap = { [weak self] in
            self?.handleOptionDoubleTap()
        }
        optionDoubleTap.onOptionReleased = { [weak self] in
            guard let self, self.overlay.isVisible else {
                return
            }

            DebugLog.write("option released via event tap")
            self.confirmSelection()
        }
        if !optionDoubleTap.start(), settings.minimizeOnDoubleOption {
            _ = Accessibility.isTrusted(prompt: true)
        }
    }

    private func handleOptionDoubleTap() {
        guard settings.minimizeOnDoubleOption, !overlay.isVisible else {
            return
        }

        if let minimizedWindow = currentWindowMinimizer.minimizeFrontmostWindow() {
            let minimizedInfo = windowInfo(from: minimizedWindow)
            lastMinimizedWindow = minimizedInfo
            cacheRecentlyMinimizedWindow(minimizedInfo)
            recentWindowTracker.record(minimizedInfo)
            refreshAccessibilityCache()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.refreshAccessibilityCache()
            }
        } else if windowProvider.visibleWindowsOnly(log: false).isEmpty,
                  restoreRecentlyMinimizedWindow() {
            return
        } else {
            NSSound.beep()
        }
    }

    private func handleWindowSnap(direction: WindowSnapDirection) {
        if overlay.isVisible {
            overlay.cancel()
            stopOptionReleaseWatcher()
        }

        if !windowSnapper.snapFrontmostWindow(to: direction) {
            NSSound.beep()
        }
    }

    private func handleWindowCommand(_ command: WindowCommand) {
        if overlay.isVisible {
            overlay.cancel()
            stopOptionReleaseWatcher()
        }

        if !windowCommandPerformer.perform(command) {
            NSSound.beep()
        }
    }

    private func handleOptionTab(reverse: Bool, prefersImmediateDismissal: Bool = false) {
        DebugLog.write("handleOptionTab reverse=\(reverse) overlayVisible=\(overlay.isVisible)")
        preferImmediateOverlayDismissalOnConfirm = prefersImmediateDismissal

        if overlay.isVisible {
            overlay.cycle(reverse: reverse)
            return
        }

        let visibleWindows = windowProvider.visibleWindowsOnly()
        currentWindows = mergeWindows(visibleWindows: visibleWindows, cachedWindows: cachedAccessibilityWindows)
        if let lastMinimizedWindow, !currentWindows.contains(where: { isSameRestorableWindow($0, lastMinimizedWindow) }) {
            currentWindows.append(lastMinimizedWindow)
        }

        let frontmostWindow = windowProvider.frontmostVisibleWindow(from: visibleWindows)
        if let frontmostWindow {
            recentWindowTracker.record(frontmostWindow)
            DebugLog.write("frontmost window app=\(frontmostWindow.appName) title=\(frontmostWindow.displayTitle)")
        }
        currentWindows = recentWindowTracker.sort(currentWindows, frontmostWindow: frontmostWindow)
        DebugLog.write("window count=\(currentWindows.count)")
        guard !currentWindows.isEmpty else {
            refreshAccessibilityCache()
            NSSound.beep()
            return
        }

        let initialIndex: Int
        if reverse {
            initialIndex = max(currentWindows.count - 1, 0)
        } else if let lastMinimizedWindow,
                  let minimizedIndex = currentWindows.firstIndex(where: { isSameRestorableWindow($0, lastMinimizedWindow) }) {
            initialIndex = minimizedIndex
            DebugLog.write("initial selection recently minimized app=\(lastMinimizedWindow.appName) title=\(lastMinimizedWindow.displayTitle) index=\(minimizedIndex)")
        } else {
            initialIndex = currentWindows.count > 1 ? 1 : 0
        }
        overlay.show(windows: currentWindows, selectedIndex: initialIndex)
        startOptionReleaseWatcher()
    }

    private func confirmSelection() {
        guard overlay.isVisible, let window = overlay.confirm() else {
            return
        }
        completeSelection(window)
    }

    private func completeSelection(_ window: WindowInfo) {
        stopOptionReleaseWatcher()
        recentWindowTracker.record(window)
        lastMinimizedWindow = nil
        currentWindows.removeAll()

        let shouldDismissImmediately = preferImmediateOverlayDismissalOnConfirm
        preferImmediateOverlayDismissalOnConfirm = false

        let shouldDeferOverlayDismissal = shouldDeferOverlayDismissal(for: window) && !shouldDismissImmediately
        if !shouldDeferOverlayDismissal {
            overlay.cancel()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.focusSelectedWindow(window)

            if shouldDeferOverlayDismissal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
                    self?.overlay.cancel()
                }
            }
        }
    }

    private func focusSelectedWindow(_ window: WindowInfo) {
        focuser.focus(window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refreshAccessibilityCache()
        }
    }

    private func shouldDeferOverlayDismissal(for window: WindowInfo) -> Bool {
        window.isMinimized || window.isHidden || !window.isOnScreen
    }

    private func restoreRecentlyMinimizedWindow() -> Bool {
        guard Accessibility.isTrusted(prompt: true) else {
            DebugLog.write("restore minimized failed: accessibility not trusted")
            return false
        }

        let candidates = recentlyMinimizedRestoreCandidates()
        guard let window = recentWindowTracker.sort(candidates).first else {
            DebugLog.write("restore minimized failed: no minimized window candidate")
            refreshAccessibilityCache()
            return false
        }

        DebugLog.write("restoring recently minimized app=\(window.appName) title=\(window.displayTitle)")
        lastMinimizedWindow = nil
        recentWindowTracker.record(window)
        focusSelectedWindow(window)
        return true
    }

    private func startAccessibilityCache() {
        accessibilityCacheTimer?.invalidate()
        refreshAccessibilityCache()

        let timer = Timer(timeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.refreshAccessibilityCache()
        }

        accessibilityCacheTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startRecentWindowTracking() {
        recentWindowTimer?.invalidate()
        recordFrontmostWindow()

        let timer = Timer(timeInterval: 0.55, repeats: true) { [weak self] _ in
            self?.recordFrontmostWindow()
        }

        recentWindowTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func recordFrontmostWindow() {
        guard !overlay.isVisible else {
            return
        }

        let windows = windowProvider.visibleWindowsOnly(log: false)
        recentWindowTracker.seedIfNeeded(with: windows)

        if let frontmost = windowProvider.frontmostVisibleWindow(from: windows) ?? windows.first {
            recentWindowTracker.record(frontmost)
        }
    }

    private func refreshAccessibilityCache() {
        let includeMinimized = settings.includeMinimizedWindows
        let includeHidden = settings.includeHiddenWindows
        guard includeMinimized || includeHidden else {
            cachedAccessibilityWindows.removeAll()
            return
        }

        guard Accessibility.isTrusted() else {
            if !cachedAccessibilityWindows.isEmpty {
                cachedAccessibilityWindows.removeAll()
            }
            DebugLog.write("accessibility not trusted; minimized/hidden cache unavailable")
            return
        }

        guard !overlay.isVisible, !isRefreshingAccessibilityCache else {
            return
        }

        isRefreshingAccessibilityCache = true
        accessibilityWindowQueue.async { [weak self] in
            guard let self else {
                return
            }

            let visibleWindows = self.windowProvider.visibleWindowsOnly(log: false)
            let extraWindows = self.windowProvider.accessibilityOnlyWindows(
                excluding: visibleWindows,
                includeMinimized: includeMinimized,
                includeHidden: includeHidden
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                self.isRefreshingAccessibilityCache = false
                if self.cachedAccessibilityWindows != extraWindows {
                    DebugLog.write("cached accessibility windows=\(extraWindows.count) includeMinimized=\(includeMinimized) includeHidden=\(includeHidden)")
                }
                self.cachedAccessibilityWindows = extraWindows
            }
        }
    }

    private func mergeWindows(visibleWindows: [WindowInfo], cachedWindows: [WindowInfo]) -> [WindowInfo] {
        guard !cachedWindows.isEmpty else {
            return visibleWindows
        }

        var seenKeys = Set(visibleWindows.map { $0.identityKey })
        let extras = cachedWindows.filter { window in
            seenKeys.insert(window.identityKey).inserted
        }

        return visibleWindows + extras
    }

    private func recentlyMinimizedRestoreCandidates() -> [WindowInfo] {
        let visibleWindows = windowProvider.visibleWindowsOnly(log: false)
        let freshMinimizedWindows = windowProvider.accessibilityOnlyWindows(
            excluding: visibleWindows,
            includeMinimized: true,
            includeHidden: false
        )

        var candidates: [WindowInfo] = []

        if let lastMinimizedWindow {
            appendRestoreCandidate(lastMinimizedWindow, to: &candidates)
        }

        for window in cachedAccessibilityWindows where window.isMinimized {
            appendRestoreCandidate(window, to: &candidates)
        }

        for window in freshMinimizedWindows where window.isMinimized {
            appendRestoreCandidate(window, to: &candidates)
        }

        return candidates
    }

    private func appendRestoreCandidate(_ window: WindowInfo, to candidates: inout [WindowInfo]) {
        guard window.isMinimized || !window.isOnScreen else {
            return
        }

        guard !candidates.contains(where: { isSameRestorableWindow($0, window) }) else {
            return
        }

        candidates.append(window)
    }

    private func cacheRecentlyMinimizedWindow(_ window: WindowInfo) {
        cachedAccessibilityWindows.removeAll { cached in
            isSameRestorableWindow(cached, window)
        }
        cachedAccessibilityWindows.insert(window, at: 0)
    }

    private func windowInfo(from target: DisplayedWindowTarget) -> WindowInfo {
        let app = NSRunningApplication(processIdentifier: target.pid)
        return WindowInfo(
            id: target.id,
            pid: target.pid,
            appName: target.appName,
            title: target.title,
            bounds: target.bounds,
            icon: app?.icon,
            isOnScreen: false,
            isMinimized: true,
            isHidden: app?.isHidden ?? false,
            order: 0
        )
    }

    private func isSameRestorableWindow(_ lhs: WindowInfo, _ rhs: WindowInfo) -> Bool {
        if lhs.identityKey == rhs.identityKey {
            return true
        }

        let lhsTitle = lhs.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhsTitle = rhs.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return lhs.pid == rhs.pid
            && !lhsTitle.isEmpty
            && lhsTitle == rhsTitle
    }

    private func startOptionReleaseWatcher() {
        optionReleaseTimer?.invalidate()

        let timer = Timer(timeInterval: 0.01, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            guard self.overlay.isVisible else {
                timer.invalidate()
                self.optionReleaseTimer = nil
                return
            }

            let flags = CGEventSource.flagsState(.combinedSessionState)
            if !flags.contains(.maskAlternate) {
                timer.invalidate()
                self.optionReleaseTimer = nil
                self.confirmSelection()
            }
        }

        optionReleaseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopOptionReleaseWatcher() {
        optionReleaseTimer?.invalidate()
        optionReleaseTimer = nil
    }

    private func buildStatusMenu() {
        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Alt"
        item.button?.toolTip = "TrustedAltTab"
        statusItem = item

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "TrustedAltTab", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let enabledItem = NSMenuItem(title: "启用 Option-Tab", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = settings.enabled ? .on : .off
        menu.addItem(enabledItem)

        let thumbnailsItem = NSMenuItem(title: "显示窗口缩略图", action: #selector(toggleThumbnails), keyEquivalent: "")
        thumbnailsItem.target = self
        thumbnailsItem.state = settings.showThumbnails ? .on : .off
        menu.addItem(thumbnailsItem)

        let minimizedItem = NSMenuItem(title: "包含最小化到 Dock 的窗口", action: #selector(toggleMinimizedWindows), keyEquivalent: "")
        minimizedItem.target = self
        minimizedItem.state = settings.includeMinimizedWindows ? .on : .off
        menu.addItem(minimizedItem)

        let hiddenItem = NSMenuItem(title: "包含隐藏应用窗口（较慢）", action: #selector(toggleHiddenWindows), keyEquivalent: "")
        hiddenItem.target = self
        hiddenItem.state = settings.includeHiddenWindows ? .on : .off
        menu.addItem(hiddenItem)

        let doubleOptionItem = NSMenuItem(title: "双击 Option 最小化当前窗口", action: #selector(toggleDoubleOptionMinimize), keyEquivalent: "")
        doubleOptionItem.target = self
        doubleOptionItem.state = settings.minimizeOnDoubleOption ? .on : .off
        menu.addItem(doubleOptionItem)

        let optionCommandItem = NSMenuItem(title: "启用 Option 字母快捷键（实验）", action: #selector(toggleOptionCommandKeys), keyEquivalent: "")
        optionCommandItem.target = self
        optionCommandItem.state = settings.optionCommandKeysEnabled ? .on : .off
        menu.addItem(optionCommandItem)

        let loginItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = loginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let testItem = NSMenuItem(title: "显示窗口列表", action: #selector(showSwitcherFromMenu), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        let permissionsItem = NSMenuItem(title: "打开辅助功能权限设置", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        let screenItem = NSMenuItem(title: "打开屏幕录制权限设置", action: #selector(openScreenCaptureSettings), keyEquivalent: "")
        screenItem.target = self
        menu.addItem(screenItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        updateStatusItemTitle()
    }

    private func rebuildStatusMenu() {
        buildStatusMenu()
    }

    private func updateStatusItemTitle() {
        statusItem?.button?.title = settings.enabled ? "Alt" : "Alt off"
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        if settings.enabled {
            if !hotKeys.isRunning {
                startKeyboardCapture()
            }
        } else {
            hotKeys.stop()
            overlay.cancel()
            optionDoubleTap.cancelPendingTap()
            stopOptionReleaseWatcher()
        }
        rebuildStatusMenu()
    }

    @objc private func toggleThumbnails() {
        settings.showThumbnails.toggle()
        if settings.showThumbnails {
            ScreenCapturePermission.requestIfNeeded()
        }
        rebuildStatusMenu()
    }

    @objc private func toggleMinimizedWindows() {
        settings.includeMinimizedWindows.toggle()
        if settings.includeMinimizedWindows {
            _ = Accessibility.isTrusted(prompt: true)
        }
        refreshAccessibilityCache()
        rebuildStatusMenu()
    }

    @objc private func toggleHiddenWindows() {
        settings.includeHiddenWindows.toggle()
        if settings.includeHiddenWindows {
            _ = Accessibility.isTrusted(prompt: true)
        }
        refreshAccessibilityCache()
        rebuildStatusMenu()
    }

    @objc private func toggleDoubleOptionMinimize() {
        settings.minimizeOnDoubleOption.toggle()
        optionDoubleTap.isEnabled = settings.minimizeOnDoubleOption
        optionDoubleTap.cancelPendingTap()

        if settings.minimizeOnDoubleOption {
            _ = Accessibility.isTrusted(prompt: true)
        }

        rebuildStatusMenu()
    }

    @objc private func toggleOptionCommandKeys() {
        settings.optionCommandKeysEnabled.toggle()
        optionDoubleTap.cancelPendingTap()

        if settings.optionCommandKeysEnabled {
            _ = Accessibility.isTrusted(prompt: true)
        }

        if settings.enabled {
            if !startKeyboardCaptureAfterSettingsChange() {
                settings.optionCommandKeysEnabled.toggle()
                _ = startKeyboardCaptureAfterSettingsChange()
            }
        }

        rebuildStatusMenu()
    }

    @objc private func toggleLoginItem() {
        do {
            try loginItemManager.setEnabled(!loginItemManager.isEnabled)
            rebuildStatusMenu()
        } catch {
            showErrorAlert(message: "无法设置开机自动启动", detail: error.localizedDescription)
        }
    }

    @objc private func openAccessibilitySettings() {
        SettingsOpener.openAccessibility()
    }

    @objc private func showSwitcherFromMenu() {
        handleOptionTab(reverse: false)
    }

    @objc private func openScreenCaptureSettings() {
        SettingsOpener.openScreenCapture()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showHotKeyAlert() {
        let alert = NSAlert()
        alert.messageText = "TrustedAltTab 无法捕获快捷键"
        alert.informativeText = "Option-Tab、Option-方向键或 Option 字母快捷键可能已被其他应用占用。请退出其他窗口管理器，或在菜单栏里重新启用 TrustedAltTab。"
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "稍后")
        alert.runModal()
    }

    private func startKeyboardCaptureAfterSettingsChange() -> Bool {
        hotKeys.stop()
        guard hotKeys.start(commandKeysEnabled: settings.optionCommandKeysEnabled) else {
            showHotKeyAlert()
            return false
        }
        updateStatusItemTitle()
        return true
    }

    private func showErrorAlert(message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

}
