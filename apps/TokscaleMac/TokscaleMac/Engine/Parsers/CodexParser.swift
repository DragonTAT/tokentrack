import Foundation

struct CodexTokenUsage: Codable {
    let input_tokens: Int64?
    let output_tokens: Int64?
    let cached_input_tokens: Int64?
    let cache_read_input_tokens: Int64?
}

struct CodexInfo: Codable {
    let model: String?
    let model_name: String?
    let last_token_usage: CodexTokenUsage?
    let total_token_usage: CodexTokenUsage?
}

struct CodexPayload: Codable {
    let type: String?
    let model: String?
    let model_name: String?
    let info: CodexInfo?
    let source: String?
}

struct CodexEntry: Codable {
    let type: String
    let timestamp: String?
    let payload: CodexPayload?
}

struct CodexHeadlessUsage {
    let input: Int64
    let output: Int64
    let cached: Int64
    let model: String?
    let timestamp_ms: Int64?
}

public class CodexParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        let sessionId = fileURL.deletingPathExtension().lastPathComponent
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fallbackDate = fileAttributes?[.modificationDate] as? Date ?? Date()
        let fallbackTimestamp = Int64(fallbackDate.timeIntervalSince1970 * 1000)
        
        var messages: [UnifiedMessage] = []
        var currentModel: String? = nil
        var previousTotals: (input: Int64, output: Int64, cached: Int64)? = nil
        var sessionIsHeadless = false
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            var handled = false
            
            if let data = trimmed.data(using: .utf8),
               let entry = try? JSONDecoder().decode(CodexEntry.self, from: data) {
                
                if let payload = entry.payload {
                    if entry.type == "session_meta" && payload.source == "exec" {
                        sessionIsHeadless = true
                    }
                    if entry.type == "turn_context" {
                        currentModel = extractModel(payload)
                        handled = true
                    }
                    
                    if entry.type == "event_msg" && payload.type == "token_count" {
                        if let m = extractModel(payload) {
                            currentModel = m
                        }
                        
                        if let info = payload.info {
                            if let m = info.model ?? info.model_name {
                                currentModel = m
                            }
                            
                            let model = currentModel ?? "unknown"
                            
                            let input: Int64
                            let output: Int64
                            let cached: Int64
                            
                            if let last = info.last_token_usage {
                                let totalInput = last.input_tokens ?? 0
                                cached = last.cached_input_tokens ?? last.cache_read_input_tokens ?? 0
                                input = max(0, totalInput - cached)
                                output = last.output_tokens ?? 0
                            } else if let total = info.total_token_usage, let prev = previousTotals {
                                let currInput = total.input_tokens ?? 0
                                let currOutput = total.output_tokens ?? 0
                                let currCached = total.cached_input_tokens ?? total.cache_read_input_tokens ?? 0
                                
                                let deltaInput = max(0, currInput - prev.input)
                                cached = max(0, currCached - prev.cached)
                                input = max(0, deltaInput - cached)
                                output = max(0, currOutput - prev.output)
                            } else {
                                continue
                            }
                            
                            if let total = info.total_token_usage {
                                previousTotals = (
                                    input: total.input_tokens ?? 0,
                                    output: total.output_tokens ?? 0,
                                    cached: total.cached_input_tokens ?? total.cache_read_input_tokens ?? 0
                                )
                            }
                            
                            if input == 0 && output == 0 && cached == 0 {
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
                            
                            let agent: String? = sessionIsHeadless ? "headless" : nil
                            
                            messages.append(UnifiedMessage(
                                client: "codex",
                                modelId: model,
                                providerId: "openai",
                                sessionId: sessionId,
                                timestamp: timestamp,
                                tokens: TokenBreakdown(
                                    input: max(0, input),
                                    output: max(0, output),
                                    cacheRead: max(0, cached),
                                    cacheWrite: 0,
                                    reasoning: 0
                                ),
                                cost: 0.0,
                                agent: agent
                            ))
                            handled = true
                        }
                    }
                }
                
                if entry.type == "session_meta" {
                    handled = true
                }
            }
            
            if handled { continue }
            
            if let msg = parseHeadlessLine(trimmed, sessionId: sessionId, currentModel: &currentModel, fallbackTimestamp: fallbackTimestamp) {
                var finalMsg = msg
                if sessionIsHeadless && finalMsg.agent == nil {
                    finalMsg.agent = "headless"
                }
                messages.append(finalMsg)
            }
        }
        
        return messages
    }
    
    private static func extractModel(_ payload: CodexPayload) -> String? {
        if let m = payload.model, !m.isEmpty { return m }
        if let m = payload.model_name, !m.isEmpty { return m }
        if let m = payload.info?.model, !m.isEmpty { return m }
        if let m = payload.info?.model_name, !m.isEmpty { return m }
        return nil
    }
    
    private static func parseHeadlessLine(_ line: String, sessionId: String, currentModel: inout String?, fallbackTimestamp: Int64) -> UnifiedMessage? {
        // Simplified headless dictionary parsing (assuming simple JSON keys matching standard OpenAI usage)
        guard let data = line.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let usageData = dict["usage"] as? [String: Any] ??
                        (dict["data"] as? [String: Any])?["usage"] as? [String: Any] ??
                        (dict["result"] as? [String: Any])?["usage"] as? [String: Any] ??
                        (dict["response"] as? [String: Any])?["usage"] as? [String: Any]
        
        guard let usage = usageData else { return nil }
        
        let inputTokens = (usage["input_tokens"] as? Int64) ?? (usage["prompt_tokens"] as? Int64) ?? (usage["input"] as? Int64) ?? 0
        let outputTokens = (usage["output_tokens"] as? Int64) ?? (usage["completion_tokens"] as? Int64) ?? (usage["output"] as? Int64) ?? 0
        let cachedTokens = (usage["cached_input_tokens"] as? Int64) ?? (usage["cache_read_input_tokens"] as? Int64) ?? (usage["cached_tokens"] as? Int64) ?? 0
        
        let modelFromDict = (dict["model"] as? String) ?? (dict["model_name"] as? String) ??
                            ((dict["data"] as? [String: Any])?["model"] as? String) ??
                            ((dict["data"] as? [String: Any])?["model_name"] as? String) ??
                            ((dict["response"] as? [String: Any])?["model"] as? String)
                            
        if let m = modelFromDict {
            currentModel = m
        }
        
        let model = modelFromDict ?? currentModel ?? "unknown"
        
        var ts = fallbackTimestamp
        if let tsStr = dict["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            if let d = formatter.date(from: tsStr) {
                ts = Int64(d.timeIntervalSince1970 * 1000)
            }
        }
        
        let finalInput = max(0, inputTokens - cachedTokens)
        if finalInput == 0 && outputTokens == 0 && cachedTokens == 0 { return nil }
        
        return UnifiedMessage(
            client: "codex",
            modelId: model,
            providerId: "openai",
            sessionId: sessionId,
            timestamp: ts,
            tokens: TokenBreakdown(
                input: finalInput,
                output: max(0, outputTokens),
                cacheRead: max(0, cachedTokens),
                cacheWrite: 0,
                reasoning: 0
            ),
            cost: 0.0
        )
    }
}
