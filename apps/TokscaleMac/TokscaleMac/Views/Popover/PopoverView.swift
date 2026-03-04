import SwiftUI

enum TimePeriod: String, CaseIterable {
    case today = "Day"
    case week = "Week"
    case month = "Month"
    case all = "All"
}

// MARK: - Custom Colors for New Design
enum PopoverColors {
    static let bg = Color(white: 0.12)
    static let panelBg = Color(white: 0.16)
    static let textMain = Color.white
    static let textSecondary = Color(white: 0.6)
    static let greenAccent = Color(red: 52/255, green: 199/255, blue: 89/255) // vibrant green
    static let segmentedBg = Color(white: 0.18)
    static let segmentedSelected = Color(white: 0.35)
    static let divider = Color(white: 0.25)
}

/// Compact menu bar popover matching the new native design mockup.
struct PopoverView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var period: TimePeriod = .today

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header (Title + Segmented Picker)
            HStack {
                Text("TokenTrack")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(PopoverColors.textMain)
                
                Spacer(minLength: 4)
                
                // Custom Segmented Control - Extra Slim
                HStack(spacing: 0) {
                    ForEach(TimePeriod.allCases, id: \.self) { p in
                        Button(action: { period = p }) {
                            Text(p.rawValue)
                                .font(.system(size: 10, weight: period == p ? .semibold : .regular))
                                .foregroundStyle(period == p ? PopoverColors.textMain : PopoverColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(period == p ? PopoverColors.segmentedSelected : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(1)
                .background(PopoverColors.segmentedBg)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(white: 0.25), lineWidth: 0.5))
            }
            .padding(.horizontal, 12)
            .padding(.top, 8) // Reduced from 12
            .padding(.bottom, 6) // Reduced from 10
            
            Divider().background(PopoverColors.divider)

            let summary = store.summaryForPeriod(period)

            // MARK: - Big Numbers
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total Tokens")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverColors.textSecondary)
                    Text(formatLargeNumber(summary.totalTokens))
                        .font(.system(size: 24, weight: .bold)) // Reduced from 28
                        .foregroundStyle(PopoverColors.textMain)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total Cost")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverColors.textSecondary)
                    Text(Formatting.formatCost(summary.totalCost))
                        .font(.system(size: 24, weight: .bold)) // Reduced from 28
                        .foregroundStyle(PopoverColors.greenAccent)
                }
                .frame(width: 110, alignment: .leading) // Increased from 90 to support 3-digit amounts
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6) // Reduced from 10

            // MARK: - Client List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) { // Reduced spacing from 6
                    if summary.clients.isEmpty {
                        Text("No activity")
                            .font(.system(size: 11))
                            .foregroundStyle(PopoverColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(summary.clients) { c in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(AppColors.clientColor(c.client))
                                    .frame(width: 6, height: 6)
                                
                                Text(AppColors.clientDisplayName(c.client))
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .foregroundStyle(PopoverColors.textMain)
                                
                                Spacer(minLength: 4)
                                
                                Text(formatLargeNumber(c.tokens))
                                    .font(.system(size: 11, design: .monospaced)) 
                                    .lineLimit(1)
                                    .foregroundStyle(PopoverColors.textMain)
                                    .frame(width: 44, alignment: .leading)
                                
                                HStack(spacing: 2) {
                                    Text(Formatting.formatCost(c.cost))
                                        .font(.system(size: 11, design: .monospaced))
                                        .lineLimit(1)
                                        .foregroundStyle(PopoverColors.textMain)
                                    Text("tok")
                                        .font(.system(size: 9)) 
                                        .foregroundStyle(PopoverColors.textSecondary)
                                }
                                .frame(width: 68, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            // Reduced bottom padding for the list to give more room to the footer
            .padding(.bottom, 4) 
            
            Spacer(minLength: 0)

            // MARK: - Continuous Bar Chart
            ContinuousBarChart(summary: summary)
                .frame(height: 8) 
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            // MARK: - Footer
            Divider().background(PopoverColors.divider)
            HStack {
                Button(action: {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }) {
                    Text("dashboard →")
                        .font(.system(size: 11, weight: .medium)) // Bolder font
                        .foregroundStyle(Color.white.opacity(0.85)) // Brighter, clearer color than textSecondary
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2) // Extra touch area
                
                Spacer()
                
                if let last = store.lastRefresh {
                    Text(timeAgo(last))
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverColors.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8) // Increased vertical padding to make footer taller and clearer
        }
        .frame(width: 300, height: 200) 
        .background(PopoverColors.bg)
        .preferredColorScheme(.dark)
        .task { await store.refreshAll() }
    }
    
    // Custom number formatter to match "48.5M", "730K"
    private func formatLargeNumber(_ num: Int64) -> String {
        let d = Double(num)
        if d >= 1_000_000 {
            return String(format: "%.1fM", d / 1_000_000)
        } else if d >= 1_000 {
            return String(format: "%.0fK", d / 1_000)
        } else {
            return "\(num)"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "\(s)s ago" }
        if s < 3600 { return "\(s / 60)m ago" }
        return "\(s / 3600)h ago"
    }
}

// MARK: - Continuous Stacked Bar
struct ContinuousBarChart: View {
    let summary: TodaySummary
    
    var body: some View {
        GeometryReader { geo in
            let total = max(Double(summary.totalTokens), 1.0)
            let width = geo.size.width
            
            HStack(spacing: 2) {
                if summary.clients.isEmpty {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(PopoverColors.panelBg)
                } else {
                    ForEach(summary.clients) { c in
                        let w = width * (Double(c.tokens) / total)
                        if w > 1 { // Only show if at least 1pt wide
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppColors.clientColor(c.client))
                                .frame(width: w)
                        }
                    }
                }
                
                Spacer(minLength: 0)
                
                Text(summary.periodLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverColors.textSecondary)
                    .padding(.leading, 4)
            }
        }
    }
}

extension TodaySummary {
    var periodLabel: String {
        // Just a static label for the chart
        "24h" // We can make this dynamic based on the selected period if needed
    }
}
