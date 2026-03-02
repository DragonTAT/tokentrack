import SwiftUI

/// Daily usage tab using native macOS Table for proper column resizing and sorting behavior.
struct DailyTab: View {
    @Environment(DataStore.self) private var store
    @Binding var sortField: SortField
    @Binding var sortDirection: SortDirection
    @State private var selectedDayID: DailyContribution.ID?

    var body: some View {
        let daily = sortedDaily

        if daily.isEmpty {
            Text("No daily usage data found. Click refresh to reload.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { proxy in
                let layout = DailyColumnLayout.compute(availableWidth: proxy.size.width)

                Group {
                    if layout.showsCacheColumns {
                        fullTable(days: daily, layout: layout)
                    } else {
                        compactTable(days: daily, layout: layout)
                    }
                }
                .id("daily-\(layout.showsCacheColumns)")
                .frame(width: proxy.size.width, height: proxy.size.height)
                .tableStyle(.inset) // Standard macOS Table style
                .font(.system(size: 12)) // Slightly larger than before for better readability natively
                // Setting a background on the table container keeps it consistent with macOS aesthetics
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    private func fullTable(days: [DailyContribution], layout: DailyColumnLayout) -> some View {
        Table(days, selection: $selectedDayID) {
            // Date Column
            TableColumn("Date") { day in
                dateCell(for: day.date)
            }
            .width(min: 50, ideal: layout.date)

            // Input Column
            TableColumn("Input") { day in
                Text(Formatting.formatTokens(day.tokenBreakdown.input))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AppColors.inputTokens)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 26, ideal: layout.input)

            // Output Column
            TableColumn("Output") { day in
                Text(Formatting.formatTokens(day.tokenBreakdown.output))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AppColors.outputTokens)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 26, ideal: layout.output)

            // Cache Read Column
            TableColumn("Cache Read") { day in
                Text(Formatting.formatTokens(day.tokenBreakdown.cacheRead))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AppColors.cacheReadTokens)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 38, ideal: layout.cacheRead)

            // Cache Write Column
            TableColumn("Cache Write") { day in
                Text(Formatting.formatTokens(day.tokenBreakdown.cacheWrite))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AppColors.cacheWriteTokens)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 38, ideal: layout.cacheWrite)

            // Total Tokens Column
            TableColumn("Total Tokens") { day in
                Text(Formatting.formatTokens(day.totals.tokens))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 43, ideal: layout.totalTokens)

            // Cost Column
            TableColumn("Cost") { day in
                Text(Formatting.formatCost(day.totals.cost))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 49, ideal: layout.cost)
        }
    }

    private func compactTable(days: [DailyContribution], layout: DailyColumnLayout) -> some View {
        Table(days, selection: $selectedDayID) {
            // Date Column
            TableColumn("Date") { day in
                dateCell(for: day.date)
            }
            .width(min: 50, ideal: layout.date)

            // Input Column
            TableColumn("Input") { day in
                Text(Formatting.formatTokens(day.tokenBreakdown.input))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AppColors.inputTokens)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 26, ideal: layout.input)

            // Output Column
            TableColumn("Output") { day in
                Text(Formatting.formatTokens(day.tokenBreakdown.output))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AppColors.outputTokens)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 26, ideal: layout.output)

            // Total Tokens Column
            TableColumn("Total Tokens") { day in
                Text(Formatting.formatTokens(day.totals.tokens))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 43, ideal: layout.totalTokens)

            // Cost Column
            TableColumn("Cost") { day in
                Text(Formatting.formatCost(day.totals.cost))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 49, ideal: layout.cost)
        }
    }

    private func dateCell(for date: String) -> some View {
        Text(date)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
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

private struct DailyColumnLayout {
    let showsCacheColumns: Bool
    let date: CGFloat
    let input: CGFloat
    let output: CGFloat
    let cacheRead: CGFloat
    let cacheWrite: CGFloat
    let totalTokens: CGFloat
    let cost: CGFloat

    static func compute(availableWidth: CGFloat) -> DailyColumnLayout {
        let usableWidth = max(availableWidth - 16, 280)

        let fullMin: [String: CGFloat] = [
            "date": 50,
            "input": 26,
            "output": 26,
            "cacheRead": 38,
            "cacheWrite": 38,
            "totalTokens": 43,
            "cost": 49,
        ]
        let fullIdeal: [String: CGFloat] = [
            "date": 150,
            "input": 95,
            "output": 95,
            "cacheRead": 108,
            "cacheWrite": 108,
            "totalTokens": 118,
            "cost": 96,
        ]
        let fullWeights: [String: CGFloat] = [
            "date": 3.2,
            "input": 1.4,
            "output": 1.4,
            "cacheRead": 1.1,
            "cacheWrite": 1.1,
            "totalTokens": 1.6,
            "cost": 1.2,
        ]

        let compactMin: [String: CGFloat] = [
            "date": 50,
            "input": 26,
            "output": 26,
            "totalTokens": 43,
            "cost": 49,
        ]
        let compactIdeal: [String: CGFloat] = [
            "date": 170,
            "input": 108,
            "output": 108,
            "totalTokens": 128,
            "cost": 108,
        ]
        let compactWeights: [String: CGFloat] = [
            "date": 3.8,
            "input": 1.7,
            "output": 1.7,
            "totalTokens": 1.9,
            "cost": 1.2,
        ]

        let fullMinimum = fullMin.values.reduce(0, +)
        let showCacheColumns = usableWidth >= fullMinimum

        if showCacheColumns {
            let widths = resolveWidths(
                min: fullMin,
                ideal: fullIdeal,
                weights: fullWeights,
                usableWidth: usableWidth
            )
            return DailyColumnLayout(
                showsCacheColumns: true,
                date: widths["date", default: fullIdeal["date", default: 150]],
                input: widths["input", default: fullIdeal["input", default: 95]],
                output: widths["output", default: fullIdeal["output", default: 95]],
                cacheRead: widths["cacheRead", default: fullIdeal["cacheRead", default: 108]],
                cacheWrite: widths["cacheWrite", default: fullIdeal["cacheWrite", default: 108]],
                totalTokens: widths["totalTokens", default: fullIdeal["totalTokens", default: 118]],
                cost: widths["cost", default: fullIdeal["cost", default: 96]]
            )
        }

        let widths = resolveWidths(
            min: compactMin,
            ideal: compactIdeal,
            weights: compactWeights,
            usableWidth: usableWidth
        )
        return DailyColumnLayout(
            showsCacheColumns: false,
            date: widths["date", default: compactIdeal["date", default: 170]],
            input: widths["input", default: compactIdeal["input", default: 108]],
            output: widths["output", default: compactIdeal["output", default: 108]],
            cacheRead: 0,
            cacheWrite: 0,
            totalTokens: widths["totalTokens", default: compactIdeal["totalTokens", default: 128]],
            cost: widths["cost", default: compactIdeal["cost", default: 108]]
        )
    }

    private static func resolveWidths(
        min: [String: CGFloat],
        ideal: [String: CGFloat],
        weights: [String: CGFloat],
        usableWidth: CGFloat
    ) -> [String: CGFloat] {
        let minTotal = min.values.reduce(0, +)
        let idealTotal = ideal.values.reduce(0, +)

        if usableWidth <= minTotal {
            return min
        }

        if usableWidth < idealTotal {
            let progress = (usableWidth - minTotal) / max(idealTotal - minTotal, 0.0001)
            var result: [String: CGFloat] = [:]
            for (key, idealWidth) in ideal {
                let minWidth = min[key, default: idealWidth]
                result[key] = minWidth + ((idealWidth - minWidth) * progress)
            }
            return result
        }

        let extra = usableWidth - idealTotal
        let totalWeight = max(weights.values.reduce(0, +), 0.0001)

        var result = ideal
        for (key, idealWidth) in ideal {
            let weight = weights[key, default: 1]
            result[key] = idealWidth + (extra * (weight / totalWeight))
        }
        return result
    }
}
