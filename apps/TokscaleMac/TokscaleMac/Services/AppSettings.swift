import Foundation
import SwiftUI

/// Centralized, persistent app settings backed by UserDefaults.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    // MARK: - Keys
    private enum Key: String {
        case themeName = "tt_themeName"
        case useUTC = "tt_useUTC"
        case autoCheckUpdates = "tt_autoCheckUpdates"
        case appearance = "tt_appearance"
    }

    enum AppAppearance: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        var id: String { rawValue }
    }

    // MARK: - Properties

    var themeName: ThemeName {
        didSet { UserDefaults.standard.set(themeName.rawValue, forKey: Key.themeName.rawValue) }
    }

    var useUTC: Bool {
        didSet { UserDefaults.standard.set(useUTC, forKey: Key.useUTC.rawValue) }
    }

    var autoCheckUpdates: Bool {
        didSet { UserDefaults.standard.set(autoCheckUpdates, forKey: Key.autoCheckUpdates.rawValue) }
    }

    var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Key.appearance.rawValue) }
    }

    // MARK: - Computed

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - Computed

    /// Returns a Calendar configured for the user's preferred timezone.
    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = useUTC ? TimeZone(identifier: "UTC")! : TimeZone.current
        return cal
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        if let raw = defaults.string(forKey: Key.themeName.rawValue),
           let theme = ThemeName(rawValue: raw) {
            themeName = theme
        } else {
            themeName = .vscode
        }

        // Default to local time (more intuitive for most users)
        if defaults.object(forKey: Key.useUTC.rawValue) != nil {
            useUTC = defaults.bool(forKey: Key.useUTC.rawValue)
        } else {
            useUTC = false
        }

        if defaults.object(forKey: Key.autoCheckUpdates.rawValue) != nil {
            autoCheckUpdates = defaults.bool(forKey: Key.autoCheckUpdates.rawValue)
        } else {
            autoCheckUpdates = true
        }

        if let raw = defaults.string(forKey: Key.appearance.rawValue),
           let appApp = AppAppearance(rawValue: raw) {
            appearance = appApp
        } else {
            appearance = .system
        }
    }
}
