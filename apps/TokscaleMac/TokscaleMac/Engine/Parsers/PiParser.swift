import Foundation

struct PiUsage: Codable {
    let input: Int64?
    let output: Int64?
    let cacheRead: Int64?
    let cacheWrite: Int64?
    let totalTokens: Int64?
}

struct PiMessagePayload: Codable {
    let role: String?
    let usage: PiUsage?
    let model: String?
    let provider: String?
}

struct PiSessionEntry: Codable {
    let type: String
    let id: String?
    let timestamp: String?
    let message: PiMessagePayload?
}

struct PiSessionHeader: Codable {
    let type: String
    let id: String
}

public class PiParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fallbackDate = fileAttributes?[.modificationDate] as? Date ?? Date()
        let fallbackTimestamp = Int64(fallbackDate.timeIntervalSince1970 * 1000)
        
        var messages: [UnifiedMessage] = []
        var sessionId: String? = nil
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            guard let data = trimmed.data(using: .utf8) else { continue }
            
            if sessionId == nil {
                if let header = try? JSONDecoder().decode(PiSessionHeader.self, from: data), header.type == "session" {
                    sessionId = header.id
                }
                continue
            }
            
            if let entry = try? JSONDecoder().decode(PiSessionEntry.self, from: data), entry.type == "message" {
                guard let message = entry.message, message.role == "assistant",
                      let usage = message.usage, let model = message.model, let provider = message.provider else {
                    continue
                }
                
                var timestamp = fallbackTimestamp
                if let tsString = entry.timestamp {
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
                
                messages.append(UnifiedMessage(
                    client: "pi",
                    modelId: model,
                    providerId: provider,
                    sessionId: sessionId ?? "unknown",
                    timestamp: timestamp,
                    tokens: TokenBreakdown(
                        input: max(0, usage.input ?? 0),
                        output: max(0, usage.output ?? 0),
                        cacheRead: max(0, usage.cacheRead ?? 0),
                        cacheWrite: max(0, usage.cacheWrite ?? 0),
                        reasoning: 0
                    ),
                    cost: 0.0
                ))
            }
        }
        
        return messages
    }
}
