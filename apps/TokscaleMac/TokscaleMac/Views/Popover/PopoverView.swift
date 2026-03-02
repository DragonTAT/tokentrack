import SwiftUI

enum TimePeriod: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
}

/// Compact menu bar popover with today/week/month toggle.
struct PopoverView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var refreshing = false
    @State private var period: TimePeriod = .today

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("TokenTrack")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 88/255, green: 166/255, blue: 255/255))

                Spacer()

                // Period toggle
                HStack(spacing: 0) {
                    ForEach(TimePeriod.allCases, id: \.self) { p in
                        Button(action: { period = p }) {
                            Text(p.rawValue)
                                .font(.system(size: 10, weight: period == p ? .bold : .regular, design: .monospaced))
                                .foregroundStyle(period == p ? .white : AppColors.muted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(period == p ? Color(white: 0.25) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.border, lineWidth: 1))

                Button(action: { Task { refreshing = true; await store.refreshAll(); refreshing = false } }) {
                    Text(refreshing ? "…" : "↻").font(.system(size: 12, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Divider().background(AppColors.border) }

            if let error = store.error {
                VStack(spacing: 4) {
                    Text("⚠️ \(error)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                Spacer()
            } else {
                let summary = store.summaryForPeriod(period)
                VStack(spacing: 6) {
                    // Token + Cost row
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Formatting.formatTokens(summary.totalTokens))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppColors.foreground)
                            Text("tokens").font(.system(size: 9, design: .monospaced)).foregroundStyle(AppColors.muted)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Formatting.formatCost(summary.totalCost))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                            Text("cost").font(.system(size: 9, design: .monospaced)).foregroundStyle(AppColors.muted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    // Client breakdown
                    if summary.clients.isEmpty {
                        Text("no activity")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppColors.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    } else {
                        VStack(spacing: 2) {
                            ForEach(summary.clients) { c in
                                HStack(spacing: 5) {
                                    Circle().fill(AppColors.clientColor(c.client)).frame(width: 5, height: 5)
                                    Text(AppColors.clientDisplayName(c.client))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(AppColors.muted)
                                    Spacer()
                                    Text(Formatting.formatTokens(c.tokens))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(AppColors.foreground)
                                    Text(Formatting.formatCost(c.cost))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.green)
                                        .frame(width: 52, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                    }

                    // Mini graph
                    MiniGraphView()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
            }

            Spacer(minLength: 0)

            // Footer
            Divider().background(AppColors.border)
            HStack {
                Button("dashboard →") {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(red: 56/255, green: 139/255, blue: 253/255))
                Spacer()
                if let last = store.lastRefresh {
                    Text(timeAgo(last))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AppColors.muted)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
        }
        .frame(width: 300, height: 200)
        .background(AppColors.background)
        .preferredColorScheme(.dark)
        .task { await store.refreshAll() }
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "\(s)s ago" }
        if s < 3600 { return "\(s / 60)m ago" }
        return "\(s / 3600)h ago"
    }
}
