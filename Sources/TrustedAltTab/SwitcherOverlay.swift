import AppKit

final class SwitcherOverlay {
    var onConfirm: ((WindowInfo) -> Void)?

    private let thumbnailQueue = DispatchQueue(label: "local.trusted-alt-tab.thumbnails", qos: .userInitiated)
    private let panel: NSPanel
    private let rootView = NSView()
    private let shadowView = NSView()
    private let container = NSVisualEffectView()
    private let stack = NSStackView()
    private var windows: [WindowInfo] = []
    private var rows: [WindowRowView] = []
    private var selectedIndex = 0
    private var thumbnailGeneration = 0
    private var displayedRange: Range<Int> = 0..<0

    private let maxRows = 8
    private let panelWidth: CGFloat = 620
    private let panelCornerRadius: CGFloat = 14
    private let shadowPadding: CGFloat = 18
    private let rowHeight: CGFloat = 60
    private let horizontalInset: CGFloat = 12
    private let verticalInset: CGFloat = 12

    var isVisible: Bool {
        panel.isVisible
    }

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 320),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        rootView.layer?.masksToBounds = false

        shadowView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.wantsLayer = true
        shadowView.layer?.backgroundColor = NSColor.clear.cgColor
        shadowView.layer?.masksToBounds = false
        shadowView.layer?.shadowColor = NSColor.black.cgColor
        shadowView.layer?.shadowOpacity = 0.30
        shadowView.layer?.shadowRadius = 22
        shadowView.layer?.shadowOffset = CGSize(width: 0, height: -4)

        container.translatesAutoresizingMaskIntoConstraints = false
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.appearance = NSAppearance(named: .vibrantDark)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        container.layer?.borderWidth = 1
        container.layer?.cornerRadius = panelCornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 6

        rootView.addSubview(shadowView)
        shadowView.addSubview(container)
        container.addSubview(stack)
        panel.contentView = rootView

        NSLayoutConstraint.activate([
            shadowView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: shadowPadding),
            shadowView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -shadowPadding),
            shadowView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: shadowPadding),
            shadowView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -shadowPadding),

            container.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            container.topAnchor.constraint(equalTo: shadowView.topAnchor),
            container.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalInset),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalInset),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: verticalInset),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -verticalInset)
        ])
    }

    func show(windows: [WindowInfo], selectedIndex: Int) {
        guard !windows.isEmpty else {
            return
        }

        panel.alphaValue = 1
        self.windows = windows
        self.selectedIndex = min(max(selectedIndex, 0), windows.count - 1)
        rebuildRows()
        panel.orderFrontRegardless()
    }

    func update(windows: [WindowInfo]) {
        guard !windows.isEmpty else {
            return
        }

        let selectedWindow = self.windows.indices.contains(selectedIndex) ? self.windows[selectedIndex] : nil
        self.windows = windows

        if let selectedWindow, let newIndex = windows.firstIndex(of: selectedWindow) {
            selectedIndex = newIndex
        } else {
            selectedIndex = min(selectedIndex, windows.count - 1)
        }

        rebuildRows()
    }

    func cycle(reverse: Bool) {
        guard !windows.isEmpty else {
            return
        }

        let previousRange = displayedRange
        if reverse {
            selectedIndex = selectedIndex == 0 ? windows.count - 1 : selectedIndex - 1
        } else {
            selectedIndex = (selectedIndex + 1) % windows.count
        }

        if visibleRange() == previousRange {
            updateSelection()
        } else {
            rebuildRows()
        }
    }

    func confirm() -> WindowInfo? {
        guard windows.indices.contains(selectedIndex) else {
            cancel()
            return nil
        }

        return windows[selectedIndex]
    }

    func cancel() {
        panel.alphaValue = 0
        panel.orderOut(nil)
        windows.removeAll()
        rows.removeAll()
        selectedIndex = 0
        thumbnailGeneration += 1
        displayedRange = 0..<0
    }

    private func rebuildRows() {
        thumbnailGeneration += 1
        let generation = thumbnailGeneration

        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        rows.removeAll()

        stack.addArrangedSubview(headerView())

        let range = visibleRange()
        displayedRange = range
        var thumbnailJobs: [(WindowRowView, WindowInfo)] = []

        for index in range {
            let row = WindowRowView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
            row.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
            row.configure(window: windows[index], selected: index == selectedIndex)
            row.onClick = { [weak self] in
                guard let self else {
                    return
                }
                self.selectedIndex = index
                if let window = self.confirm() {
                    self.onConfirm?(window)
                }
            }
            rows.append(row)
            stack.addArrangedSubview(row)
            thumbnailJobs.append((row, windows[index]))
        }

        if windows.count > maxRows {
            stack.addArrangedSubview(footerView(range: range))
        }
        positionPanel()
        loadThumbnails(thumbnailJobs, generation: generation)
    }

    private func updateSelection() {
        for (offset, row) in rows.enumerated() {
            let windowIndex = displayedRange.lowerBound + offset
            row.setSelected(windowIndex == selectedIndex)
        }
    }

    private func loadThumbnails(_ jobs: [(WindowRowView, WindowInfo)], generation: Int) {
        guard AppSettings.shared.showThumbnails else {
            return
        }

        thumbnailQueue.async { [weak self] in
            for (row, window) in jobs {
                guard let self else {
                    return
                }

                let image = WindowThumbnailProvider.shared.thumbnail(for: window)
                DispatchQueue.main.async { [weak self, weak row] in
                    guard let self, self.thumbnailGeneration == generation else {
                        return
                    }
                    row?.setThumbnail(image, for: window)
                }
            }
        }
    }

    private func headerView() -> NSView {
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        wrapper.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let title = NSTextField(labelWithString: "窗口")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = NSColor.white.withAlphaComponent(0.92)

        let count = NSTextField(labelWithString: "\(windows.count) 个窗口")
        count.translatesAutoresizingMaskIntoConstraints = false
        count.font = .systemFont(ofSize: 11, weight: .medium)
        count.textColor = NSColor.white.withAlphaComponent(0.52)

        wrapper.addSubview(title)
        wrapper.addSubview(count)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            title.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            count.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -4),
            count.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor)
        ])

        return wrapper
    }

    private func footerView(range: Range<Int>) -> NSView {
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        wrapper.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let prefix = "\(range.lowerBound + 1)-\(range.upperBound) / \(windows.count)"

        let label = NSTextField(labelWithString: prefix)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.44)

        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor, constant: -4)
        ])

        return wrapper
    }

    private func visibleRange() -> Range<Int> {
        guard windows.count > maxRows else {
            return 0..<windows.count
        }

        let half = maxRows / 2
        var start = max(0, selectedIndex - half)
        if start + maxRows > windows.count {
            start = max(0, windows.count - maxRows)
        }
        return start..<min(windows.count, start + maxRows)
    }

    private func positionPanel() {
        let visibleCount = min(windows.count, maxRows)
        let footerHeight: CGFloat = windows.count > maxRows ? 16 + stack.spacing : 0
        let height = CGFloat(visibleCount) * rowHeight
            + CGFloat(max(visibleCount - 1, 0)) * stack.spacing
            + 22
            + stack.spacing
            + footerHeight
            + verticalInset * 2

        let screen = screenForOverlay()
        let frame = centeredFrame(
            width: panelWidth + shadowPadding * 2,
            height: height + shadowPadding * 2,
            in: screen.visibleFrame
        )
        panel.setFrame(frame, display: true)
        rootView.layoutSubtreeIfNeeded()
        updateShadowPath()
    }

    private func updateShadowPath() {
        let bounds = shadowView.bounds
        guard !bounds.isEmpty else {
            return
        }

        shadowView.layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: panelCornerRadius,
            cornerHeight: panelCornerRadius,
            transform: nil
        )
    }

    private func screenForOverlay() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first!
    }

    private func centeredFrame(width: CGFloat, height: CGFloat, in visibleFrame: CGRect) -> CGRect {
        let clampedWidth = min(width, visibleFrame.width - 40)
        let clampedHeight = min(height, visibleFrame.height - 40)
        return CGRect(
            x: visibleFrame.midX - clampedWidth / 2,
            y: visibleFrame.midY - clampedHeight / 2,
            width: clampedWidth,
            height: clampedHeight
        )
    }

    private var contentWidth: CGFloat {
        panelWidth - horizontalInset * 2
    }
}
