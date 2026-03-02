import Foundation

// MARK: - Token Breakdown
struct TokenBreakdown: Codable {
    let input: Int64
    let output: Int64
    let cacheRead: Int64
    let cacheWrite: Int64
    let reasoning: Int64

    var total: Int64 { input + output + cacheRead + cacheWrite + reasoning }

    init(input: Int64 = 0, output: Int64 = 0, cacheRead: Int64 = 0, cacheWrite: Int64 = 0, reasoning: Int64 = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.reasoning = reasoning
    }
}

// MARK: - Model Report (tokscale models --json)
struct ModelUsage: Codable, Identifiable {
    let client: String
    let mergedClients: String?
    let model: String
    let provider: String
    let input: Int64
    let output: Int64
    let cacheRead: Int64
    let cacheWrite: Int64
    let reasoning: Int64
    let messageCount: Int64
    let cost: Double

    var id: String { "\(client)-\(provider)-\(model)" }
    var totalTokens: Int64 { input + output + cacheRead + cacheWrite + reasoning }
}

struct ModelReport: Codable {
    let groupBy: String?
    let entries: [ModelUsage]
    let totalInput: Int64
    let totalOutput: Int64
    let totalCacheRead: Int64
    let totalCacheWrite: Int64
    let totalMessages: Int64
    let totalCost: Double
    let processingTimeMs: Double
}

// MARK: - Monthly Report (tokscale monthly --json)
struct MonthlyUsage: Codable, Identifiable {
    let month: String
    let models: [String]
    let input: Int64
    let output: Int64
    let cacheRead: Int64
    let cacheWrite: Int64
    let messageCount: Int64
    let cost: Double

    var id: String { month }
    var totalTokens: Int64 { input + output + cacheRead + cacheWrite }
}

struct MonthlyReport: Codable {
    let entries: [MonthlyUsage]
    let totalCost: Double
    let processingTimeMs: Double
}

// MARK: - Graph Data (tokscale graph --output <file>)
struct ClientContribution: Codable {
    let client: String
    let modelId: String
    let providerId: String
    let tokens: TokenBreakdown
    let cost: Double
    let messages: Int64
}

struct DailyTotals: Codable {
    let tokens: Int64
    let cost: Double
    let messages: Int64
}

struct DailyContribution: Codable, Identifiable {
    let date: String
    let totals: DailyTotals
    let intensity: Int
    let tokenBreakdown: TokenBreakdown
    let clients: [ClientContribution]

    var id: String { date }
}

struct DateRange: Codable {
    let start: String
    let end: String
}

struct YearSummary: Codable {
    let year: String
    let totalTokens: Int64
    let totalCost: Double
    let range: DateRange
}

struct DataSummary: Codable {
    let totalTokens: Int64
    let totalCost: Double
    let totalDays: Int
    let activeDays: Int
    let averagePerDay: Double
    let maxCostInSingleDay: Double
    let clients: [String]
    let models: [String]
}

struct GraphMeta: Codable {
    let generatedAt: String
    let version: String
    let dateRange: DateRange
}

struct GraphResult: Codable {
    let meta: GraphMeta
    let summary: DataSummary
    let years: [YearSummary]
    let contributions: [DailyContribution]
}

// MARK: - Today Summary (derived from graph)
struct ClientSummary: Identifiable {
    let client: String
    let tokens: Int64
    let cost: Double

    var id: String { client }
}

struct TodaySummary {
    let totalTokens: Int64
    let totalCost: Double
    let clients: [ClientSummary]
}

// MARK: - Graph Grid (for 52-week contribution view)
struct GraphDay {
    let date: String
    let tokens: Int64
    let cost: Double
    let intensity: Double
    let clients: [ClientContribution]
}

struct GraphGrid {
    let weeks: [[GraphDay?]]  // 53 weeks × 7 days
}
