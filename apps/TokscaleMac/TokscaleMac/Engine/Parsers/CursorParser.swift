import Foundation

public class CursorParser: SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        
        var messages: [UnifiedMessage] = []
        let lines = content.components(separatedBy: .newlines)
        
        guard let header = lines.first else { return [] }
        if !header.contains("Date") || !header.contains("Model") {
            return []
        }
        
        let headerFields = parseCSVLine(header)
        let hasKindColumn = headerFields.contains(where: { $0.trimmingCharacters(in: .whitespaces) == "Kind" })
        
        let modelIdx: Int
        let inputCacheWriteIdx: Int
        let inputNoCacheIdx: Int
        let cacheReadIdx: Int
        let outputIdx: Int
        let costIdx: Int
        
        if hasKindColumn {
            modelIdx = 2
            inputCacheWriteIdx = 4
            inputNoCacheIdx = 5
            cacheReadIdx = 6
            outputIdx = 7
            costIdx = 9
        } else {
            modelIdx = 1
            inputCacheWriteIdx = 2
            inputNoCacheIdx = 3
            cacheReadIdx = 4
            outputIdx = 5
            costIdx = 7
        }
        
        let fileName = fileURL.lastPathComponent
        let accountId: String
        if fileName == "usage.csv" {
            accountId = "active"
        } else if fileName.hasPrefix("usage.") && fileName.hasSuffix(".csv") {
            let stem = fileName.dropFirst("usage.".count).dropLast(".csv".count)
            accountId = String(stem).reduce(into: "") { result, c in
                if c.isLetter || c.isNumber || c == "-" || c == "_" || c == "." {
                    result.append(c)
                } else {
                    result.append("-")
                }
            }
        } else {
            accountId = "unknown"
        }
        
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let fields = parseCSVLine(trimmed)
            let minFields = costIdx + 1
            if fields.count < minFields { continue }
            
            let dateStr = fields[0].trimmingCharacters(in: CharacterSet(charactersIn: " \""))
            let model = fields[modelIdx].trimmingCharacters(in: CharacterSet(charactersIn: " \""))
            
            let inputWithCacheWrite = Int64(fields[inputCacheWriteIdx].trimmingCharacters(in: CharacterSet(charactersIn: " \""))) ?? 0
            let inputWithoutCacheWrite = Int64(fields[inputNoCacheIdx].trimmingCharacters(in: CharacterSet(charactersIn: " \""))) ?? 0
            let cacheRead = Int64(fields[cacheReadIdx].trimmingCharacters(in: CharacterSet(charactersIn: " \""))) ?? 0
            let outputTokens = Int64(fields[outputIdx].trimmingCharacters(in: CharacterSet(charactersIn: " \""))) ?? 0
            
            let costStr = fields[costIdx].trimmingCharacters(in: CharacterSet(charactersIn: " \"")).replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
            let cost = Double(costStr) ?? 0.0
            
            if model.isEmpty { continue }
            
            let timestamp = parseDateToTimestamp(dateStr)
            if timestamp == 0 { continue }
            
            let cacheWrite = max(0, inputWithCacheWrite - inputWithoutCacheWrite)
            let input = inputWithoutCacheWrite
            
            let providerId: String
            let lowerModel = model.lowercased()
            if lowerModel.contains("claude") || lowerModel.contains("opus") || lowerModel.contains("sonnet") || lowerModel.contains("haiku") {
                providerId = "anthropic"
            } else if lowerModel.contains("gpt") || lowerModel.contains("o1") || lowerModel.contains("o3") || lowerModel.contains("o4") {
                providerId = "openai"
            } else if lowerModel.contains("gemini") {
                providerId = "google"
            } else if lowerModel.contains("deepseek") {
                providerId = "deepseek"
            } else if lowerModel.contains("llama") {
                providerId = "meta"
            } else if lowerModel.contains("grok") {
                providerId = "xai"
            } else if lowerModel.contains("qwen") {
                providerId = "alibaba"
            } else if lowerModel.contains("mistral") {
                providerId = "mistral"
            } else {
                providerId = "cursor"
            }
            
            messages.append(UnifiedMessage(
                client: "cursor",
                modelId: model,
                providerId: providerId,
                sessionId: "cursor-\(accountId)-\(dateStr)",
                timestamp: timestamp,
                tokens: TokenBreakdown(
                    input: max(0, input),
                    output: max(0, outputTokens),
                    cacheRead: max(0, cacheRead),
                    cacheWrite: cacheWrite,
                    reasoning: 0
                ),
                cost: max(0.0, cost)
            ))
        }
        
        return messages
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        fields.append(currentField)
        
        return fields
    }
    
    private static func parseDateToTimestamp(_ dateStr: String) -> Int64 {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return Int64(date.timeIntervalSince1970 * 1000)
            }
        }
        
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            // Noon UTC
            let noon = date.addingTimeInterval(12 * 3600)
            return Int64(noon.timeIntervalSince1970 * 1000)
        }
        
        return 0
    }
}
