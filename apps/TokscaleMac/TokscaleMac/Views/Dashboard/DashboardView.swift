import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case models = "Models"
    case daily = "Daily"
    case stats = "Stats"

    var id: String { rawValue }
}

enum SortField: String, CaseIterable {
    case cost = "Cost"
    case tokens = "Tokens"
    case date = "Date"
}

enum SortDirection {
    case ascending, descending
    mutating func toggle() { self = self == .ascending ? .descending : .ascending }
}

/// Main dashboard window with 4 tabs matching the CLI TUI.
struct DashboardView: View {
    @Environment(DataStore.self) private var store
    @State private var currentTab: DashboardTab = .overview
    @State private var sortField: SortField = .cost
    @State private var sortDirection: SortDirection = .descending
    @State private var refreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar with tabs
            headerBar

            // Content area
            Group {
                switch currentTab {
                case .overview:
                    OverviewTab(sortField: $sortField, sortDirection: $sortDirection)
                case .models:
                    ModelsTab(sortField: $sortField, sortDirection: $sortDirection)
                case .daily:
                    DailyTab(sortField: $sortField, sortDirection: $sortDirection)
                case .stats:
                    StatsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Footer (status bar)
            footerBar
        }
        .background(AppColors.background)
        .preferredColorScheme(.dark)
        .task { await store.refreshAll() }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 0) {
            Text(" TokenTrack ")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(store.currentTheme.accent)

            Spacer().frame(width: 12)

            ForEach(DashboardTab.allCases) { tab in
                Button(action: { currentTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: currentTab == tab ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(currentTab == tab ? store.currentTheme.accent : AppColors.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if tab != DashboardTab.allCases.last {
                    Text("│").foregroundStyle(AppColors.border).font(.system(size: 12, design: .monospaced))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.background)
        .overlay(alignment: .bottom) { Rectangle().fill(AppColors.border).frame(height: 1) }
    }

    // MARK: - Footer
    private var footerBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AppColors.border).frame(height: 1)

            VStack(spacing: 2) {
                // Row 1: Sort + Totals
                HStack {
                    // Sort buttons
                    HStack(spacing: 4) {
                        Text("Sort:").font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColors.muted)
                        ForEach(SortField.allCases, id: \.self) { field in
                            Button(action: {
                                if sortField == field { sortDirection.toggle() } else { sortField = field; sortDirection = .descending }
                            }) {
                                Text(field.rawValue)
                                    .font(.system(size: 11, weight: sortField == field ? .bold : .regular, design: .monospaced))
                                    .foregroundStyle(sortField == field ? AppColors.foreground : AppColors.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    // Totals
                    HStack(spacing: 4) {
                        Text(Formatting.formatTokens(store.modelReport?.entries.reduce(0) { $0 + $1.totalTokens } ?? 0))
                            .foregroundStyle(.cyan)
                        Text("tokens").foregroundStyle(AppColors.muted)
                        Text("|").foregroundStyle(AppColors.muted)
                        Text(Formatting.formatCost(store.modelReport?.totalCost ?? 0))
                            .foregroundStyle(.green).fontWeight(.bold)
                        Text("(\(store.modelReport?.entries.count ?? 0) models)")
                            .foregroundStyle(AppColors.muted)
                    }
                    .font(.system(size: 11, design: .monospaced))
                }

                // Row 2: Help
                HStack {
                    Text("↑↓ scroll • ←→ view • [p:\(store.currentTheme.name.rawValue)] • [r:refresh] • q")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppColors.muted)
                    Spacer()
                }

                // Row 3: Status
                HStack {
                    if store.isLoading {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text("Scanning sources...").foregroundStyle(AppColors.muted)
                        }
                    } else if let last = store.lastRefresh {
                        Text("Last updated: \(timeAgo(last))").foregroundStyle(AppColors.muted)
                    }
                    Spacer()
                    Button(action: { store.cycleTheme() }) {
                        Text("🎨 \(store.currentTheme.name.displayName)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)

                    Button(action: { Task { refreshing = true; await store.refreshAll(); refreshing = false } }) {
                        Text(refreshing ? "⏳" : "↻ Refresh")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    .disabled(refreshing)
                }
                .font(.system(size: 11, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
