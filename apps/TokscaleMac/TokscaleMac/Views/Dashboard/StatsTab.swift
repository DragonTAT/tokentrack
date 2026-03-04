import SwiftUI

/// Stats tab: 52-week contribution graph (top) + stats/breakdown panel (bottom).
struct StatsTab: View {
    @Environment(\.theme) private var theme
    @Environment(DataStore.self) private var store
    @State private var selectedCell: (week: Int, day: Int)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Top: Contribution Graph
            VStack(spacing: 0) {
                HStack {
                    Text(" Contribution Graph (52 weeks) ")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.accent)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) { Rectangle().fill(theme.border).frame(height: 1) }

                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 0) {
                            ContribGraphView(selectedCell: $selectedCell)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)

                            Color.clear
                                .frame(width: 1, height: 1)
                                .id("graph-end")
                        }
                    }
                    .onAppear {
                        scrollGraphToRight(scrollProxy)
                    }
                    .onChange(of: store.graphGrid?.weeks.count ?? 0) {
                        scrollGraphToRight(scrollProxy)
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 1))
            .frame(maxHeight: .infinity)
            .padding(4)

            // Bottom: Stats or Day Breakdown
            if selectedCell != nil {
                dayBreakdownPanel
                    .frame(height: 200)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            } else {
                statsPanel
                    .frame(height: 200)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }
        }
    }

    private func scrollGraphToRight(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.none) {
                proxy.scrollTo("graph-end", anchor: .trailing)
            }
        }
    }

    // MARK: - Stats Panel
    private var statsPanel: some View {
        let graph = store.graphResult
        let totalTokens = graph?.summary.totalTokens ?? 0
        let totalCost = graph?.summary.totalCost ?? 0
        let activeDays = graph?.summary.activeDays ?? 0
        let totalDays = graph?.summary.totalDays ?? 365
        let favoriteModel = store.modelReport?.entries.max(by: { $0.cost < $1.cost })?.model ?? "N/A"
        let sessions = store.totalSessions

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(" Stats ")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.accent)
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(theme.border).frame(height: 1) }

            VStack(alignment: .leading, spacing: 2) {
                // Row 1
                HStack(spacing: 0) {
                    statLine("Favorite model:", value: favoriteModel, color: AppColors.modelColor(favoriteModel), maxW: 320)
                    statLine("Total tokens:", value: Formatting.formatTokens(totalTokens), color: .cyan, maxW: nil)
                }
                // Row 2
                HStack(spacing: 0) {
                    statLine("Sessions:", value: "\(sessions)", color: .cyan, maxW: 320)
                    statLine("Total cost:", value: Formatting.formatCost(totalCost), color: .green, maxW: nil)
                }
                // Row 3
                HStack(spacing: 0) {
                    statLine("Current streak:", value: "\(store.currentStreak) days", color: .cyan, maxW: 320)
                    statLine("Longest streak:", value: "\(store.longestStreak) days", color: .cyan, maxW: nil)
                }
                // Row 4
                statLine("Active days:", value: "\(activeDays)/\(totalDays)", color: .cyan, maxW: 320)

                Spacer().frame(height: 8)

                // Legend
                HStack(spacing: 4) {
                    Text("Less").font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.secondaryForeground)
                    Text("·").foregroundStyle(theme.border)
                    ForEach(1..<5) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.colors[i])
                            .frame(width: 12, height: 12)
                    }
                    Text("More").font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.secondaryForeground)
                }

                Spacer().frame(height: 8)

                Text("Your total spending is \(Formatting.formatCost(totalCost)) on AI coding assistants!")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .italic()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 1))
    }

    private func statLine(_ label: String, value: String, color: Color, maxW: CGFloat?) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(theme.secondaryForeground)
            Text(value).foregroundStyle(color)
            if maxW != nil { Spacer() }
        }
        .font(.system(size: 12, design: .monospaced))
        .frame(width: maxW, alignment: .leading)
    }

    // MARK: - Day Breakdown Panel
    private var dayBreakdownPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(" Day Breakdown ")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.accent)
                Spacer()
                Button("✕ Close") {
                    selectedCell = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.secondaryForeground)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(theme.border).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if let (wi, di) = selectedCell,
                       let grid = store.graphGrid,
                       wi < grid.weeks.count && di < grid.weeks[wi].count,
                       let day = grid.weeks[wi][di] {
                        // Date + tokens + cost
                        HStack(spacing: 12) {
                            Text(day.date)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(theme.foreground)
                            Text(Formatting.formatTokens(day.tokens))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.cyan)
                            Text(Formatting.formatCost(day.cost))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(.bottom, 4)

                        // Group by client
                        let grouped = Dictionary(grouping: day.clients, by: \.client)
                        ForEach(Array(grouped.keys.sorted()), id: \.self) { client in
                            let models = grouped[client]!
                            HStack(spacing: 4) {
                                Circle().fill(AppColors.clientColor(client)).frame(width: 8, height: 8)
                                Text(AppColors.clientDisplayName(client))
                                    .fontWeight(.bold)
                                    .foregroundStyle(AppColors.clientColor(client))
                                Text("(\(models.count) model\(models.count > 1 ? "s" : ""))")
                                    .foregroundStyle(theme.secondaryForeground)
                            }
                            .font(.system(size: 12, design: .monospaced))

                            ForEach(Array(models.enumerated()), id: \.offset) { _, m in
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 4) {
                                        Text("  ")
                                        Circle().fill(AppColors.modelColor(m.modelId)).frame(width: 6, height: 6)
                                        Text(m.modelId).foregroundStyle(theme.foreground)
                                    }
                                    HStack(spacing: 0) {
                                        Text("    In: ").foregroundStyle(theme.secondaryForeground)
                                        Text(Formatting.formatTokens(m.tokens.input)).foregroundStyle(theme.foreground)
                                        Text(" · Out: ").foregroundStyle(theme.secondaryForeground)
                                        Text(Formatting.formatTokens(m.tokens.output)).foregroundStyle(theme.foreground)
                                        Text(" · CR: ").foregroundStyle(theme.secondaryForeground)
                                        Text(Formatting.formatTokens(m.tokens.cacheRead)).foregroundStyle(theme.foreground)
                                        Text(" · CW: ").foregroundStyle(theme.secondaryForeground)
                                        Text(Formatting.formatTokens(m.tokens.cacheWrite)).foregroundStyle(theme.foreground)
                                        Text(" · RS: ").foregroundStyle(theme.secondaryForeground)
                                        Text(Formatting.formatTokens(m.tokens.reasoning)).foregroundStyle(theme.foreground)
                                    }
                                }
                                .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    } else {
                        Text("No data for this day")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(theme.secondaryForeground)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 1))
    }
}
