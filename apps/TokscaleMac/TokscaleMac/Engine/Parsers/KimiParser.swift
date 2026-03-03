import Foundation

struct KimiTokenUsage: Codable {
    let inputOther: Int64?
    let output: Int64?
    let inputCacheRead: Int64?
    let inputCacheCreation: Int64?
    
    enum CodingKeys: String, CodingKey {
        case inputOther = "input_other"
        case output
        case inputCacheRead = "input_cache_read"
        case inputCacheCreation = "input_cache_creation"
    }
}

struct KimiStatusPayload: Codable {
    let tokenUsage: KimiTokenUsage?
    let messageId: String?
    
    enum CodingKeys: String, CodingKey {
        case tokenUsage = "token_usage"
        case messageId = "message_id"
    }
}

struct KimiWireMessage: Codable {
    let type: String
    let payload: KimiStatusPayload?
}

struct KimiWireLine: Codable {
    let timestamp: Double?
    let message: KimiWireMessage?
    let type: String?
}

public class KimiParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        
        let sessionGroupId = fileURL.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
        let sessionUuid = fileURL.deletingLastPathComponent().lastPathComponent
        let sessionId = "\(sessionGroupId)/\(sessionUuid)"
        
        let configURL = fileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("config.json")
        var model = "kimi-for-coding"
        if let configData = try? Data(contentsOf: configURL),
           let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
           let m = config["model"] as? String, !m.isEmpty {
            model = m
        }
        
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fallbackDate = fileAttributes?[.modificationDate] as? Date ?? Date()
        let fallbackTimestamp = Int64(fallbackDate.timeIntervalSince1970 * 1000)
        
        var messages: [UnifiedMessage] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            guard let data = trimmed.data(using: .utf8),
                  let wireLine = try? JSONDecoder().decode(KimiWireLine.self, from: data) else { continue }
            
            if wireLine.type == "metadata" { continue }
            
            guard let message = wireLine.message, message.type == "StatusUpdate",
                  let payload = message.payload, let tokenUsage = payload.tokenUsage else { continue }
            
            let timestampMs: Int64
            if let ts = wireLine.timestamp {
                timestampMs = Int64(ts * 1000.0)
            } else {
                timestampMs = fallbackTimestamp
            }
            
            let input = max(0, tokenUsage.inputOther ?? 0)
            let output = max(0, tokenUsage.output ?? 0)
            let cacheRead = max(0, tokenUsage.inputCacheRead ?? 0)
            let cacheWrite = max(0, tokenUsage.inputCacheCreation ?? 0)
            
            if input + output + cacheRead + cacheWrite == 0 { continue }
            
            messages.append(UnifiedMessage(
                client: "kimi",
                modelId: model,
                providerId: "moonshot",
                sessionId: sessionId,
                timestamp: timestampMs,
                tokens: TokenBreakdown(
                    input: input,
                    output: output,
                    cacheRead: cacheRead,
                    cacheWrite: cacheWrite,
                    reasoning: 0
                ),
                cost: 0.0,
                dedupKey: payload.messageId
            ))
        }
        
        return messages
    }
}
