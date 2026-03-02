import SwiftUI

/// Models tab using native macOS Table for proper column resizing and sorting behavior.
struct ModelsTab: View {
    @Environment(DataStore.self) private var store
    @Binding var sortField: SortField
    @Binding var sortDirection: SortDirection
    @State private var selectedModelID: ModelUsage.ID?

    var body: some View {
        let models = sortedModels

        if models.isEmpty {
            Text("No usage data found. Click refresh to reload.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { proxy in
                let layout = ModelsColumnLayout.compute(availableWidth: proxy.size.width)

                Group {
                    if layout.mode == .withCache {
                        tableWithCache(models: models, layout: layout)
                    } else {
                        tableCompact(models: models, layout: layout)
                    }
                }
                .id("models-mode-\(layout.mode.rawValue)")
                .frame(width: proxy.size.width, height: proxy.size.height)
                .tableStyle(.inset)
                .font(.system(size: 12))
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    private func tableWithCache(models: [ModelUsage], layout: ModelsColumnLayout) -> some View {
        Table(models, selection: $selectedModelID) {
            TableColumn("Model") { model in
                modelCell(for: model)
            }
            .width(min: ModelsColumnLayout.modelMin, ideal: layout.model)

            TableColumn("Source") { model in
                Text(AppColors.clientDisplayName(model.client))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: ModelsColumnLayout.sourceMin, ideal: layout.source)

            tokenColumn(
                title: "Input",
                value: \.input,
                color: AppColors.inputTokens,
                width: layout.input,
                minWidth: ModelsColumnLayout.inputMin
            )
            tokenColumn(
                title: "Output",
                value: \.output,
                color: AppColors.outputTokens,
                width: layout.output,
                minWidth: ModelsColumnLayout.outputMin
            )
            tokenColumn(
                title: "Cache Read",
                value: \.cacheRead,
                color: AppColors.cacheReadTokens,
                width: layout.cacheRead,
                minWidth: ModelsColumnLayout.cacheMin
            )
            tokenColumn(
                title: "Cache Write",
                value: \.cacheWrite,
                color: AppColors.cacheWriteTokens,
                width: layout.cacheWrite,
                minWidth: ModelsColumnLayout.cacheMin
            )

            TableColumn("Total Tokens") { model in
                Text(Formatting.formatTokens(model.totalTokens))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: ModelsColumnLayout.totalMin, ideal: layout.totalTokens)

            TableColumn("Cost") { model in
                Text(Formatting.formatCost(model.cost))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: ModelsColumnLayout.costMin, ideal: layout.cost)
        }
    }

    private func tableCompact(models: [ModelUsage], layout: ModelsColumnLayout) -> some View {
        Table(models, selection: $selectedModelID) {
            TableColumn("Model") { model in
                modelCell(for: model)
            }
            .width(min: ModelsColumnLayout.modelMin, ideal: layout.model)

            TableColumn("Source") { model in
                Text(AppColors.clientDisplayName(model.client))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: ModelsColumnLayout.sourceMin, ideal: layout.source)

            tokenColumn(
                title: "Input",
                value: \.input,
                color: AppColors.inputTokens,
                width: layout.input,
                minWidth: ModelsColumnLayout.inputMin
            )
            tokenColumn(
                title: "Output",
                value: \.output,
                color: AppColors.outputTokens,
                width: layout.output,
                minWidth: ModelsColumnLayout.outputMin
            )

            TableColumn("Total Tokens") { model in
                Text(Formatting.formatTokens(model.totalTokens))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: ModelsColumnLayout.totalMin, ideal: layout.totalTokens)

            TableColumn("Cost") { model in
                Text(Formatting.formatCost(model.cost))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: ModelsColumnLayout.costMin, ideal: layout.cost)
        }
    }

    private func modelCell(for model: ModelUsage) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppColors.modelColor(model.model))
                .frame(width: 8, height: 8)
            Text(model.model)
                .foregroundStyle(AppColors.modelColor(model.model))
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func tokenColumn(
        title: String,
        value: KeyPath<ModelUsage, Int64>,
        color: Color,
        width: CGFloat,
        minWidth: CGFloat
    ) -> some TableColumnContent<ModelUsage, Never> {
        TableColumn(title) { model in
            Text(Formatting.formatTokens(model[keyPath: value]))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .width(min: minWidth, ideal: width)
    }

    // MARK: - Sorting
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
}

private struct ModelsColumnLayout {
    enum Mode: String {
        case compact
        case withCache
    }

    static let horizontalInset: CGFloat = 36
    static let rightEdgeGuard: CGFloat = 16

    static let modelMin: CGFloat = 130
    static let sourceMin: CGFloat = 72
    static let inputMin: CGFloat = 42
    static let outputMin: CGFloat = 42
    static let cacheMin: CGFloat = 50
    static let totalMin: CGFloat = 54
    static let costMin: CGFloat = 63

    static let modelIdeal: CGFloat = modelMin
    static let sourceIdeal: CGFloat = sourceMin
    static let inputIdeal: CGFloat = inputMin
    static let outputIdeal: CGFloat = outputMin
    static let totalIdeal: CGFloat = totalMin
    static let costIdeal: CGFloat = costMin

    static let cacheIdeal: CGFloat = cacheMin

    static var compactMinTotal: CGFloat {
        modelMin + sourceMin + inputMin + outputMin + totalMin + costMin
    }

    static var compactIdealTotal: CGFloat {
        modelIdeal + sourceIdeal + inputIdeal + outputIdeal + totalIdeal + costIdeal
    }

    static var fullMinTotal: CGFloat {
        compactMinTotal + (cacheMin * 2)
    }

    static let cacheShowThreshold: CGFloat = 640

    static var fullIdealTotal: CGFloat {
        compactIdealTotal + (cacheIdeal * 2)
    }

    let mode: Mode
    let model: CGFloat
    let source: CGFloat
    let input: CGFloat
    let output: CGFloat
    let cacheRead: CGFloat
    let cacheWrite: CGFloat
    let totalTokens: CGFloat
    let cost: CGFloat

    static func compute(availableWidth: CGFloat) -> ModelsColumnLayout {
        // Use actual container width so cache threshold maps directly to column width totals.
        let usable = max(availableWidth, 280)

        // 1) Compact mode until all visible columns can fit their minimum widths.
        if usable < cacheShowThreshold {
            let base = compactBaseWidths(usableWidth: usable)
            return ModelsColumnLayout(
                mode: .compact,
                model: base.model,
                source: base.source,
                input: base.input,
                output: base.output,
                cacheRead: 0,
                cacheWrite: 0,
                totalTokens: base.total,
                cost: base.cost
            )
        }

        // 2) Cache mode: grow cache from min -> ideal.
        if usable < fullIdealTotal {
            let p = (usable - cacheShowThreshold) / max(fullIdealTotal - cacheShowThreshold, 0.0001)
            return ModelsColumnLayout(
                mode: .withCache,
                model: modelIdeal,
                source: sourceIdeal,
                input: inputIdeal,
                output: outputIdeal,
                cacheRead: lerp(cacheMin, cacheIdeal, p),
                cacheWrite: lerp(cacheMin, cacheIdeal, p),
                totalTokens: totalIdeal,
                cost: costIdeal
            )
        }

        // 3) Above full ideal: distribute extra width with weights.
        let extra = usable - fullIdealTotal
        let (m, s, i, o, t, c, cr, cw) = distributeExtra(
            extra,
            base: (modelIdeal, sourceIdeal, inputIdeal, outputIdeal, totalIdeal, costIdeal, cacheIdeal, cacheIdeal),
            weights: (4.2, 1.8, 1.3, 1.3, 1.5, 1.2, 1.1, 1.1)
        )
        return ModelsColumnLayout(
            mode: .withCache,
            model: m,
            source: s,
            input: i,
            output: o,
            cacheRead: cr,
            cacheWrite: cw,
            totalTokens: t,
            cost: c
        )
    }

    private static func compactBaseWidths(usableWidth: CGFloat) -> (model: CGFloat, source: CGFloat, input: CGFloat, output: CGFloat, total: CGFloat, cost: CGFloat) {
        if usableWidth <= compactMinTotal {
            return (modelMin, sourceMin, inputMin, outputMin, totalMin, costMin)
        }

        if usableWidth < compactIdealTotal {
            let p = (usableWidth - compactMinTotal) / max(compactIdealTotal - compactMinTotal, 0.0001)
            return (
                lerp(modelMin, modelIdeal, p),
                lerp(sourceMin, sourceIdeal, p),
                lerp(inputMin, inputIdeal, p),
                lerp(outputMin, outputIdeal, p),
                lerp(totalMin, totalIdeal, p),
                lerp(costMin, costIdeal, p)
            )
        }

        let extra = usableWidth - compactIdealTotal
        let (m, s, i, o, t, c, _, _) = distributeExtra(
            extra,
            base: (modelIdeal, sourceIdeal, inputIdeal, outputIdeal, totalIdeal, costIdeal, 0, 0),
            weights: (4.4, 1.8, 1.3, 1.3, 1.5, 1.1, 0, 0)
        )
        return (m, s, i, o, t, c)
    }

    private static func lerp(_ lower: CGFloat, _ upper: CGFloat, _ progress: CGFloat) -> CGFloat {
        let clamped = Swift.max(0, Swift.min(1, progress))
        return lower + ((upper - lower) * clamped)
    }

    private static func distributeExtra(
        _ extra: CGFloat,
        base: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat),
        weights: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) {
        let totalWeight = max(
            weights.0 + weights.1 + weights.2 + weights.3 + weights.4 + weights.5 + weights.6 + weights.7,
            0.0001
        )

        return (
            base.0 + extra * (weights.0 / totalWeight),
            base.1 + extra * (weights.1 / totalWeight),
            base.2 + extra * (weights.2 / totalWeight),
            base.3 + extra * (weights.3 / totalWeight),
            base.4 + extra * (weights.4 / totalWeight),
            base.5 + extra * (weights.5 / totalWeight),
            base.6 + extra * (weights.6 / totalWeight),
            base.7 + extra * (weights.7 / totalWeight)
        )
    }

}
