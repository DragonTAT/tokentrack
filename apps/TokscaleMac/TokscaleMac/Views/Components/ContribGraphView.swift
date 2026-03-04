import SwiftUI

/// 52-week contribution graph rendered with Canvas, matching stats.rs.
struct ContribGraphView: View {
    @Environment(\.theme) private var theme
    @Environment(DataStore.self) private var store
    @Binding var selectedCell: (week: Int, day: Int)?
    let cellWidth: CGFloat = 12
    let gap: CGFloat = 2

    private let monthLabels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        guard let grid = store.graphGrid else {
            return AnyView(Text("No graph data").foregroundStyle(theme.secondaryForeground).font(.system(size: 12, design: .monospaced)))
        }

        let labelW: CGFloat = 28
        let graphStartY: CGFloat = 16
        let totalWidth = labelW + CGFloat(grid.weeks.count) * (cellWidth + gap)
        let totalHeight = graphStartY + 7 * (cellWidth + gap)

        return AnyView(
            Canvas { context, size in
                // Month labels
                var lastMonth = -1
                for (wi, week) in grid.weeks.enumerated() {
                    if let firstDay = week.compactMap({ $0 }).first {
                        let comps = firstDay.date.split(separator: "-")
                        if comps.count >= 2, let month = Int(comps[1]) {
                            let m = month - 1
                            if m != lastMonth && m < monthLabels.count {
                                lastMonth = m
                                let x = labelW + CGFloat(wi) * (cellWidth + gap)
                                context.draw(
                                    Text(monthLabels[m]).font(.system(size: 9, design: .monospaced)).foregroundStyle(theme.secondaryForeground),
                                    at: CGPoint(x: x + cellWidth / 2, y: 6),
                                    anchor: .center
                                )
                            }
                        }
                    }
                }

                // Day labels (every other row)
                for (di, label) in dayLabels.enumerated() where di % 2 == 1 {
                    let y = graphStartY + CGFloat(di) * (cellWidth + gap) + cellWidth / 2
                    context.draw(
                        Text(label).font(.system(size: 8, design: .monospaced)).foregroundStyle(theme.secondaryForeground),
                        at: CGPoint(x: 14, y: y),
                        anchor: .center
                    )
                }

                // Grid cells
                for (wi, week) in grid.weeks.enumerated() {
                    for (di, dayOpt) in week.enumerated() {
                        let x = labelW + CGFloat(wi) * (cellWidth + gap)
                        let y = graphStartY + CGFloat(di) * (cellWidth + gap)
                        let rect = CGRect(x: x, y: y, width: cellWidth, height: cellWidth)
                        let isSelected = selectedCell?.week == wi && selectedCell?.day == di

                        if let day = dayOpt {
                            let color = store.currentTheme.intensityColor(day.intensity)
                            if isSelected {
                                context.fill(RoundedRectangle(cornerRadius: 2).path(in: rect), with: .color(theme.foreground))
                                let inner = rect.insetBy(dx: 1, dy: 1)
                                context.fill(RoundedRectangle(cornerRadius: 1).path(in: inner), with: .color(color))
                            } else {
                                context.fill(RoundedRectangle(cornerRadius: 2).path(in: rect), with: .color(color))
                            }
                            // Empty cell (dot)
                            let dotRect = CGRect(x: x + cellWidth/2 - 1, y: y + cellWidth/2 - 1, width: 2, height: 2)
                            context.fill(Circle().path(in: dotRect), with: .color(theme.border))
                        }
                    }
                }
            }
            .frame(width: totalWidth, height: totalHeight)
            .onTapGesture { location in
                handleTap(location: location, grid: grid, labelW: labelW, graphStartY: graphStartY)
            }
        )
    }

    private func handleTap(location: CGPoint, grid: GraphGrid, labelW: CGFloat, graphStartY: CGFloat) {
        let wi = Int((location.x - labelW) / (cellWidth + gap))
        let di = Int((location.y - graphStartY) / (cellWidth + gap))
        if wi >= 0 && wi < grid.weeks.count && di >= 0 && di < 7 {
            if selectedCell?.week == wi && selectedCell?.day == di {
                selectedCell = nil
            } else {
                selectedCell = (wi, di)
            }
        }
    }
}
