import Foundation

final class LoginItemManager {
    private let label = "local.trusted-alt-tab.login"

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try install()
        } else {
            try remove()
        }
    }

    private func install() throws {
        let appPath = Bundle.main.bundlePath
        guard appPath.hasSuffix(".app") else {
            throw LoginItemError.notRunningFromAppBundle
        }

        try FileManager.default.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                "/usr/bin/open",
                appPath
            ],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua"
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: launchAgentURL, options: .atomic)
        DebugLog.write("login item enabled path=\(launchAgentURL.path)")
    }

    private func remove() throws {
        guard isEnabled else {
            return
        }

        try FileManager.default.removeItem(at: launchAgentURL)
        DebugLog.write("login item disabled path=\(launchAgentURL.path)")
    }

    private var launchAgentURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
}

enum LoginItemError: LocalizedError {
    case notRunningFromAppBundle

    var errorDescription: String? {
        switch self {
        case .notRunningFromAppBundle:
            return "TrustedAltTab 需要从 .app 启动后才能设置开机自动启动。"
        }
    }
}
