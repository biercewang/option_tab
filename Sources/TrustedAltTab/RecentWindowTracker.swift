import Foundation

final class RecentWindowTracker {
    private var windowRecency: [String: TimeInterval] = [:]
    private var appRecency: [String: TimeInterval] = [:]
    private var seeded = false

    func seedIfNeeded(with windows: [WindowInfo]) {
        guard !seeded else {
            return
        }

        seeded = true
        let now = Date.timeIntervalSinceReferenceDate
        for (index, window) in windows.enumerated() {
            record(window, at: now - Double(index) * 0.001, prune: false)
        }
        prune()
    }

    func record(_ window: WindowInfo) {
        record(window, at: Date.timeIntervalSinceReferenceDate, prune: true)
    }

    func recordRecentlyMinimized(_ target: DisplayedWindowTarget) {
        let now = Date.timeIntervalSinceReferenceDate
        windowRecency[target.identityKey] = now
        appRecency[target.appKey] = max(appRecency[target.appKey] ?? 0, now)
        prune()
    }

    func sort(_ windows: [WindowInfo], frontmostWindow: WindowInfo? = nil) -> [WindowInfo] {
        windows.sorted { lhs, rhs in
            let lhsScore = recencyScore(for: lhs, frontmostWindow: frontmostWindow)
            let rhsScore = recencyScore(for: rhs, frontmostWindow: frontmostWindow)

            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            if lhs.order != rhs.order {
                return lhs.order < rhs.order
            }

            if lhs.appName != rhs.appName {
                return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
            }

            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }

    private func record(_ window: WindowInfo, at timestamp: TimeInterval, prune shouldPrune: Bool) {
        windowRecency[window.identityKey] = timestamp
        appRecency[window.appKey] = max(appRecency[window.appKey] ?? 0, timestamp)

        if shouldPrune {
            prune()
        }
    }

    private func recencyScore(for window: WindowInfo, frontmostWindow: WindowInfo?) -> TimeInterval {
        if let frontmostWindow {
            if window.identityKey == frontmostWindow.identityKey {
                return Date.timeIntervalSinceReferenceDate + 2
            }

            if window.pid == frontmostWindow.pid {
                return Date.timeIntervalSinceReferenceDate + 1
            }
        }

        if let exact = windowRecency[window.identityKey] {
            return exact
        }

        if let app = appRecency[window.appKey] {
            return app - 0.0005
        }

        return 0
    }

    private func prune() {
        let maxEntries = 300

        if windowRecency.count > maxEntries {
            windowRecency = Dictionary(
                uniqueKeysWithValues: windowRecency
                    .sorted { $0.value > $1.value }
                    .prefix(maxEntries)
                    .map { ($0.key, $0.value) }
            )
        }

        if appRecency.count > maxEntries {
            appRecency = Dictionary(
                uniqueKeysWithValues: appRecency
                    .sorted { $0.value > $1.value }
                    .prefix(maxEntries)
                    .map { ($0.key, $0.value) }
            )
        }
    }
}
