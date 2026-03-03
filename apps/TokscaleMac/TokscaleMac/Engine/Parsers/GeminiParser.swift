import Foundation

struct GeminiTokens: Codable {
    let input: Int64?
    let output: Int64?
    let cached: Int64?
    let thoughts: Int64?
    let tool: Int64?
    let total: Int64?
}

struct GeminiMessage: Codable {
    let id: String
    let timestamp: String?
    let type: String
    let tokens: GeminiTokens?
    let model: String?
}

struct GeminiSession: Codable {
    let sessionId: String
    let projectHash: String
    let startTime: String
    let lastUpdated: String
    let messages: [GeminiMessage]
}

public class GeminiParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        return parse(fileURL: fileURL, source: "gemini")
    }
    
    private static func parse(fileURL: URL, source: String) -> [UnifiedMessage] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fallbackDate = fileAttributes?[.modificationDate] as? Date ?? Date()
        let fallbackTimestamp = Int64(fallbackDate.timeIntervalSince1970 * 1000)
        
        var messages: [UnifiedMessage] = []
        
        do {
            let session = try JSONDecoder().decode(GeminiSession.self, from: data)
            let sessionId = session.sessionId
            
            for msg in session.messages {
                guard msg.type == "gemini", let tokens = msg.tokens else { continue }
                
                let model = msg.model ?? "gemini-2.0-flash"
                
                var timestamp = fallbackTimestamp
                if let tsString = msg.timestamp {
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
                
                let rawInput = tokens.input ?? 0
                let cached = tokens.cached ?? 0
                let baseInput = max(0, rawInput - cached)
                
                let breakdown = TokenBreakdown(
                    input: baseInput,
                    output: max(0, tokens.output ?? 0),
                    cacheRead: max(0, cached),
                    cacheWrite: 0,
                    reasoning: max(0, tokens.thoughts ?? 0)
                )
                
                messages.append(UnifiedMessage(
                    client: source,
                    modelId: model,
                    providerId: "google",
                    sessionId: sessionId,
                    timestamp: timestamp,
                    tokens: breakdown,
                    cost: 0.0
                ))
            }
        } catch {
            // Check headless format if normal parse fails
            // (We will skip full jsonl / value fallback extraction in this simplest implementation
            //  assuming `TokscaleMac` primarily reads GUI sessions for Gemini right now, 
            //  but full implementation would parse dictionaries here)
        }
        
        return messages
    }
}
