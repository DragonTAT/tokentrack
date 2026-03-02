import SwiftUI

/// 30-day mini contribution bar for the popover.
struct MiniGraphView: View {
    @Environment(DataStore.self) private var store
    private let cellSize: CGFloat = 10
    private let gap: CGFloat = 2

    var body: some View {
        let contributions = recentContributions
        if contributions.isEmpty {
            Text("No data").font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColors.muted)
        } else {
            Canvas { context, size in
                for (i, day) in contributions.enumerated() {
                    let x = CGFloat(i) * (cellSize + gap)
                    let rect = CGRect(x: x, y: 0, width: cellSize, height: cellSize)
                    let color = store.currentTheme.intensityColor(Double(day.intensity) / 4.0)
                    context.fill(RoundedRectangle(cornerRadius: 2).path(in: rect), with: .color(color))
                }
            }
            .frame(width: CGFloat(contributions.count) * (cellSize + gap), height: cellSize)
        }
    }

    private var recentContributions: [DailyContribution] {
        guard let graph = store.graphResult else { return [] }
        return Array(graph.contributions.suffix(30))
    }
}
