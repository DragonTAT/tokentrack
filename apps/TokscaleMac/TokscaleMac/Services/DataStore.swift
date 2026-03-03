import Foundation
import SwiftUI

/// Observable data store that caches CLI data and supports auto-refresh.
@Observable
final class DataStore {
    var modelReport: ModelReport?
    var monthlyReport: MonthlyReport?
    var graphResult: GraphResult?
    var todaySummary: TodaySummary?
    var graphGrid: GraphGrid?

    var isLoading = false
    var error: String?
    var lastRefresh: Date?
    var currentTheme: Theme = .from(.blue)

    // Stats derived from graph
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalSessions: Int64 = 0

    private let service = TokscaleService()
    private var refreshTimer: Timer?

    init() {
        Task { @MainActor in
            await refreshAll()
        }
        startAutoRefresh()
    }

    // MARK: - Data Loading (resilient - each command independent)

    @MainActor
    func refreshAll() async {
        isLoading = true
        error = nil
        var errors: [String] = []

        // Load models
        do {
            self.modelReport = try await service.fetchModelReport()
            self.totalSessions = Int64(modelReport?.entries.reduce(Int32(0)) { $0 + $1.messageCount } ?? 0)
        } catch {
            errors.append("models: \(error.localizedDescription)")
        }

        // Load monthly
        do {
            self.monthlyReport = try await service.fetchMonthlyReport()
        } catch {
            errors.append("monthly: \(error.localizedDescription)")
        }

        // Load graph
        do {
            let g = try await service.fetchGraphData()
            self.graphResult = g
            self.todaySummary = computeTodaySummary(from: g)
            self.graphGrid = buildGraphGrid(from: g)
            computeStreaks(from: g)
        } catch {
            errors.append("graph: \(error.localizedDescription)")
        }

        if !errors.isEmpty && modelReport == nil && graphResult == nil {
            self.error = errors.joined(separator: "\n")
        }

        self.lastRefresh = Date()
        isLoading = false
    }

    // MARK: - Theme

    func cycleTheme() {
        currentTheme = .from(currentTheme.name.next)
    }

    // MARK: - Period Summary (today / week / month)

    func summaryForPeriod(_ period: TimePeriod) -> TodaySummary {
        guard let graph = graphResult else {
            return TodaySummary(totalTokens: 0, totalCost: 0, clients: [])
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let today = Date()

        let cutoff: Date
        switch period {
        case .today: cutoff = calendar.startOfDay(for: today)
        case .week: cutoff = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        case .month: cutoff = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        }

        let cutoffStr = formatter.string(from: cutoff)

        let matching = graph.contributions.filter { $0.date >= cutoffStr }

        var totalTokens: Int64 = 0
        var totalCost: Double = 0
        var clientMap: [String: (tokens: Int64, cost: Double)] = [:]

        for day in matching {
            totalTokens += day.totals.tokens
            totalCost += day.totals.cost
            for c in day.clients {
                let existing = clientMap[c.client] ?? (0, 0)
                clientMap[c.client] = (existing.tokens + c.tokens.total, existing.cost + c.cost)
            }
        }

        let clients = clientMap.map { ClientSummary(client: $0.key, tokens: $0.value.tokens, cost: $0.value.cost) }
            .sorted { $0.tokens > $1.tokens }

        return TodaySummary(totalTokens: totalTokens, totalCost: totalCost, clients: clients)
    }

    private func computeTodaySummary(from graph: GraphResult) -> TodaySummary {
        summaryForPeriod(.today)
    }

    // MARK: - 52-Week Graph Grid

    private func buildGraphGrid(from graph: GraphResult) -> GraphGrid {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let byDate: [String: DailyContribution] = Dictionary(
            graph.contributions.map { ($0.date, $0) },
            uniquingKeysWith: { _, last in last }
        )

        // Find max tokens for intensity calculation
        let maxTokens = graph.contributions.map { $0.totals.tokens }.max() ?? 1
        let maxTokensDouble = max(Double(maxTokens), 1)

        let today = Date()
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: today) - 1 // 0=Sun
        let totalDays = 53 * 7
        guard let gridStart = calendar.date(byAdding: .day, value: -(totalDays - 1 + dayOfWeek), to: today) else {
            return GraphGrid(weeks: [])
        }

        var weeks: [[GraphDay?]] = []
        var cursor = gridStart

        for _ in 0..<53 {
            var week: [GraphDay?] = []
            for _ in 0..<7 {
                let dateStr = formatter.string(from: cursor)
                if cursor > today {
                    week.append(nil)
                } else if let contrib = byDate[dateStr] {
                    let intensity = Double(contrib.totals.tokens) / maxTokensDouble
                    week.append(GraphDay(
                        date: dateStr,
                        tokens: contrib.totals.tokens,
                        cost: contrib.totals.cost,
                        intensity: intensity,
                        clients: contrib.clients
                    ))
                } else {
                    week.append(GraphDay(date: dateStr, tokens: 0, cost: 0, intensity: 0, clients: []))
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            weeks.append(week)
        }

        return GraphGrid(weeks: weeks)
    }

    // MARK: - Streaks

    private func computeStreaks(from graph: GraphResult) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let activeDates = Set(
            graph.contributions
                .filter { $0.totals.tokens > 0 }
                .compactMap { formatter.date(from: $0.date) }
        )

        let calendar = Calendar.current

        // Current streak (count backwards from today)
        var current = 0
        var checkDate = Date()
        while true {
            let dateStr = formatter.string(from: checkDate)
            if let d = formatter.date(from: dateStr), activeDates.contains(d) {
                current += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }

        // Longest streak
        var longest = 0
        var streak = 0
        let sorted = activeDates.sorted()
        for (i, date) in sorted.enumerated() {
            if i == 0 {
                streak = 1
            } else {
                let prev = sorted[i - 1]
                let diff = calendar.dateComponents([.day], from: prev, to: date).day ?? 0
                streak = diff == 1 ? streak + 1 : 1
            }
            longest = max(longest, streak)
        }

        self.currentStreak = current
        self.longestStreak = longest
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshAll()
            }
        }
    }
}
