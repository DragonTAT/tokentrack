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
                    timestamp = parseISO8601Timestamp(tsString) ?? fallbackTimestamp
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
            // Fallback: try parsing as JSONL (headless/CLI format)
            guard let content = String(data: data, encoding: .utf8) else { return [] }
            let sessionId = fileURL.deletingPathExtension().lastPathComponent
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                
                guard let lineData = trimmed.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                    continue
                }
                
                // Try to extract token usage from various possible structures
                let tokensDict = dict["tokens"] as? [String: Any]
                    ?? (dict["usageMetadata"] as? [String: Any])
                    ?? (dict["usage"] as? [String: Any])
                
                guard let tokens = tokensDict else { continue }
                
                let rawInput = (tokens["input"] as? NSNumber)?.int64Value
                    ?? (tokens["promptTokenCount"] as? NSNumber)?.int64Value
                    ?? (tokens["input_tokens"] as? NSNumber)?.int64Value ?? 0
                let output = (tokens["output"] as? NSNumber)?.int64Value
                    ?? (tokens["candidatesTokenCount"] as? NSNumber)?.int64Value
                    ?? (tokens["output_tokens"] as? NSNumber)?.int64Value ?? 0
                let cached = (tokens["cached"] as? NSNumber)?.int64Value
                    ?? (tokens["cachedContentTokenCount"] as? NSNumber)?.int64Value ?? 0
                let thoughts = (tokens["thoughts"] as? NSNumber)?.int64Value
                    ?? (tokens["thoughtsTokenCount"] as? NSNumber)?.int64Value ?? 0
                
                let baseInput = max(0, rawInput - cached)
                if baseInput == 0 && output == 0 && cached == 0 { continue }
                
                let model = dict["model"] as? String ?? "gemini-unknown"
                
                var timestamp = fallbackTimestamp
                if let tsStr = dict["timestamp"] as? String {
                    timestamp = parseISO8601Timestamp(tsStr) ?? fallbackTimestamp
                } else if let tsNum = (dict["timestamp"] as? NSNumber)?.doubleValue {
                    timestamp = Int64(tsNum * (tsNum > 1e12 ? 1.0 : 1000.0))
                }
                
                messages.append(UnifiedMessage(
                    client: source,
                    modelId: model,
                    providerId: "google",
                    sessionId: sessionId,
                    timestamp: timestamp,
                    tokens: TokenBreakdown(
                        input: baseInput,
                        output: max(0, output),
                        cacheRead: max(0, cached),
                        cacheWrite: 0,
                        reasoning: max(0, thoughts)
                    ),
                    cost: 0.0
                ))
            }
        }
        
        return messages
    }
    
    private static func parseISO8601Timestamp(_ str: String) -> Int64? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) {
            return Int64(d.timeIntervalSince1970 * 1000)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: str) {
            return Int64(d.timeIntervalSince1970 * 1000)
        }
        return nil
    }
}
