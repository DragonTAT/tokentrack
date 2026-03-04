import Foundation

struct DroidTokenUsage: Codable {
    let inputTokens: Int64?
    let outputTokens: Int64?
    let cacheCreationTokens: Int64?
    let cacheReadTokens: Int64?
    let thinkingTokens: Int64?
}

struct DroidSettingsJson: Codable {
    let model: String?
    let providerLock: String?
    let providerLockTimestamp: String?
    let tokenUsage: DroidTokenUsage?
}

public class DroidParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let settings = try? JSONDecoder().decode(DroidSettingsJson.self, from: data) else { return [] }
        
        guard let usage = settings.tokenUsage else { return [] }
        
        let inT = usage.inputTokens ?? 0
        let outT = usage.outputTokens ?? 0
        let crT = usage.cacheReadTokens ?? 0
        let cwT = usage.cacheCreationTokens ?? 0
        let thT = usage.thinkingTokens ?? 0
        let totalTokens = inT + outT + crT + cwT + thT
        
        if totalTokens == 0 { return [] }
        
        let fileStem = fileURL.deletingPathExtension().deletingPathExtension().lastPathComponent
        let sessionId = fileStem == "unknown" ? "unknown" : fileStem
        
        // Simple provider inference fallback map
        func inferProvider(model: String) -> String {
            let lower = model.lowercased()
            if lower.contains("claude") || lower.contains("opus") || lower.contains("sonnet") || lower.contains("haiku") {
                return "anthropic"
            } else if lower.contains("gpt") || lower.contains("o1") || lower.contains("o3") {
                return "openai"
            } else if lower.contains("gemini") {
                return "google"
            } else if lower.contains("grok") {
                return "xai"
            } else {
                return "unknown"
            }
        }
        
        let provider = settings.providerLock ?? inferProvider(model: settings.model ?? "")
        
        func normalizeModelName(_ model: String) -> String {
            var normalized = model
            if normalized.hasPrefix("custom:") {
                normalized = String(normalized.dropFirst("custom:".count))
            }
            
            var result = ""
            var inBracket = false
            for ch in normalized {
                if ch == "[" { inBracket = true }
                else if ch == "]" { inBracket = false }
                else if !inBracket { result.append(ch) }
            }
            normalized = result
            
            while normalized.hasSuffix("-") {
                normalized = String(normalized.dropLast())
            }
            
            normalized = normalized.lowercased()
            
            // Remove consecutive hyphens
            var collapsed = ""
            var lastWasHyphen = false
            for ch in normalized {
                if ch == "-" {
                    if !lastWasHyphen { collapsed.append(ch) }
                    lastWasHyphen = true
                } else {
                    collapsed.append(ch)
                    lastWasHyphen = false
                }
            }
            
            return collapsed
        }
        
        func getDefaultModel(provider: String) -> String {
            let pLower = provider.lowercased()
            if pLower == "anthropic" { return "claude-unknown" }
            if pLower == "openai" { return "gpt-unknown" }
            if pLower == "google" { return "gemini-unknown" }
            if pLower == "xai" { return "grok-unknown" }
            return "\(pLower)-unknown"
        }
        
        let jsonlPath = fileURL.path.replacingOccurrences(of: ".settings.json", with: ".jsonl")
        
        func extractModelFromJsonl() -> String? {
            guard let content = try? String(contentsOfFile: jsonlPath, encoding: .utf8) else { return nil }
            let lines = content.components(separatedBy: .newlines)
            for line in lines.prefix(500) {
                if let range = line.range(of: "Model: ") {
                    let afterModel = String(line[range.upperBound...])
                    var modelPart = ""
                    for ch in afterModel {
                        if ch == "[" || ch == "\\" || ch == "\"" { break }
                        modelPart.append(ch)
                    }
                    let trimmed = modelPart.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        return normalizeModelName(trimmed)
                    }
                }
            }
            return nil
        }
        
        let model: String
        if let m = settings.model {
            model = normalizeModelName(m)
        } else if let m = extractModelFromJsonl() {
            model = m
        } else {
            model = getDefaultModel(provider: provider)
        }
        
        var timestamp: Int64 = 0
        if let tsString = settings.providerLockTimestamp {
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
            let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fallbackDate = fileAttributes?[.modificationDate] as? Date ?? Date()
            timestamp = Int64(fallbackDate.timeIntervalSince1970 * 1000)
        }
        
        return [UnifiedMessage(
            client: "droid",
            modelId: model,
            providerId: provider,
            sessionId: sessionId,
            timestamp: timestamp,
            tokens: TokenBreakdown(
                input: max(0, usage.inputTokens ?? 0),
                output: max(0, usage.outputTokens ?? 0),
                cacheRead: max(0, usage.cacheReadTokens ?? 0),
                cacheWrite: max(0, usage.cacheCreationTokens ?? 0),
                reasoning: max(0, usage.thinkingTokens ?? 0)
            ),
            cost: 0.0
        )]
    }
}
