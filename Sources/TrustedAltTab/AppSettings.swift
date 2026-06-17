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
        static let speedDefaultsVersion = "speedDefaultsVersion"
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
            value(for: Key.showThumbnails, default: true)
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

    private init() {}

    func applySpeedDefaultsIfNeeded() {
        guard defaults.integer(forKey: Key.speedDefaultsVersion) < 2 else {
            return
        }

        defaults.set(true, forKey: Key.includeMinimizedWindows)
        defaults.set(false, forKey: Key.includeHiddenWindows)
        defaults.set(true, forKey: Key.minimizeOnDoubleOption)
        defaults.set(false, forKey: Key.optionCommandKeysEnabled)
        defaults.set(2, forKey: Key.speedDefaultsVersion)
    }

    private func value(for key: String, default defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }
}
