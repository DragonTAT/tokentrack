import Foundation
import SQLite3

struct OpenCodeCache: Codable {
    let read: Int64?
    let write: Int64?
}

struct OpenCodeTokens: Codable {
    let input: Int64?
    let output: Int64?
    let reasoning: Int64?
    let cache: OpenCodeCache?
}

struct OpenCodeTime: Codable {
    let created: Double
    let completed: Double?
}

struct OpenCodeMessage: Codable {
    let id: String?
    let sessionID: String?
    let role: String
    let modelID: String?
    let providerID: String?
    let cost: Double?
    let tokens: OpenCodeTokens?
    let time: OpenCodeTime
    let agent: String?
    let mode: String?
}

public class OpenCodeParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        if fileURL.pathExtension == "db" || fileURL.pathExtension == "sqlite" {
            return parseSQLite(fileURL: fileURL)
        } else {
            if let msg = parseJSON(fileURL: fileURL) {
                return [msg]
            }
            return []
        }
    }
    
    private static func normalizeAgentName(_ agent: String) -> String {
        let agentLower = agent.lowercased()
        if agentLower.contains("plan") {
            if agentLower.contains("omo") || agentLower.contains("sisyphus") {
                return "Planner-Sisyphus"
            }
            return agent
        }
        if agentLower == "omo" || agentLower == "sisyphus" {
            return "Sisyphus"
        }
        return agent
    }
    
    private static func parseJSON(fileURL: URL) -> UnifiedMessage? {
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let role = json["role"] as? String, role == "assistant",
              let modelId = json["modelID"] as? String,
              let tokensDict = json["tokens"] as? [String: Any] else {
            return nil
        }
        
        let providerId = json["providerID"] as? String ?? "unknown"
        let sessionId = json["sessionID"] as? String ?? "unknown"
        let dedupKey = json["id"] as? String ?? fileURL.deletingPathExtension().lastPathComponent
        
        let agentRaw = (json["mode"] as? String) ?? (json["agent"] as? String)
        let agent = agentRaw.map { normalizeAgentName($0) }
        
        var timestamp: Int64 = 0
        if let timeDict = json["time"] as? [String: Any], let created = timeDict["created"] as? Double {
            timestamp = Int64(created)
        }
        
        let costDouble = (json["cost"] as? NSNumber)?.doubleValue ?? 0.0
        
        let rawInput = (tokensDict["input"] as? NSNumber)?.int64Value ?? 0
        let output = (tokensDict["output"] as? NSNumber)?.int64Value ?? 0
        let reasoning = (tokensDict["reasoning"] as? NSNumber)?.int64Value ?? 0
        
        var cacheRead: Int64 = 0
        var cacheWrite: Int64 = 0
        if let cacheDict = tokensDict["cache"] as? [String: Any] {
            cacheRead = (cacheDict["read"] as? NSNumber)?.int64Value ?? 0
            cacheWrite = (cacheDict["write"] as? NSNumber)?.int64Value ?? 0
        }
        
        // Follow standard: baseInput = totalInput - cached
        let baseInput = max(0, rawInput - cacheRead - cacheWrite)
        
        let breakdown = TokenBreakdown(
            input: baseInput,
            output: max(0, output),
            cacheRead: max(0, cacheRead),
            cacheWrite: max(0, cacheWrite),
            reasoning: max(0, reasoning)
        )
        
        return UnifiedMessage(
            client: "opencode",
            modelId: modelId,
            providerId: providerId,
            sessionId: sessionId,
            timestamp: timestamp,
            tokens: breakdown,
            cost: max(0.0, costDouble),
            agent: agent,
            dedupKey: dedupKey
        )
    }
    
    private static func parseSQLite(fileURL: URL) -> [UnifiedMessage] {
        var messages: [UnifiedMessage] = []
        var db: OpaquePointer?
        
        if sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) != SQLITE_OK {
            return []
        }
        
        defer { sqlite3_close(db) }
        
        let query = "SELECT id, session_id, data FROM message WHERE json_extract(data, '$.role') = 'assistant' AND json_extract(data, '$.tokens') IS NOT NULL"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
            return []
        }
        
        defer { sqlite3_finalize(stmt) }
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idCStr = sqlite3_column_text(stmt, 0),
                  let sessionIdCStr = sqlite3_column_text(stmt, 1),
                  let dataCStr = sqlite3_column_text(stmt, 2) else { continue }
            
            let id = String(cString: idCStr)
            let sessionId = String(cString: sessionIdCStr)
            let dataStr = String(cString: dataCStr)
            
            guard let data = dataStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let role = json["role"] as? String, role == "assistant",
                  let modelId = json["modelID"] as? String,
                  let tokensDict = json["tokens"] as? [String: Any] else {
                continue
            }
            
            let providerId = json["providerID"] as? String ?? "unknown"
            
            let agentRaw = (json["mode"] as? String) ?? (json["agent"] as? String)
            let agent = agentRaw.map { normalizeAgentName($0) }
            
            var timestamp: Int64 = 0
            if let timeDict = json["time"] as? [String: Any], let created = timeDict["created"] as? Double {
                timestamp = Int64(created)
            }
            
            let costDouble = (json["cost"] as? NSNumber)?.doubleValue ?? 0.0
            
            let rawInput = (tokensDict["input"] as? NSNumber)?.int64Value ?? 0
            let output = (tokensDict["output"] as? NSNumber)?.int64Value ?? 0
            let reasoning = (tokensDict["reasoning"] as? NSNumber)?.int64Value ?? 0
            
            var cacheRead: Int64 = 0
            var cacheWrite: Int64 = 0
            if let cacheDict = tokensDict["cache"] as? [String: Any] {
                cacheRead = (cacheDict["read"] as? NSNumber)?.int64Value ?? 0
                cacheWrite = (cacheDict["write"] as? NSNumber)?.int64Value ?? 0
            }
            
            let baseInput = max(0, rawInput - cacheRead - cacheWrite)
            
            let breakdown = TokenBreakdown(
                input: baseInput,
                output: max(0, output),
                cacheRead: max(0, cacheRead),
                cacheWrite: max(0, cacheWrite),
                reasoning: max(0, reasoning)
            )
            
            messages.append(UnifiedMessage(
                client: "opencode",
                modelId: modelId,
                providerId: providerId,
                sessionId: sessionId,
                timestamp: timestamp,
                tokens: breakdown,
                cost: max(0.0, costDouble),
                agent: agent,
                dedupKey: id
            ))
        }
        print("[tokscale] OpenCode SQLite parsed \(messages.count) messages")
        return messages
    }
}
