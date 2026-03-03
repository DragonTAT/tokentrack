import Foundation

struct OpenClawCost: Codable {
    let total: Double?
}

struct OpenClawUsage: Codable {
    let input: Int64?
    let output: Int64?
    let cacheRead: Int64?
    let cacheWrite: Int64?
    let totalTokens: Int64?
    let cost: OpenClawCost?
}

struct OpenClawMessagePayload: Codable {
    let role: String?
    let usage: OpenClawUsage?
    let timestamp: Int64?
}

struct OpenClawEntry: Codable {
    let type: String
    let message: OpenClawMessagePayload?
    let modelId: String?
    let provider: String?
}

struct SessionEntry: Codable {
    let sessionId: String
    let sessionFile: String?
}

public class OpenClawParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        if fileURL.lastPathComponent == "sessions.json" {
            return parseIndex(fileURL: fileURL)
        } else {
            return parseTranscript(fileURL: fileURL)
        }
    }
    
    private static func parseIndex(fileURL: URL) -> [UnifiedMessage] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        // Simple parsing mapping dynamic keys
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        
        var messages: [UnifiedMessage] = []
        let dir = fileURL.deletingLastPathComponent()
        
        for (_, value) in dict {
            if let entryDict = value as? [String: Any],
               let sessionId = entryDict["sessionId"] as? String {
                let sessionFile = entryDict["sessionFile"] as? String
                
                let sessionURL: URL
                if let file = sessionFile, !file.trimmingCharacters(in: .whitespaces).isEmpty {
                    if file.hasPrefix("/") {
                        sessionURL = URL(fileURLWithPath: file)
                    } else {
                        sessionURL = dir.appendingPathComponent(file)
                    }
                } else {
                    sessionURL = dir.appendingPathComponent("\(sessionId).jsonl")
                }
                
                if FileManager.default.fileExists(atPath: sessionURL.path) {
                    messages.append(contentsOf: parseSession(sessionURL, sessionId: sessionId))
                }
            }
        }
        
        return messages
    }
    
    private static func parseTranscript(fileURL: URL) -> [UnifiedMessage] {
        let sessionId = fileURL.deletingPathExtension().lastPathComponent
        return parseSession(fileURL, sessionId: sessionId)
    }
    
    private static func parseSession(_ fileURL: URL, sessionId: String) -> [UnifiedMessage] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fallbackDate = fileAttributes?[.modificationDate] as? Date ?? Date()
        let fallbackTimestamp = Int64(fallbackDate.timeIntervalSince1970 * 1000)
        
        var messages: [UnifiedMessage] = []
        var currentModel: String? = nil
        var currentProvider: String? = nil
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            guard let data = trimmed.data(using: .utf8),
                  let entry = try? JSONDecoder().decode(OpenClawEntry.self, from: data) else { continue }
            
            if entry.type == "model_change" {
                if let modelId = entry.modelId { currentModel = modelId }
                if let provider = entry.provider { currentProvider = provider }
            } else if entry.type == "message" {
                if let msg = entry.message, msg.role == "assistant", let usage = msg.usage {
                    guard let model = currentModel else { continue }
                    
                    let provider = currentProvider ?? "unknown"
                    let timestamp = msg.timestamp ?? fallbackTimestamp
                    let cost = usage.cost?.total ?? 0.0
                    
                    messages.append(UnifiedMessage(
                        client: "openclaw",
                        modelId: model,
                        providerId: provider,
                        sessionId: sessionId,
                        timestamp: timestamp,
                        tokens: TokenBreakdown(
                            input: max(0, usage.input ?? 0),
                            output: max(0, usage.output ?? 0),
                            cacheRead: max(0, usage.cacheRead ?? 0),
                            cacheWrite: max(0, usage.cacheWrite ?? 0),
                            reasoning: 0
                        ),
                        cost: max(0.0, cost)
                    ))
                }
            }
        }
        
        return messages
    }
}
