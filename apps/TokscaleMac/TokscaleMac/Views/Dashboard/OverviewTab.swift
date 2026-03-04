import SwiftUI

/// Overview tab: stacked bar chart (top 35%) + legend + top models list.
/// When a bar is clicked, shows only that day's model usage.
struct OverviewTab: View {
    @Environment(\.theme) private var theme
    @Environment(DataStore.self) private var store
    @Binding var sortField: SortField
    @Binding var sortDirection: SortDirection
    @State private var selectedDate: String? = nil

    var body: some View {
        if store.isLoading && store.modelReport == nil {
            ProgressView("Loading...")
                .foregroundStyle(theme.secondaryForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geo in
                let chartHeight = max(geo.size.height * 0.35, 100)
                VStack(spacing: 0) {
                    // Stacked bar chart
                    StackedBarChart(sortField: sortField, selectedDate: $selectedDate)
                        .frame(height: chartHeight)
                        .padding(.horizontal, 4)

                    // Legend
                    legendRow
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)

                    // Top models list (filtered by selected date if any)
                    if let date = selectedDate {
                        dayModelsList(date: date)
                    } else {
                        topModelsList
                    }
                }
            }
        }
    }

    // MARK: - Legend
    private var legendRow: some View {
        HStack(spacing: 8) {
            let models = sortedModels.prefix(5)
            ForEach(Array(models.enumerated()), id: \.offset) { _, m in
                HStack(spacing: 3) {
                    Circle().fill(AppColors.modelColor(m.model)).frame(width: 6, height: 6)
                    Text(truncate(m.model, max: 18))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.foreground)
                }
            }
            Spacer()
        }
    }

    // MARK: - Day-specific Models (when a bar is clicked)
    private func dayModelsList(date: String) -> some View {
        let dayModels = modelsForDate(date)

        return VStack(spacing: 0) {
            // Title bar with close button
            HStack {
                Text(" \(date) ")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.accent)
                Text("(\(dayModels.count) models)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.secondaryForeground)
                Spacer()
                let totalCost = dayModels.reduce(0) { $0 + $1.cost }
                Text(Formatting.formatCost(totalCost))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                Text("  ")
                Button("✕") { selectedDate = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.secondaryForeground)
                    .font(.system(size: 12, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.panelBackground)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 1))

            // Day model rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(dayModels.enumerated()), id: \.offset) { idx, model in
                        let totalTokens = dayModels.reduce(Int64(0)) { $0 + $1.tokens.total }
                        let percentage = totalTokens > 0 ? Double(model.tokens.total) / Double(totalTokens) * 100 : 0
                        VStack(alignment: .leading, spacing: 1) {
                            // Line 1: ● model (xx.x%) — client
                            HStack(spacing: 4) {
                                Circle().fill(AppColors.modelColor(model.modelId)).frame(width: 8, height: 8)
                                Text(truncate(model.modelId, max: 35))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppColors.modelColor(model.modelId))
                                Text(String(format: "(%.1f%%)", percentage))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.secondaryForeground)
                                Text("·").foregroundStyle(theme.border)
                                Text(AppColors.clientDisplayName(model.client))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(AppColors.clientColor(model.client))
                                Spacer()
                                Text(Formatting.formatCost(model.cost))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.green)
                            }
                            // Line 2: In/Out/CR/CW
                            HStack(spacing: 0) {
                                Text("  In: ").foregroundStyle(theme.secondaryForeground)
                                Text(Formatting.formatTokens(model.tokens.input)).foregroundStyle(theme.foreground)
                                Text(" · Out: ").foregroundStyle(theme.secondaryForeground)
                                Text(Formatting.formatTokens(model.tokens.output)).foregroundStyle(theme.foreground)
                                Text(" · CR: ").foregroundStyle(theme.secondaryForeground)
                                Text(Formatting.formatTokens(model.tokens.cacheRead)).foregroundStyle(theme.foreground)
                                Text(" · CW: ").foregroundStyle(theme.secondaryForeground)
                                Text(Formatting.formatTokens(model.tokens.cacheWrite)).foregroundStyle(theme.foreground)
                                Spacer()
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(idx % 2 == 1 ? theme.stripedRow : .clear)
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 1))
        }
    }

    // MARK: - Top Models List (default, no date selected)
    private var topModelsList: some View {
        let models = sortedModels
        let totalCost = models.reduce(0.0) { $0 + $1.cost }

        return VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(sortField == .tokens ? " Models by Tokens " : " Models by Cost ")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.accent)
                Spacer()
                Text("Total: \(Formatting.formatCost(totalCost))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.panelBackground)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 1))

            // Model rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(models.enumerated()), id: \.element.id) { idx, model in
                        let percentage = totalCost > 0 ? (model.cost / totalCost) * 100 : 0
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Circle().fill(AppColors.modelColor(model.model)).frame(width: 8, height: 8)
                                Text(truncate(model.model, max: 35))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppColors.modelColor(model.model))
                                Text(String(format: "(%.1f%%)", percentage))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.secondaryForeground)
                                Spacer()
                                Text(Formatting.formatCost(model.cost))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.green)
                            }
                            HStack(spacing: 0) {
                                Text("  In: ").foregroundStyle(theme.secondaryForeground)
                                Text(Formatting.formatTokens(model.input)).foregroundStyle(theme.foreground)
                                Text(" · Out: ").foregroundStyle(theme.secondaryForeground)
                                Text(Formatting.formatTokens(model.output)).foregroundStyle(theme.foreground)
                                Text(" · CR: ").foregroundStyle(theme.secondaryForeground)
                                Text(Formatting.formatTokens(model.cacheRead)).foregroundStyle(theme.foreground)
                                Text(" · CW: ").foregroundStyle(theme.secondaryForeground)
                                Text(Formatting.formatTokens(model.cacheWrite)).foregroundStyle(theme.foreground)
                                Spacer()
                            }
                            .font(.system(size: 11, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(idx % 2 == 1 ? theme.stripedRow : .clear)
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 1))
        }
    }

    // MARK: - Data

    /// Get models for a specific date from graph contributions
    private func modelsForDate(_ date: String) -> [ClientContribution] {
        guard let graph = store.graphResult,
              let day = graph.contributions.first(where: { $0.date == date }) else {
            return []
        }
        return day.clients.sorted { $0.tokens.total > $1.tokens.total }
    }

    private var sortedModels: [ModelUsage] {
        guard let entries = store.modelReport?.entries else { return [] }
        return entries.sorted { a, b in
            let result: Bool
            switch sortField {
            case .cost: result = a.cost > b.cost
            case .tokens: result = a.totalTokens > b.totalTokens
            case .date: result = a.cost > b.cost
            }
            return sortDirection == .descending ? result : !result
        }
    }

    private func truncate(_ s: String, max: Int) -> String {
        s.count <= max ? s : String(s.prefix(max - 1)) + "…"
    }
}
