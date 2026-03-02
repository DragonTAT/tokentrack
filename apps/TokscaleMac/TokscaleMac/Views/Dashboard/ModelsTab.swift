import SwiftUI

/// Models tab: full table with #/Model/Provider/Source/Input/Output/CacheRead/CacheWrite/Total/Cost.
struct ModelsTab: View {
    @Environment(DataStore.self) private var store
    @Binding var sortField: SortField
    @Binding var sortDirection: SortDirection
    @State private var selectedIndex: Int? = nil

    var body: some View {
        let models = sortedModels

        if models.isEmpty {
            Text("No usage data found. Click refresh to reload.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Header row
                headerRow

                // Table body
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(models.enumerated()), id: \.element.id) { idx, model in
                            modelRow(idx: idx, model: model)
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
            headerCell("#", width: 30, alignment: .center, field: nil)
            headerCell("Model", width: nil, alignment: .leading, field: nil)
            headerCell("Provider", width: 100, alignment: .leading, field: nil)
            headerCell("Source", width: 90, alignment: .leading, field: nil)
            headerCell("Input", width: 70, alignment: .trailing, field: nil)
            headerCell("Output", width: 70, alignment: .trailing, field: nil)
            headerCell("Cache Read", width: 85, alignment: .trailing, field: nil)
            headerCell("Cache Write", width: 85, alignment: .trailing, field: nil)
            headerCell("Total" + (sortField == .tokens ? (sortDirection == .ascending ? " ▲" : " ▼") : ""),
                       width: 75, alignment: .trailing, field: .tokens)
            headerCell("Cost" + (sortField == .cost ? (sortDirection == .ascending ? " ▲" : " ▼") : ""),
                       width: 75, alignment: .trailing, field: .cost)
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(store.currentTheme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.background)
        .overlay(alignment: .bottom) { Rectangle().fill(AppColors.border).frame(height: 1) }
    }

    @ViewBuilder
    private func headerCell(_ text: String, width: CGFloat?, alignment: Alignment, field: SortField?) -> some View {
        let content = Text(text).lineLimit(1)

        if let w = width {
            content.frame(width: w, alignment: alignment)
                .onTapGesture {
                    if let f = field {
                        if sortField == f { sortDirection.toggle() } else { sortField = f; sortDirection = .descending }
                    }
                }
        } else {
            content.frame(maxWidth: .infinity, alignment: alignment)
        }
    }

    // MARK: - Row
    private func modelRow(idx: Int, model: ModelUsage) -> some View {
        HStack(spacing: 0) {
            Text("\(idx + 1)")
                .frame(width: 30, alignment: .center)
                .foregroundStyle(AppColors.muted)

            HStack(spacing: 4) {
                Circle().fill(AppColors.modelColor(model.model)).frame(width: 6, height: 6)
                Text(model.model.count > 30 ? String(model.model.prefix(27)) + "..." : model.model)
                    .foregroundStyle(AppColors.modelColor(model.model))
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(AppColors.providerDisplayName(model.provider))
                .frame(width: 100, alignment: .leading)
                .foregroundStyle(AppColors.foreground)

            Text(AppColors.clientDisplayName(model.client))
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(AppColors.muted)

            Text(Formatting.formatTokens(model.input))
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(AppColors.inputTokens)

            Text(Formatting.formatTokens(model.output))
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(AppColors.outputTokens)

            Text(Formatting.formatTokens(model.cacheRead))
                .frame(width: 85, alignment: .trailing)
                .foregroundStyle(AppColors.cacheReadTokens)

            Text(Formatting.formatTokens(model.cacheWrite))
                .frame(width: 85, alignment: .trailing)
                .foregroundStyle(AppColors.cacheWriteTokens)

            Text(Formatting.formatTokens(model.totalTokens))
                .frame(width: 75, alignment: .trailing)
                .foregroundStyle(AppColors.foreground)

            Text(Formatting.formatCost(model.cost))
                .frame(width: 75, alignment: .trailing)
                .foregroundStyle(.green)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
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
