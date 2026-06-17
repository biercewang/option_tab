import AppKit

final class WindowRowView: NSView {
    var onClick: (() -> Void)?

    private let thumbnailView = NSImageView()
    private let thumbnailContainer = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let appLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")

    private var selected = false
    private var representedWindow: WindowInfo?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(window: WindowInfo, selected: Bool) {
        self.selected = selected
        representedWindow = window

        thumbnailView.image = window.icon
        titleLabel.stringValue = window.displayTitle
        appLabel.stringValue = window.appName
        statusLabel.stringValue = window.statusText

        applyTextStyle()

        applySelectionStyle()
    }

    func setSelected(_ selected: Bool) {
        self.selected = selected
        applyTextStyle()
        applySelectionStyle()
    }

    private func applyTextStyle() {
        titleLabel.textColor = selected ? .white : NSColor.white.withAlphaComponent(0.90)
        appLabel.textColor = selected ? NSColor.white.withAlphaComponent(0.78) : NSColor.white.withAlphaComponent(0.58)

        if representedWindow?.isMinimized == true {
            statusLabel.textColor = selected ? NSColor.white.withAlphaComponent(0.95) : NSColor.systemYellow.withAlphaComponent(0.82)
        } else if representedWindow?.isHidden == true {
            statusLabel.textColor = selected ? NSColor.white.withAlphaComponent(0.95) : NSColor.systemPurple.withAlphaComponent(0.82)
        } else {
            statusLabel.textColor = selected ? NSColor.white.withAlphaComponent(0.95) : NSColor.systemGreen.withAlphaComponent(0.70)
        }
    }

    private func applySelectionStyle() {
        wantsLayer = true
        layer?.backgroundColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.82).cgColor
            : NSColor.white.withAlphaComponent(0.075).cgColor
        layer?.borderColor = selected
            ? NSColor.white.withAlphaComponent(0.26).cgColor
            : NSColor.white.withAlphaComponent(0.09).cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 9
    }

    func setThumbnail(_ image: NSImage?, for window: WindowInfo) {
        guard representedWindow == window else {
            return
        }
        thumbnailView.image = image ?? window.icon
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    private func setup() {
        wantsLayer = true

        thumbnailContainer.translatesAutoresizingMaskIntoConstraints = false
        thumbnailContainer.wantsLayer = true
        thumbnailContainer.layer?.cornerRadius = 7
        thumbnailContainer.layer?.masksToBounds = true
        thumbnailContainer.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        thumbnailContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        thumbnailContainer.layer?.borderWidth = 1

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 6
        thumbnailView.layer?.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1

        appLabel.translatesAutoresizingMaskIntoConstraints = false
        appLabel.font = .systemFont(ofSize: 11, weight: .regular)
        appLabel.lineBreakMode = .byTruncatingTail
        appLabel.maximumNumberOfLines = 1

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        statusLabel.alignment = .right

        addSubview(thumbnailContainer)
        thumbnailContainer.addSubview(thumbnailView)
        addSubview(titleLabel)
        addSubview(appLabel)
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            thumbnailContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            thumbnailContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnailContainer.widthAnchor.constraint(equalToConstant: 78),
            thumbnailContainer.heightAnchor.constraint(equalToConstant: 44),

            thumbnailView.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor, constant: 4),
            thumbnailView.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor, constant: -4),
            thumbnailView.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor, constant: 4),
            thumbnailView.bottomAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor, constant: -4),

            titleLabel.leadingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 11),

            appLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            appLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -12),
            appLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 72)
        ])
    }
}
