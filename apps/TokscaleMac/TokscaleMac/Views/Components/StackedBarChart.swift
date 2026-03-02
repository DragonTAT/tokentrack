import SwiftUI

/// Stacked bar chart showing daily token usage by model (last 60 days).
struct StackedBarChart: View {
    @Environment(DataStore.self) private var store
    let sortField: SortField
    @Binding var selectedDate: String?

    private let leftPadding: CGFloat = 52
    private let bottomPadding: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let data = chartData
            let maxTokens = max(data.map(\.totalTokens).max() ?? 1, 1)
            let chartWidth = geo.size.width - leftPadding - 8
            let chartHeight = geo.size.height - bottomPadding - 8
            let barWidth = max(2, chartWidth / CGFloat(max(data.count, 1)) - 1)

            Canvas { context, size in
                guard chartHeight > 10 else { return }

                // Y-axis labels (token scale)
                let ySteps = 4
                for i in 0...ySteps {
                    let frac = CGFloat(i) / CGFloat(ySteps)
                    let y = 4 + chartHeight * (1 - frac)
                    let tokenVal = Int64(Double(maxTokens) * Double(frac))
                    let label = Formatting.formatTokens(tokenVal)

                    context.draw(
                        Text(label)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(AppColors.muted),
                        at: CGPoint(x: leftPadding - 6, y: y),
                        anchor: .trailing
                    )

                    // Grid line
                    if i > 0 && i < ySteps {
                        var path = Path()
                        path.move(to: CGPoint(x: leftPadding, y: y))
                        path.addLine(to: CGPoint(x: leftPadding + chartWidth, y: y))
                        context.stroke(path, with: .color(AppColors.border.opacity(0.3)), lineWidth: 0.5)
                    }
                }

                // Bars
                for (i, day) in data.enumerated() {
                    let x = leftPadding + CGFloat(i) * (barWidth + 1)
                    let totalHeight = chartHeight * CGFloat(day.totalTokens) / CGFloat(maxTokens)
                    let isSelected = selectedDate == day.date

                    // Selection highlight background
                    if isSelected {
                        let bgRect = CGRect(x: x - 1, y: 4, width: barWidth + 2, height: chartHeight)
                        context.fill(
                            Rectangle().path(in: bgRect),
                            with: .color(AppColors.selection.opacity(0.5))
                        )
                    }

                    // Stack segments bottom to top
                    var y = 4 + chartHeight
                    for segment in day.segments {
                        let segHeight = totalHeight * CGFloat(segment.tokens) / CGFloat(max(day.totalTokens, 1))
                        if segHeight > 0.5 {
                            y -= segHeight
                            let rect = CGRect(x: x, y: y, width: barWidth, height: segHeight)
                            let color = AppColors.modelColor(segment.model)
                            context.fill(
                                RoundedRectangle(cornerRadius: 1).path(in: rect),
                                with: .color(isSelected ? color.opacity(1) : color.opacity(0.85))
                            )
                        }
                    }
                }

                // X-axis date labels (every ~10 bars)
                let labelInterval = max(1, data.count / 6)
                for (i, day) in data.enumerated() {
                    if i % labelInterval == 0 || i == data.count - 1 {
                        let x = leftPadding + CGFloat(i) * (barWidth + 1) + barWidth / 2
                        let y = 4 + chartHeight + 10
                        // Show MM/DD
                        let parts = day.date.split(separator: "-")
                        let label = parts.count >= 3 ? "\(parts[1])/\(parts[2])" : day.date
                        context.draw(
                            Text(label)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(AppColors.muted),
                            at: CGPoint(x: x, y: y),
                            anchor: .center
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let x = location.x - leftPadding
                let idx = Int(x / (barWidth + 1))
                if idx >= 0 && idx < data.count {
                    let tappedDate = data[idx].date
                    selectedDate = selectedDate == tappedDate ? nil : tappedDate
                }
            }
        }
    }

    // MARK: - Data

    struct BarSegment {
        let model: String
        let tokens: Int64
    }

    struct BarData {
        let date: String
        let segments: [BarSegment]
        let totalTokens: Int64
    }

    private var chartData: [BarData] {
        guard let graph = store.graphResult else { return [] }

        let sorted = graph.contributions.sorted { $0.date < $1.date }
        let recent = Array(sorted.suffix(60))

        return recent.map { day in
            var modelMap: [String: Int64] = [:]
            for c in day.clients {
                modelMap[c.modelId, default: 0] += c.tokens.total
            }
            let segments = modelMap.map { BarSegment(model: $0.key, tokens: $0.value) }
                .sorted { $0.tokens > $1.tokens }

            return BarData(date: day.date, segments: segments, totalTokens: day.totals.tokens)
        }
    }
}
