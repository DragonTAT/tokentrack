import Foundation

struct ClaudeUsage: Codable {
    let input_tokens: Int64?
    let output_tokens: Int64?
    let cache_read_input_tokens: Int64?
    let cache_creation_input_tokens: Int64?
}

struct ClaudeContentMessage: Codable {
    let id: String?
    let model: String?
    let usage: ClaudeUsage?
}

struct ClaudeEntry: Codable {
    let type: String
    let timestamp: String?
    let message: ClaudeContentMessage?
    let requestId: String?
}

public class ClaudeParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        let sessionId = fileURL.deletingPathExtension().lastPathComponent
        
        // Simulating line-by-line reading for JSONL
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fallbackDate = fileAttributes?[.modificationDate] as? Date ?? Date()
        let fallbackTimestamp = Int64(fallbackDate.timeIntervalSince1970 * 1000)
        
        var messages: [UnifiedMessage] = []
        var processedHashes: Set<String> = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8) else { continue }
            
            do {
                let entry = try JSONDecoder().decode(ClaudeEntry.self, from: data)
                
                if entry.type == "assistant" {
                    guard let message = entry.message else { continue }
                    guard let usage = message.usage else { continue }
                    guard let model = message.model else { continue }
                    
                    var dedupKey: String? = nil
                    if let msgId = message.id, let reqId = entry.requestId {
                        let hash = "\(msgId):\(reqId)"
                        if processedHashes.contains(hash) {
                            continue
                        }
                        processedHashes.insert(hash)
                        dedupKey = hash
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
                    
                    let rawInput = usage.input_tokens ?? 0
                    let cacheRead = usage.cache_read_input_tokens ?? 0
                    let cacheWrite = usage.cache_creation_input_tokens ?? 0
                    
                    // Anthropic's input_tokens already EXCLUDES cacheRead but INCLUDES cacheWrite.
                    // To follow our standard where 'input' field is only tokens charged at base rate:
                    let baseInput = max(0, rawInput - cacheWrite)
                    
                    let breakdown = TokenBreakdown(
                        input: baseInput,
                        output: max(0, usage.output_tokens ?? 0),
                        cacheRead: max(0, cacheRead),
                        cacheWrite: max(0, cacheWrite),
                        reasoning: 0
                    )
                    
                    messages.append(UnifiedMessage(
                        client: "claude",
                        modelId: model,
                        providerId: "anthropic",
                        sessionId: sessionId,
                        timestamp: timestamp,
                        tokens: breakdown,
                        cost: 0.0,
                        dedupKey: dedupKey
                    ))
                }
            } catch {
                // Handling headless formats or errors skipped for brevity, matching simple path
                continue
            }
        }
        
        return messages
    }
}
