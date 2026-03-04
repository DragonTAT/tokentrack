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
        
        // Date is set to empty here; the engine's processMessage will
        // recalculate it with the correct timezone from user settings.
        self.date = ""
    }
}
