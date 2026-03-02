import SwiftUI

/// Daily usage tab: table with Date/Input/Output/CacheRead/CacheWrite/Total/Cost.
struct DailyTab: View {
    @Environment(DataStore.self) private var store
    @Binding var sortField: SortField
    @Binding var sortDirection: SortDirection
    @State private var selectedIndex: Int? = nil

    var body: some View {
        let daily = sortedDaily

        if daily.isEmpty {
            Text("No daily usage data found. Click refresh to reload.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Header
                headerRow

                // Table body
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(daily.enumerated()), id: \.offset) { idx, day in
                            dailyRow(idx: idx, day: day)
                                .background(
                                    selectedIndex == idx
                                        ? AppColors.selection
                                        : (idx % 2 == 1 ? AppColors.stripedRow : Color.clear)
                                )
                                .onTapGesture { selectedIndex = idx }
                        }
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.border, lineWidth: 1))
            .padding(4)
        }
    }

    // MARK: - Header
    private var headerRow: some View {
        HStack(spacing: 0) {
            headerCell("Date" + (sortField == .date ? (sortDirection == .ascending ? " ▲" : " ▼") : ""),
                       width: 100, field: .date)
            headerCell("Input", width: 80, field: nil)
            headerCell("Output", width: 80, field: nil)
            headerCell("Cache Read", width: 90, field: nil)
            headerCell("Cache Write", width: 90, field: nil)
            headerCell("Total" + (sortField == .tokens ? (sortDirection == .ascending ? " ▲" : " ▼") : ""),
                       width: 80, field: .tokens)
            headerCell("Cost" + (sortField == .cost ? (sortDirection == .ascending ? " ▲" : " ▼") : ""),
                       width: 80, field: .cost)
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(store.currentTheme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.background)
        .overlay(alignment: .bottom) { Rectangle().fill(AppColors.border).frame(height: 1) }
    }

    private func headerCell(_ text: String, width: CGFloat, field: SortField?) -> some View {
        Text(text)
            .frame(width: width, alignment: field == .date ? .leading : .trailing)
            .lineLimit(1)
            .onTapGesture {
                if let f = field {
                    if sortField == f { sortDirection.toggle() } else { sortField = f; sortDirection = .descending }
                }
            }
    }

    // MARK: - Row
    private func dailyRow(idx: Int, day: DailyContribution) -> some View {
        HStack(spacing: 0) {
            Text(day.date)
                .frame(width: 100, alignment: .leading)
                .fontWeight(.bold)

            Text(Formatting.formatTokens(day.tokenBreakdown.input))
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(AppColors.inputTokens)

            Text(Formatting.formatTokens(day.tokenBreakdown.output))
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(AppColors.outputTokens)

            Text(Formatting.formatTokens(day.tokenBreakdown.cacheRead))
                .frame(width: 90, alignment: .trailing)
                .foregroundStyle(AppColors.cacheReadTokens)

            Text(Formatting.formatTokens(day.tokenBreakdown.cacheWrite))
                .frame(width: 90, alignment: .trailing)
                .foregroundStyle(AppColors.cacheWriteTokens)

            Text(Formatting.formatTokens(day.totals.tokens))
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(AppColors.foreground)

            Text(Formatting.formatCost(day.totals.cost))
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.green)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    // MARK: - Sorting
    private var sortedDaily: [DailyContribution] {
        guard let contributions = store.graphResult?.contributions else { return [] }
        let active = contributions.filter { $0.totals.tokens > 0 }
        return active.sorted { a, b in
            let result: Bool
            switch sortField {
            case .date: result = a.date > b.date
            case .cost: result = a.totals.cost > b.totals.cost
            case .tokens: result = a.totals.tokens > b.totals.tokens
            }
            return sortDirection == .descending ? result : !result
        }
    }
}
