import AppKit
import Carbon.HIToolbox
import Foundation

enum RightGestureDirection: String {
    case up = "U"
    case down = "D"
    case left = "L"
    case right = "R"
}

struct RightGestureShortcutAction: Codable {
    struct KeyStroke: Codable {
        let keyCode: Int
        let modifiers: [String]
    }

    let name: String
    let keys: [KeyStroke]
    let delivery: String?
    let windowAction: String?

    init(name: String, keys: [KeyStroke], delivery: String? = nil, windowAction: String? = nil) {
        self.name = name
        self.keys = keys
        self.delivery = delivery
        self.windowAction = windowAction
    }
}

struct RightGestureConfig: Codable {
    struct GestureTemplate: Codable {
        let name: String
        let points: [Double]
        let action: RightGestureShortcutAction
    }

    var gestures: [String: RightGestureShortcutAction]
    var mouseButtons: [String: RightGestureShortcutAction]
    var templates: [GestureTemplate]?

    static let defaultConfig = RightGestureConfig(
        gestures: [
            "L": RightGestureShortcutAction(name: "Left Half", keys: [], windowAction: "left"),
            "R": RightGestureShortcutAction(name: "Right Half", keys: [], windowAction: "right"),
            "U": RightGestureShortcutAction(name: "Top Half", keys: [], windowAction: "top"),
            "D": RightGestureShortcutAction(name: "Bottom Half", keys: [], windowAction: "bottom"),
            "UD": RightGestureShortcutAction(name: "Address Bar", keys: [.init(keyCode: kVK_ANSI_L, modifiers: ["command"])]),
            "DU": RightGestureShortcutAction(name: "Reload", keys: [.init(keyCode: kVK_ANSI_R, modifiers: ["command"])]),
            "LR": RightGestureShortcutAction(name: "Previous Tab", keys: [.init(keyCode: kVK_Tab, modifiers: ["control", "shift"])]),
            "RL": RightGestureShortcutAction(name: "Next Tab", keys: [.init(keyCode: kVK_Tab, modifiers: ["control"])]),
            "DR": RightGestureShortcutAction(name: "Hide App", keys: [.init(keyCode: kVK_ANSI_H, modifiers: ["command"])]),
            "DL": RightGestureShortcutAction(name: "Quit App", keys: [.init(keyCode: kVK_ANSI_Q, modifiers: ["command"])])
        ],
        mouseButtons: [
            "R+Left": RightGestureShortcutAction(name: "Close Tab", keys: [.init(keyCode: kVK_ANSI_W, modifiers: ["command"])]),
            "R+Middle": RightGestureShortcutAction(name: "New Tab", keys: [.init(keyCode: kVK_ANSI_T, modifiers: ["command"])]),
            "R+Mouse4": RightGestureShortcutAction(name: "Back", keys: [.init(keyCode: kVK_ANSI_LeftBracket, modifiers: ["command"])]),
            "R+Mouse5": RightGestureShortcutAction(name: "Forward", keys: [.init(keyCode: kVK_ANSI_RightBracket, modifiers: ["command"])])
        ],
        templates: []
    )
}

final class RightGestureConfigStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    let url: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AltGesture", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("right-gestures.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> RightGestureConfig {
        if !FileManager.default.fileExists(atPath: url.path) {
            if migrateExistingConfigIfAvailable() {
                return load()
            } else if let bundledConfig = loadBundledDefault() {
                save(bundledConfig)
            } else {
                save(RightGestureConfig.defaultConfig)
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let config = try decoder.decode(RightGestureConfig.self, from: data)
            let migration = migratingKnownWindowActions(in: config)
            if migration.didChange {
                save(migration.config)
            }
            return migration.config
        } catch {
            DebugLog.write("right gesture config read failed: \(error)")
            return RightGestureConfig.defaultConfig
        }
    }

    func save(_ config: RightGestureConfig) {
        do {
            let data = try encoder.encode(config)
            try data.write(to: url, options: [.atomic])
        } catch {
            DebugLog.write("right gesture config write failed: \(error)")
        }
    }

    private func loadBundledDefault() -> RightGestureConfig? {
        guard let bundledURL = Bundle.main.url(forResource: "default-right-gestures", withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: bundledURL)
            return try decoder.decode(RightGestureConfig.self, from: data)
        } catch {
            DebugLog.write("right gesture bundled default read failed: \(error)")
            return nil
        }
    }

    private func migrateExistingConfigIfAvailable() -> Bool {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let candidates = [
            base.appendingPathComponent("TrustedAltTab/right-gestures.json"),
            base.appendingPathComponent("RightKeyGesture/gestures.json"),
            base.appendingPathComponent("WeGestureARM/gestures.json")
        ]

        for sourceURL in candidates where FileManager.default.fileExists(atPath: sourceURL.path) {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: url)
                DebugLog.write("right gesture config migrated from \(sourceURL.path)")
                return true
            } catch {
                DebugLog.write("right gesture config migration failed from \(sourceURL.path): \(error)")
            }
        }

        return false
    }

    private func migratingKnownWindowActions(in config: RightGestureConfig) -> (config: RightGestureConfig, didChange: Bool) {
        var didChange = false

        let gestures = config.gestures.mapValues { action in
            let migrated = migrateKnownWindowAction(action)
            didChange = didChange || migrated.didChange
            return migrated.action
        }

        let mouseButtons = config.mouseButtons.mapValues { action in
            let migrated = migrateKnownWindowAction(action)
            didChange = didChange || migrated.didChange
            return migrated.action
        }

        let templates = config.templates?.map { template in
            let migrated = migrateKnownWindowAction(template.action)
            didChange = didChange || migrated.didChange
            return RightGestureConfig.GestureTemplate(
                name: template.name,
                points: template.points,
                action: migrated.action
            )
        }

        return (
            RightGestureConfig(gestures: gestures, mouseButtons: mouseButtons, templates: templates),
            didChange
        )
    }

    private func migrateKnownWindowAction(_ action: RightGestureShortcutAction) -> (action: RightGestureShortcutAction, didChange: Bool) {
        if let windowAction = action.windowAction, WindowSnapDirection(rightGestureActionName: windowAction) != nil {
            guard action.delivery != nil || !action.keys.isEmpty else {
                return (action, false)
            }

            return (
                RightGestureShortcutAction(
                    name: action.name,
                    keys: [],
                    windowAction: windowAction
                ),
                true
            )
        }

        guard let windowAction = nativeWindowAction(for: action) else {
            return (action, false)
        }

        return (
            RightGestureShortcutAction(
                name: action.name,
                keys: [],
                windowAction: windowAction
            ),
            true
        )
    }

    private func nativeWindowAction(for action: RightGestureShortcutAction) -> String? {
        guard action.delivery == "systemEvents", action.keys.count == 1, let stroke = action.keys.first else {
            return nil
        }

        let modifiers = Set(stroke.modifiers.map { $0.lowercased() })
        guard modifiers == ["control", "option"] || modifiers == ["ctrl", "option"] || modifiers == ["control", "alt"] else {
            return nil
        }

        switch stroke.keyCode {
        case kVK_LeftArrow:
            return "left"
        case kVK_RightArrow:
            return "right"
        case kVK_UpArrow:
            return "top"
        case kVK_DownArrow:
            return "bottom"
        default:
            return nil
        }
    }
}
