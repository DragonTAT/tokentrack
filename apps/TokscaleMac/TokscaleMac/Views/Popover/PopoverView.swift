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
                    Text(Formatting.formatTokens(summary.totalTokens))
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
                                
                                Text(Formatting.formatTokens(c.tokens))
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
            ContinuousBarChart(summary: summary, theme: theme, period: period)
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
                    Text(Formatting.timeAgo(last))
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
    }
}

// MARK: - Continuous Stacked Bar
struct ContinuousBarChart: View {
    let summary: TodaySummary
    let theme: Theme
    let period: TimePeriod
    
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
                
                Text(periodLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray)
                    .padding(.leading, 4)
            }
        }
    }

    private var periodLabel: String {
        switch period {
        case .today: return "24h"
        case .week: return "7d"
        case .month: return "30d"
        case .all: return "All"
        }
    }
}
