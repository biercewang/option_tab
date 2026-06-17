import AppKit

struct WindowInfo: Equatable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String
    let bounds: CGRect
    let icon: NSImage?
    let isOnScreen: Bool
    let isMinimized: Bool
    let isHidden: Bool
    let order: Int

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "无标题窗口" : trimmed
    }

    var statusText: String {
        if isMinimized {
            return "最小化"
        }
        if isHidden {
            return "隐藏"
        }
        return "可见"
    }

    var identityKey: String {
        [
            String(pid),
            displayTitle,
            String(Int(bounds.origin.x.rounded())),
            String(Int(bounds.origin.y.rounded())),
            String(Int(bounds.width.rounded())),
            String(Int(bounds.height.rounded()))
        ].joined(separator: "|")
    }

    var appKey: String {
        "\(pid)|\(appName)"
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id && lhs.pid == rhs.pid
    }
}
