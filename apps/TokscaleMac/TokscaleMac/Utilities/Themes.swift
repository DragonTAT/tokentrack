import SwiftUI

enum ThemeName: String, CaseIterable, Identifiable {
    case green, halloween, teal, blue, pink, purple, orange, monochrome, ylgnbu

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ylgnbu: return "YlGnBu"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
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
    /// 5 intensity colors: [empty, grade1, grade2, grade3, grade4]
    let colors: [Color]
    let accent: Color

    static func from(_ name: ThemeName) -> Theme {
        let colors: [Color]
        switch name {
        case .green:
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 155/255, green: 233/255, blue: 168/255),
                Color(red: 64/255, green: 196/255, blue: 99/255),
                Color(red: 48/255, green: 161/255, blue: 78/255),
                Color(red: 33/255, green: 110/255, blue: 57/255),
            ]
        case .halloween:
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 255/255, green: 238/255, blue: 74/255),
                Color(red: 255/255, green: 197/255, blue: 1/255),
                Color(red: 254/255, green: 150/255, blue: 0/255),
                Color(red: 200/255, green: 50/255, blue: 0/255),
            ]
        case .teal:
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 126/255, green: 229/255, blue: 229/255),
                Color(red: 45/255, green: 197/255, blue: 197/255),
                Color(red: 13/255, green: 158/255, blue: 158/255),
                Color(red: 14/255, green: 109/255, blue: 109/255),
            ]
        case .blue:
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 121/255, green: 184/255, blue: 255/255),
                Color(red: 56/255, green: 139/255, blue: 253/255),
                Color(red: 31/255, green: 111/255, blue: 235/255),
                Color(red: 13/255, green: 65/255, blue: 157/255),
            ]
        case .pink:
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 240/255, green: 181/255, blue: 210/255),
                Color(red: 217/255, green: 97/255, blue: 160/255),
                Color(red: 191/255, green: 75/255, blue: 138/255),
                Color(red: 153/255, green: 40/255, blue: 110/255),
            ]
        case .purple:
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 205/255, green: 180/255, blue: 255/255),
                Color(red: 163/255, green: 113/255, blue: 247/255),
                Color(red: 137/255, green: 87/255, blue: 229/255),
                Color(red: 110/255, green: 64/255, blue: 201/255),
            ]
        case .orange:
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 255/255, green: 214/255, blue: 153/255),
                Color(red: 255/255, green: 179/255, blue: 71/255),
                Color(red: 255/255, green: 140/255, blue: 0/255),
                Color(red: 204/255, green: 85/255, blue: 0/255),
            ]
        case .monochrome:
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 100/255, green: 100/255, blue: 100/255),
                Color(red: 145/255, green: 145/255, blue: 145/255),
                Color(red: 190/255, green: 190/255, blue: 190/255),
                Color(red: 220/255, green: 220/255, blue: 220/255),
            ]
        case .ylgnbu:
            colors = [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 161/255, green: 218/255, blue: 180/255),
                Color(red: 65/255, green: 182/255, blue: 196/255),
                Color(red: 44/255, green: 127/255, blue: 184/255),
                Color(red: 37/255, green: 52/255, blue: 148/255),
            ]
        }
        return Theme(name: name, colors: colors, accent: .cyan)
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
