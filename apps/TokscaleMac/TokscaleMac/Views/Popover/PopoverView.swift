import SwiftUI

enum TimePeriod: String, CaseIterable {
    case today = "Day"
    case week = "Week"
    case month = "Month"
    case all = "All"
}

// Used previously, now deleted in favor of dynamic theme.

/// Compact menu bar popover matching the new native design mockup.
struct PopoverView: View {
    @Environment(\.theme) private var theme
    @Environment(DataStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var period: TimePeriod = .today

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header (Title + Segmented Picker)
            HStack {
                Text("TokenTrack")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(theme.foreground)
                
                Spacer(minLength: 4)
                
                // Custom Segmented Control - Extra Slim
                HStack(spacing: 0) {
                    ForEach(TimePeriod.allCases, id: \.self) { p in
                        Button(action: { period = p }) {
                            Text(p.rawValue)
                                .font(.system(size: 10, weight: period == p ? .semibold : .regular))
                                .foregroundStyle(period == p ? theme.foreground : theme.secondaryForeground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(period == p ? theme.selection : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(1)
                .background(theme.stripedRow) // Use stripeRow or selection style
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.border, lineWidth: 0.5))
            }
            .padding(.horizontal, 12)
            .padding(.top, 8) // Reduced from 12
            .padding(.bottom, 6) // Reduced from 10
            
            Divider().background(theme.border)

            let summary = store.summaryForPeriod(period)

            // MARK: - Big Numbers
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total Tokens")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.secondaryForeground)
                    Text(formatLargeNumber(summary.totalTokens))
                        .font(.system(size: 24, weight: .bold)) // Reduced from 28
                        .foregroundStyle(theme.foreground)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total Cost")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.secondaryForeground)
                    Text(Formatting.formatCost(summary.totalCost))
                        .font(.system(size: 24, weight: .bold)) // Reduced from 28
                        .foregroundStyle(Color.green)
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
                            .foregroundStyle(theme.secondaryForeground)
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
                                    .foregroundStyle(theme.foreground)
                                
                                Spacer(minLength: 4)
                                
                                Text(formatLargeNumber(c.tokens))
                                    .font(.system(size: 11, design: .monospaced)) 
                                    .lineLimit(1)
                                    .foregroundStyle(theme.foreground)
                                    .frame(width: 44, alignment: .leading)
                                
                                HStack(spacing: 2) {
                                    Text(Formatting.formatCost(c.cost))
                                        .font(.system(size: 11, design: .monospaced))
                                        .lineLimit(1)
                                        .foregroundStyle(theme.foreground)
                                    Text("tok")
                                        .font(.system(size: 9)) 
                                        .foregroundStyle(theme.secondaryForeground)
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
            ContinuousBarChart(summary: summary, theme: theme)
                .frame(height: 8) 
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            // MARK: - Footer
            Divider().background(theme.border)
            HStack {
                Button(action: {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }) {
                    Text("dashboard →")
                        .font(.system(size: 11, weight: .medium)) // Bolder font
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2) // Extra touch area
                
                Spacer()
                
                if let last = store.lastRefresh {
                    Text(timeAgo(last))
                        .font(.system(size: 10))
                        .foregroundStyle(theme.secondaryForeground)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8) // Increased vertical padding to make footer taller and clearer
        }
        .frame(width: 300, height: 200) 
        .background(theme.panelBackground)
        .foregroundStyle(theme.foreground)
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
    let theme: Theme // Added theme property
    
    var body: some View {
        GeometryReader { geo in
            let total = max(Double(summary.totalTokens), 1.0)
            let width = geo.size.width
            
            HStack(spacing: 2) {
                if summary.clients.isEmpty {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.border) // Fallback if no clients
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
                    .foregroundStyle(Color.gray)
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
