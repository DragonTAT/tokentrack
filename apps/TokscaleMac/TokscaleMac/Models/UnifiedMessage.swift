import Foundation

public struct UnifiedMessage: Codable, Equatable {
    public var client: String
    public var modelId: String
    public var providerId: String
    public var sessionId: String
    public var timestamp: Int64
    public var date: String
    public var tokens: TokenBreakdown
    public var cost: Double
    public var agent: String?
    public var dedupKey: String?
    
    public init(
        client: String,
        modelId: String,
        providerId: String,
        sessionId: String,
        timestamp: Int64,
        tokens: TokenBreakdown,
        cost: Double = 0.0,
        agent: String? = nil,
        dedupKey: String? = nil
    ) {
        self.client = client
        self.modelId = modelId
        self.providerId = providerId
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.tokens = tokens
        self.cost = cost
        self.agent = agent
        self.dedupKey = dedupKey
        
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        self.date = formatter.string(from: date)
    }
}
