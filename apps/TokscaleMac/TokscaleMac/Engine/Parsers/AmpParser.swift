import Foundation

struct AmpTokens: Codable {
    let input: Int64?
    let output: Int64?
    let cacheReadInputTokens: Int64?
    let cacheCreationInputTokens: Int64?
}

struct AmpUsageEvent: Codable {
    let timestamp: String?
    let model: String?
    let credits: Double?
    let tokens: AmpTokens?
    let operationType: String?
}

struct AmpMessageUsage: Codable {
    let model: String?
    let inputTokens: Int64?
    let outputTokens: Int64?
    let cacheReadInputTokens: Int64?
    let cacheCreationInputTokens: Int64?
    let credits: Double?
}

struct AmpMessage: Codable {
    let role: String?
    let messageId: Int64?
    let usage: AmpMessageUsage?
}

struct AmpUsageLedger: Codable {
    let events: [AmpUsageEvent]?
}

struct AmpThread: Codable {
    let id: String?
    let created: Int64?
    let messages: [AmpMessage]?
    let usageLedger: AmpUsageLedger?
}

public class AmpParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let thread = try? JSONDecoder().decode(AmpThread.self, from: data) else { return [] }
        
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fallbackDate = fileAttributes?[.modificationDate] as? Date ?? Date()
        let fallbackTimestamp = Int64(fallbackDate.timeIntervalSince1970 * 1000)
        
        let threadId = thread.id ?? fileURL.deletingPathExtension().lastPathComponent
        let threadCreatedMs = thread.created ?? 0
        
        var messages: [UnifiedMessage] = []
        
        if let ledger = thread.usageLedger, let events = ledger.events {
            for event in events {
                guard let model = event.model else { continue }
                
                var timestamp: Int64 = 0
                if let tsString = event.timestamp {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let d = formatter.date(from: tsString) {
                        timestamp = Int64(d.timeIntervalSince1970 * 1000)
                    } else {
                        formatter.formatOptions = [.withInternetDateTime]
                        if let d = formatter.date(from: tsString) {
                            timestamp = Int64(d.timeIntervalSince1970 * 1000)
                        }
                    }
                }
                
                if timestamp == 0 {
                    timestamp = threadCreatedMs != 0 ? threadCreatedMs : fallbackTimestamp
                }
                
                let tokens = event.tokens ?? AmpTokens(input: 0, output: 0, cacheReadInputTokens: 0, cacheCreationInputTokens: 0)
                
                let providerId: String
                let lowerModel = model.lowercased()
                if lowerModel.contains("claude") || lowerModel.contains("opus") || lowerModel.contains("sonnet") || lowerModel.contains("haiku") {
                    providerId = "anthropic"
                } else if lowerModel.contains("gpt") || lowerModel.contains("o1") || lowerModel.contains("o3") {
                    providerId = "openai"
                } else if lowerModel.contains("gemini") {
                    providerId = "google"
                } else {
                    providerId = "anthropic"
                }
                
                messages.append(UnifiedMessage(
                    client: "amp",
                    modelId: model,
                    providerId: providerId,
                    sessionId: threadId,
                    timestamp: timestamp,
                    tokens: TokenBreakdown(
                        input: max(0, tokens.input ?? 0),
                        output: max(0, tokens.output ?? 0),
                        cacheRead: max(0, tokens.cacheReadInputTokens ?? 0),
                        cacheWrite: max(0, tokens.cacheCreationInputTokens ?? 0),
                        reasoning: 0
                    ),
                    cost: max(0.0, event.credits ?? 0.0)
                ))
            }
            if !messages.isEmpty { return messages }
        }
        
        let created = threadCreatedMs
        if let threadMessages = thread.messages {
            for msg in threadMessages {
                if msg.role != "assistant" { continue }
                guard let usage = msg.usage, let model = usage.model else { continue }
                
                let messageId = msg.messageId ?? 0
                let timestamp = created + (messageId * 1000)
                
                let providerId: String
                let lowerModel = model.lowercased()
                if lowerModel.contains("claude") || lowerModel.contains("opus") || lowerModel.contains("sonnet") {
                    providerId = "anthropic"
                } else if lowerModel.contains("gpt") {
                    providerId = "openai"
                } else {
                    providerId = "anthropic"
                }
                
                messages.append(UnifiedMessage(
                    client: "amp",
                    modelId: model,
                    providerId: providerId,
                    sessionId: threadId,
                    timestamp: timestamp,
                    tokens: TokenBreakdown(
                        input: max(0, usage.inputTokens ?? 0),
                        output: max(0, usage.outputTokens ?? 0),
                        cacheRead: max(0, usage.cacheReadInputTokens ?? 0),
                        cacheWrite: max(0, usage.cacheCreationInputTokens ?? 0),
                        reasoning: 0
                    ),
                    cost: max(0.0, usage.credits ?? 0.0)
                ))
            }
        }
        
        return messages
    }
}
