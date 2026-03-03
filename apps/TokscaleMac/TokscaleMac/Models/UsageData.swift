import Foundation

public struct TodaySummary: Equatable {
    public var totalTokens: Int64
    public var totalCost: Double
    public var clients: [ClientSummary]
}

public struct ClientSummary: Equatable, Identifiable {
    public var id: String { client }
    public var client: String
    public var tokens: Int64
    public var cost: Double
}

public struct GraphDay: Equatable, Identifiable {
    public var id: String { date }
    public var date: String
    public var tokens: Int64
    public var cost: Double
    public var intensity: Double
    public var clients: [ClientContribution] // Using ClientContribution from Models.swift
}

public struct GraphGrid {
    public var weeks: [[GraphDay?]]
    
    public init(weeks: [[GraphDay?]]) {
        self.weeks = weeks
    }
}
