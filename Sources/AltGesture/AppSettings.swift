import Foundation

final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let showThumbnails = "showThumbnails"
        static let includeMinimizedWindows = "includeMinimizedWindows"
        static let includeHiddenWindows = "includeHiddenWindows"
        static let minimizeOnDoubleOption = "minimizeOnDoubleOption"
        static let optionCommandKeysEnabled = "optionCommandKeysEnabled"
        static let rightGestureEnabled = "rightGestureEnabled"
        static let speedDefaultsVersion = "speedDefaultsVersion"
        static let legacyDefaultsMigrationVersion = "legacyDefaultsMigrationVersion"
        static let minimalPermissionsDefaultsVersion = "minimalPermissionsDefaultsVersion"
    }

    var enabled: Bool {
        get {
            value(for: Key.enabled, default: true)
        }
        set {
            defaults.set(newValue, forKey: Key.enabled)
        }
    }

    var showThumbnails: Bool {
        get {
            value(for: Key.showThumbnails, default: false)
        }
        set {
            defaults.set(newValue, forKey: Key.showThumbnails)
        }
    }

    var includeMinimizedWindows: Bool {
        get {
            value(for: Key.includeMinimizedWindows, default: true)
        }
        set {
            defaults.set(newValue, forKey: Key.includeMinimizedWindows)
        }
    }

    var includeHiddenWindows: Bool {
        get {
            value(for: Key.includeHiddenWindows, default: false)
        }
        set {
            defaults.set(newValue, forKey: Key.includeHiddenWindows)
        }
    }

    var minimizeOnDoubleOption: Bool {
        get {
            value(for: Key.minimizeOnDoubleOption, default: true)
        }
        set {
            defaults.set(newValue, forKey: Key.minimizeOnDoubleOption)
        }
    }

    var optionCommandKeysEnabled: Bool {
        get {
            value(for: Key.optionCommandKeysEnabled, default: false)
        }
        set {
            defaults.set(newValue, forKey: Key.optionCommandKeysEnabled)
        }
    }

    var rightGestureEnabled: Bool {
        get {
            value(for: Key.rightGestureEnabled, default: true)
        }
        set {
            defaults.set(newValue, forKey: Key.rightGestureEnabled)
        }
    }

    private init() {}

    func applySpeedDefaultsIfNeeded() {
        migrateLegacyDefaultsIfNeeded()
        applyMinimalPermissionsDefaultsIfNeeded()

        guard defaults.integer(forKey: Key.speedDefaultsVersion) < 2 else {
            return
        }

        defaults.set(false, forKey: Key.showThumbnails)
        defaults.set(true, forKey: Key.includeMinimizedWindows)
        defaults.set(false, forKey: Key.includeHiddenWindows)
        defaults.set(true, forKey: Key.minimizeOnDoubleOption)
        defaults.set(false, forKey: Key.optionCommandKeysEnabled)
        defaults.set(2, forKey: Key.speedDefaultsVersion)
    }

    private func migrateLegacyDefaultsIfNeeded() {
        guard defaults.integer(forKey: Key.legacyDefaultsMigrationVersion) < 1 else {
            return
        }

        guard let legacyDomain = defaults.persistentDomain(forName: "local.trusted-alt-tab") else {
            defaults.set(1, forKey: Key.legacyDefaultsMigrationVersion)
            return
        }

        for key in [
            Key.enabled,
            Key.includeMinimizedWindows,
            Key.includeHiddenWindows,
            Key.minimizeOnDoubleOption,
            Key.optionCommandKeysEnabled,
            Key.rightGestureEnabled,
            Key.speedDefaultsVersion
        ] {
            if let value = legacyDomain[key] {
                defaults.set(value, forKey: key)
            }
        }

        defaults.set(1, forKey: Key.legacyDefaultsMigrationVersion)
        DebugLog.write("migrated user defaults from local.trusted-alt-tab")
    }

    private func applyMinimalPermissionsDefaultsIfNeeded() {
        guard defaults.integer(forKey: Key.minimalPermissionsDefaultsVersion) < 1 else {
            return
        }

        defaults.set(false, forKey: Key.showThumbnails)
        defaults.set(1, forKey: Key.minimalPermissionsDefaultsVersion)
        DebugLog.write("applied minimal permission defaults")
    }

    private func value(for key: String, default defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }
}
