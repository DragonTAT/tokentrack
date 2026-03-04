import Foundation

enum Formatting {
    static func formatTokens(_ tokens: Int64) -> String {
        if tokens >= 1_000_000_000 {
            return String(format: "%.1fB", Double(tokens) / 1_000_000_000)
        } else if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        } else {
            return formatWithCommas(tokens)
        }
    }

    static func formatCost(_ cost: Double) -> String {
        guard cost.isFinite && cost >= 0 else { return "$0.00" }
        if cost >= 1000 {
            return String(format: "$%.1fK", cost / 1000)
        } else if cost >= 0.01 {
            return String(format: "$%.2f", cost)
        } else if cost > 0 {
            return String(format: "$%.4f", cost)
        } else {
            return "$0.00"
        }
    }

    static func formatWithCommas(_ n: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
