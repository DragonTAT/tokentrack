import SwiftUI

enum ThemeName: String, CaseIterable, Identifiable {
    case vscode, xcode, claude, nord, dracula

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vscode: return "Default"
        case .xcode: return "Midnight"
        case .claude: return "Claude"
        case .nord: return "Nord"
        case .dracula: return "Dracula"
        }
    }

    var next: ThemeName {
        let all = ThemeName.allCases
        let idx = all.firstIndex(of: self) ?? all.startIndex
        return all[(all.distance(from: all.startIndex, to: idx) + 1) % all.count]
    }
}

struct Theme {
    let name: ThemeName
    // Graph colors (5 intensity blocks)
    let colors: [Color]
    
    // Core UI (Environment-dependent)
    let background: Color
    let panelBackground: Color
    let foreground: Color
    let secondaryForeground: Color
    let border: Color
    let stripedRow: Color
    let accent: Color
    let selection: Color

    static func from(_ name: ThemeName, scheme: ColorScheme? = nil) -> Theme {
        // Defaults to dark mode logic if no scheme provided (used in DataStore as a fallback)
        let isDark = scheme != .light
        
        let colors: [Color]
        let accent: Color

        // Base IDE-inspired palettes
        switch name {
        case .vscode: // Default
            // Light: Blue accent, clean grays / Dark: Blue accent, deep gray-blue
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 121/255, green: 184/255, blue: 255/255),
                Color(red: 56/255, green: 139/255, blue: 253/255),
                Color(red: 31/255, green: 111/255, blue: 235/255),
                Color(red: 13/255, green: 65/255, blue: 157/255),
            ]
            accent = isDark ? Color(red: 56/255, green: 139/255, blue: 253/255) : Color(red: 0/255, green: 104/255, blue: 200/255)
            
        case .xcode: // Midnight
            // Xcode default colors. Light: true blue. Dark: light cyan/pinkish blue
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 161/255, green: 218/255, blue: 220/255),
                Color(red: 84/255, green: 191/255, blue: 200/255),
                Color(red: 23/255, green: 140/255, blue: 180/255),
                Color(red: 17/255, green: 90/255, blue: 120/255),
            ]
            accent = isDark ? Color(red: 90/255, green: 195/255, blue: 225/255) : Color(red: 0/255, green: 120/255, blue: 215/255)
            
        case .claude: // Claude Code
            // Light: warm beige/biscuit / Dark: earthy brown-grey. Accent: Terracotta/Claude orange
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 245/255, green: 200/255, blue: 160/255),
                Color(red: 225/255, green: 150/255, blue: 90/255),
                Color(red: 213/255, green: 105/255, blue: 60/255),
                Color(red: 160/255, green: 60/255, blue: 30/255),
            ]
            accent = isDark ? Color(red: 218/255, green: 119/255, blue: 86/255) : Color(red: 190/255, green: 90/255, blue: 50/255)
            
        case .nord: // Nord (Cold)
            // Frosty blue/cyan
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 143/255, green: 188/255, blue: 187/255), // Nord 7
                Color(red: 136/255, green: 192/255, blue: 208/255), // Nord 8
                Color(red: 129/255, green: 161/255, blue: 193/255), // Nord 9
                Color(red: 94/255, green: 129/255, blue: 172/255),  // Nord 10
            ]
            accent = isDark ? Color(red: 136/255, green: 192/255, blue: 208/255) : Color(red: 94/255, green: 129/255, blue: 172/255)
            
        case .dracula: // Dracula (Purple Night)
            // Hot pink/purple
            colors = [
                Color(red: 40/255, green: 42/255, blue: 54/255),
                Color(red: 255/255, green: 184/255, blue: 210/255),
                Color(red: 255/255, green: 121/255, blue: 198/255),
                Color(red: 189/255, green: 147/255, blue: 249/255),
                Color(red: 98/255, green: 114/255, blue: 164/255),
            ]
            // Pink for light, Purple for dark
            accent = isDark ? Color(red: 189/255, green: 147/255, blue: 249/255) : Color(red: 140/255, green: 50/255, blue: 170/255)
        }

        // Generate UI colors based on colorScheme & IDE-like specific overrides
        let baseBg: Color
        let basePanel: Color
        let baseBorder: Color
        let baseStripe: Color
        let baseSelection: Color
        
        if isDark {
            switch name {
            case .xcode: // Deep black background for Xcode midnight
                baseBg = Color(red: 0, green: 0, blue: 0)
                basePanel = Color(red: 28/255, green: 28/255, blue: 30/255)
            case .dracula: // Dracula dark
                baseBg = Color(red: 40/255, green: 42/255, blue: 54/255)
                basePanel = Color(red: 68/255, green: 71/255, blue: 90/255)
            case .nord: // Nord dark
                baseBg = Color(red: 36/255, green: 41/255, blue: 51/255) // Nord 0
                basePanel = Color(red: 59/255, green: 66/255, blue: 82/255) // Nord 1
            case .claude: // Earthy Claude dark
                baseBg = Color(red: 32/255, green: 28/255, blue: 26/255)
                basePanel = Color(red: 46/255, green: 42/255, blue: 38/255)
            default: // VS Code default Dark+
                baseBg = Color(red: 30/255, green: 30/255, blue: 30/255)
                basePanel = Color(red: 37/255, green: 37/255, blue: 38/255)
            }
            // Use slightly lighter colors for other elements
            baseBorder = basePanel.tinted(with: .white, amount: 0.1)
            baseStripe = baseBg.tinted(with: .white, amount: 0.03)
            baseSelection = basePanel.tinted(with: .white, amount: 0.15)
        } else {
            switch name {
            case .claude: // Claude warm white
                baseBg = Color(red: 252/255, green: 250/255, blue: 245/255)
                basePanel = Color(red: 244/255, green: 240/255, blue: 232/255)
            case .nord: // Nord Snow Storm
                baseBg = Color(red: 236/255, green: 239/255, blue: 244/255)
                basePanel = Color(red: 229/255, green: 233/255, blue: 240/255)
            case .vscode: // VS Code light
                baseBg = Color(red: 255/255, green: 255/255, blue: 255/255)
                basePanel = Color(red: 243/255, green: 243/255, blue: 243/255)
            default:
                baseBg = Color.white
                basePanel = Color(white: 0.96)
            }
            baseBorder = basePanel.tinted(with: .black, amount: 0.1)
            baseStripe = baseBg.tinted(with: .black, amount: 0.02)
            baseSelection = basePanel.tinted(with: .black, amount: 0.08)
        }

        // Minor general hue-tinting (keep professional & low saturation)
        let bgTintAmt = isDark ? 0.02 : 0.01
        let panelTintAmt = isDark ? 0.04 : 0.02
        let elementTintAmt = isDark ? 0.06 : 0.03

        let background = baseBg.tinted(with: accent, amount: bgTintAmt)
        let panelBackground = basePanel.tinted(with: accent, amount: panelTintAmt)
        let border = baseBorder.tinted(with: accent, amount: elementTintAmt)
        let stripedRow = baseStripe.tinted(with: accent, amount: panelTintAmt)
        let selection = baseSelection.tinted(with: accent, amount: elementTintAmt)

        // Typography Color Tinting
        // Black color in light mode / White color in dark mode gets tinted with the accent color
        // so it looks perfectly integrated with the theme!
        let baseFg = isDark ? Color(red: 220/255, green: 224/255, blue: 230/255) : Color(white: 0.15)
        let baseSecondaryFg = isDark ? Color(white: 0.65) : Color(white: 0.45)
        
        // In light mode, inject more accent hue into the black font
        let fgTintAmt = isDark ? 0.05 : 0.25
        let secFgTintAmt = isDark ? 0.08 : 0.15
        
        let foreground = baseFg.tinted(with: accent, amount: fgTintAmt)
        let secondaryForeground = baseSecondaryFg.tinted(with: accent, amount: secFgTintAmt)

        return Theme(
            name: name,
            colors: colors,
            background: background,
            panelBackground: panelBackground,
            foreground: foreground,
            secondaryForeground: secondaryForeground,
            border: border,
            stripedRow: stripedRow,
            accent: accent,
            selection: selection
        )
    }

    func intensityColor(_ intensity: Double) -> Color {
        let safe = intensity.isFinite ? max(0, min(1, intensity)) : 0
        let idx: Int
        switch safe {
        case ...0: idx = 0
        case ..<0.25: idx = 1
        case ..<0.50: idx = 2
        case ..<0.75: idx = 3
        default: idx = 4
        }
        return colors[idx]
    }
}

// SwiftUI Environment Key to allow reading the Theme anywhere without needing to pipe through bindings.
struct ThemeEnvironmentKey: EnvironmentKey {
    // Default theme (fallback)
    static let defaultValue: Theme = .from(.vscode, scheme: .dark)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

extension Color {
    /// Blend the current color with a tint color using the specified amount (0.0 to 1.0)
    func tinted(with tint: Color, amount: Double) -> Color {
        // Fallback or precise mixing
        guard let currentNative = NSColor(self).usingColorSpace(.extendedSRGB),
              let tintNative = NSColor(tint).usingColorSpace(.extendedSRGB) else {
            return self
        }
        
        let r = currentNative.redComponent * (1.0 - amount) + tintNative.redComponent * amount
        let g = currentNative.greenComponent * (1.0 - amount) + tintNative.greenComponent * amount
        let b = currentNative.blueComponent * (1.0 - amount) + tintNative.blueComponent * amount
        let a = currentNative.alphaComponent * (1.0 - amount) + tintNative.alphaComponent * amount
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
