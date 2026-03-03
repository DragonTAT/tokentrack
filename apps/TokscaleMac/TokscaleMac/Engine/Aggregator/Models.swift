import Foundation

public enum GroupBy: String, Codable, Equatable {
    case model
    case clientModel = "client,model"
    case clientProviderModel = "client,provider,model"
    
    public init(from string: String) {
        let normalized = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: ",")
        switch normalized.lowercased() {
        case "model": self = .model
        case "client,model", "client-model": self = .clientModel
        case "client,provider,model", "client-provider-model": self = .clientProviderModel
        default: self = .clientModel
        }
    }
}

public struct DailyTotals: Codable, Equatable {
    public var tokens: Int64
    public var cost: Double
    public var messages: Int32
    
    public init(tokens: Int64 = 0, cost: Double = 0.0, messages: Int32 = 0) {
        self.tokens = tokens
        self.cost = cost
        self.messages = messages
    }
}

public struct ClientContribution: Codable, Equatable, Identifiable {
    public var id: String { "\(client):\(providerId):\(modelId)" }
    public var client: String
    public var modelId: String
    public var providerId: String
    public var tokens: TokenBreakdown
    public var cost: Double
    public var messages: Int32
}

public struct DailyContribution: Codable, Equatable, Identifiable {
    public var id: String { date }
    public var date: String
    public var totals: DailyTotals
    public var intensity: UInt8
    public var tokenBreakdown: TokenBreakdown
    public var clients: [ClientContribution]
}

public struct YearSummary: Codable, Equatable, Identifiable {
    public var id: String { year }
    public var year: String
    public var totalTokens: Int64
    public var totalCost: Double
    public var rangeStart: String
    public var rangeEnd: String
}

public struct DataSummary: Codable, Equatable {
    public var totalTokens: Int64
    public var totalCost: Double
    public var totalDays: Int32
    public var activeDays: Int32
    public var averagePerDay: Double
    public var maxCostInSingleDay: Double
    public var clients: [String]
    public var models: [String]
}

public struct GraphMeta: Codable, Equatable {
    public var generatedAt: String
    public var version: String
    public var dateRangeStart: String
    public var dateRangeEnd: String
    public var processingTimeMs: UInt32
}

public struct GraphResult: Codable, Equatable {
    public var meta: GraphMeta
    public var summary: DataSummary
    public var years: [YearSummary]
    public var contributions: [DailyContribution]
}

public struct LocalParseOptions {
    public var homeDir: String?
    public var clients: [String]?
    public var since: String?
    public var until: String?
    public var year: String?
    
    public init(homeDir: String? = nil, clients: [String]? = nil, since: String? = nil, until: String? = nil, year: String? = nil) {
        self.homeDir = homeDir
        self.clients = clients
        self.since = since
        self.until = until
        self.year = year
    }
}

public struct ReportOptions {
    public var homeDir: String?
    public var clients: [String]?
    public var since: String?
    public var until: String?
    public var year: String?
    public var groupBy: GroupBy
    
    public init(homeDir: String? = nil, clients: [String]? = nil, since: String? = nil, until: String? = nil, year: String? = nil, groupBy: GroupBy = .clientModel) {
        self.homeDir = homeDir
        self.clients = clients
        self.since = since
        self.until = until
        self.year = year
        self.groupBy = groupBy
    }
}

public struct ModelUsage: Codable, Equatable, Identifiable {
    public var id: String { "\(client):\(provider):\(model)" }
    public var client: String
    public var mergedClients: String?
    public var model: String
    public var provider: String
    public var input: Int64
    public var output: Int64
    public var cacheRead: Int64
    public var cacheWrite: Int64
    public var reasoning: Int64
    public var messageCount: Int32
    public var cost: Double

    public var totalTokens: Int64 {
        return input + output + cacheRead + cacheWrite + reasoning
    }
}

public struct MonthlyUsage: Codable, Equatable, Identifiable {
    public var id: String { month }
    public var month: String
    public var models: [String]
    public var input: Int64
    public var output: Int64
    public var cacheRead: Int64
    public var cacheWrite: Int64
    public var messageCount: Int32
    public var cost: Double
}

public struct ModelReport: Codable, Equatable {
    public var entries: [ModelUsage]
    public var totalInput: Int64
    public var totalOutput: Int64
    public var totalCacheRead: Int64
    public var totalCacheWrite: Int64
    public var totalMessages: Int32
    public var totalCost: Double
    public var processingTimeMs: UInt32
}

public struct MonthlyReport: Codable, Equatable {
    public var entries: [MonthlyUsage]
    public var totalCost: Double
    public var processingTimeMs: UInt32
}
