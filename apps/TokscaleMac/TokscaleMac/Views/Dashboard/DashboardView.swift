import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case models = "Models"
    case daily = "Daily"
    case stats = "Stats"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "chart.pie.fill"
        case .models: return "server.rack"
        case .daily: return "calendar"
        case .stats: return "chart.bar.xaxis"
        }
    }
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

/// Main dashboard window with a modern macOS native sidebar navigation.
struct DashboardView: View {
    @Environment(DataStore.self) private var store
    @State private var currentTab: DashboardTab = .overview
    @State private var sortField: SortField = .cost
    @State private var sortDirection: SortDirection = .descending
    @State private var refreshing = false

    var body: some View {
        NavigationSplitView {
            // MARK: - Sidebar
            List(selection: $currentTab) {
                Text("TokenTrack")
                    .font(.headline)
                    .foregroundStyle(store.currentTheme.accent)
                    .padding(.vertical, 8)
                
                ForEach(DashboardTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            
        } detail: {
            // MARK: - Detail Content Area
            VStack(spacing: 0) {
                // Content View
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
            .background(Color(NSColor.windowBackgroundColor)) // Native macOS background
        }
        .preferredColorScheme(.dark)
        .task { await store.refreshAll() }
        .toolbar {
            // Adds a refresh button to the native toolbar
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        refreshing = true
                        await store.refreshAll()
                        refreshing = false
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .symbolEffect(.bounce, value: refreshing)
                }
                .disabled(refreshing)
            }
        }
    }

    // MARK: - Footer
    private var footerBar: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 4) {
                // Row 1: Sort + Totals
                HStack(alignment: .center) {
                    // Sort Buttons Group
                    HStack(spacing: 8) {
                        Text("Sort:").font(.system(size: 11)).foregroundStyle(.secondary)
                        
                        Picker("", selection: $sortField) {
                            ForEach(SortField.allCases, id: \.self) { field in
                                Text(field.rawValue).tag(field)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 160)
                        
                        Button(action: { sortDirection.toggle() }) {
                            Image(systemName: sortDirection == .descending ? "arrow.down" : "arrow.up")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Totals
                    HStack(spacing: 6) {
                        Text(Formatting.formatTokens(store.modelReport?.entries.reduce(0) { $0 + $1.totalTokens } ?? 0))
                            .foregroundStyle(.cyan)
                            .font(.system(size: 12, design: .monospaced))
                        Text("tokens").foregroundStyle(.secondary).font(.system(size: 11))
                        
                        Text("│").foregroundStyle(.tertiary)
                        
                        Text(Formatting.formatCost(store.modelReport?.totalCost ?? 0))
                            .foregroundStyle(.green).fontWeight(.semibold)
                            .font(.system(size: 12, design: .monospaced))
                        Text("(\(store.modelReport?.entries.count ?? 0) models)")
                            .foregroundStyle(.secondary).font(.system(size: 11))
                    }
                }

                // Row 2: Status
                HStack {
                    if store.isLoading {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text("Scanning sources...").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    } else if let last = store.lastRefresh {
                        Text("Last updated: \(timeAgo(last))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { store.cycleTheme() }) {
                        Label(store.currentTheme.name.displayName, systemImage: "paintpalette.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(store.currentTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
