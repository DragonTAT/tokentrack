import Foundation

fileprivate class DayAccumulator {
    var totals = DailyTotals()
    var tokenBreakdown = TokenBreakdown()
    var clients: [String: ClientContribution] = [:]
    
    init() {}
    
    func addMessage(_ msg: UnifiedMessage) {
        let totalTokens = msg.tokens.input + msg.tokens.output + msg.tokens.cacheRead + msg.tokens.cacheWrite + msg.tokens.reasoning
        
        totals.tokens += totalTokens
        totals.cost += msg.cost ?? 0.0
        totals.messages += 1
        
        tokenBreakdown.input += msg.tokens.input
        tokenBreakdown.output += msg.tokens.output
        tokenBreakdown.cacheRead += msg.tokens.cacheRead
        tokenBreakdown.cacheWrite += msg.tokens.cacheWrite
        tokenBreakdown.reasoning += msg.tokens.reasoning
        
        let normalizedModel = normalizeModelForGrouping(modelId: msg.modelId)
        let key = "\(msg.client):\(normalizedModel)"
        
        if clients[key] == nil {
            clients[key] = ClientContribution(
                client: msg.client,
                modelId: normalizedModel,
                providerId: msg.providerId,
                tokens: TokenBreakdown(),
                cost: 0.0,
                messages: 0
            )
        }
        
        var clientEntry = clients[key]!
        
        let existingProviders = clientEntry.providerId.components(separatedBy: ", ")
        if !existingProviders.contains(msg.providerId) {
            clientEntry.providerId = "\(clientEntry.providerId), \(msg.providerId)"
        }
        
        clientEntry.tokens.input += msg.tokens.input
        clientEntry.tokens.output += msg.tokens.output
        clientEntry.tokens.cacheRead += msg.tokens.cacheRead
        clientEntry.tokens.cacheWrite += msg.tokens.cacheWrite
        clientEntry.tokens.reasoning += msg.tokens.reasoning
        clientEntry.cost += msg.cost ?? 0.0
        clientEntry.messages += 1
        
        let providers = Array(Set(clientEntry.providerId.components(separatedBy: ", "))).sorted()
        clientEntry.providerId = providers.joined(separator: ", ")
        
        clients[key] = clientEntry
    }
    
    func merge(_ other: DayAccumulator) {
        totals.tokens += other.totals.tokens
        totals.cost += other.totals.cost
        totals.messages += other.totals.messages
        
        tokenBreakdown.input += other.tokenBreakdown.input
        tokenBreakdown.output += other.tokenBreakdown.output
        tokenBreakdown.cacheRead += other.tokenBreakdown.cacheRead
        tokenBreakdown.cacheWrite += other.tokenBreakdown.cacheWrite
        tokenBreakdown.reasoning += other.tokenBreakdown.reasoning
        
        for (key, clientContrib) in other.clients {
            if clients[key] == nil {
                clients[key] = ClientContribution(
                    client: clientContrib.client,
                    modelId: clientContrib.modelId,
                    providerId: clientContrib.providerId,
                    tokens: TokenBreakdown(),
                    cost: 0.0,
                    messages: 0
                )
            }
            
            var entry = clients[key]!
            let newProviders = clientContrib.providerId.components(separatedBy: ", ")
            for provider in newProviders {
                let existing = entry.providerId.components(separatedBy: ", ")
                if !existing.contains(provider) {
                    entry.providerId = "\(entry.providerId), \(provider)"
                }
            }
            
            entry.tokens.input += clientContrib.tokens.input
            entry.tokens.output += clientContrib.tokens.output
            entry.tokens.cacheRead += clientContrib.tokens.cacheRead
            entry.tokens.cacheWrite += clientContrib.tokens.cacheWrite
            entry.tokens.reasoning += clientContrib.tokens.reasoning
            entry.cost += clientContrib.cost
            entry.messages += clientContrib.messages
            
            clients[key] = entry
        }
        
        for (key, var entry) in clients {
            let providers = Array(Set(entry.providerId.components(separatedBy: ", "))).sorted()
            entry.providerId = providers.joined(separator: ", ")
            clients[key] = entry
        }
    }
    
    func intoContribution(date: String) -> DailyContribution {
        let finalTokenBreakdown = TokenBreakdown(
            input: max(0, tokenBreakdown.input),
            output: max(0, tokenBreakdown.output),
            cacheRead: max(0, tokenBreakdown.cacheRead),
            cacheWrite: max(0, tokenBreakdown.cacheWrite),
            reasoning: max(0, tokenBreakdown.reasoning)
        )
        
        let clientContribs: [ClientContribution] = clients.values.map { s in
            var sc = s
            sc.tokens.input = max(0, sc.tokens.input)
            sc.tokens.output = max(0, sc.tokens.output)
            sc.tokens.cacheRead = max(0, sc.tokens.cacheRead)
            sc.tokens.cacheWrite = max(0, sc.tokens.cacheWrite)
            sc.tokens.reasoning = max(0, sc.tokens.reasoning)
            sc.cost = max(0.0, sc.cost)
            return sc
        }
        
        return DailyContribution(
            date: date,
            totals: DailyTotals(
                tokens: max(0, totals.tokens),
                cost: max(0.0, totals.cost),
                messages: max(0, totals.messages)
            ),
            intensity: 0,
            tokenBreakdown: finalTokenBreakdown,
            clients: clientContribs
        )
    }
}

fileprivate class YearAccumulator {
    var tokens: Int64 = 0
    var cost: Double = 0.0
    var start: String = ""
    var end: String = ""
}

public class Aggregator {
    
    public static func aggregateByDate(messages: [UnifiedMessage]) -> [DailyContribution] {
        if messages.isEmpty { return [] }
        
        // In Swift, we process sequentially or use TaskGroups. For simple arrays, sequential is often fast enough.
        // We can optimize if needed. For now, a simple loop is sufficient and thread-safe.
        var dailyMap: [String: DayAccumulator] = [:]
        
        for msg in messages {
            let dateStr = msg.date
            if dailyMap[dateStr] == nil {
                dailyMap[dateStr] = DayAccumulator()
            }
            dailyMap[dateStr]?.addMessage(msg)
        }
        
        var contributions: [DailyContribution] = dailyMap.map { (date, acc) in
            acc.intoContribution(date: date)
        }
        
        contributions.sort { $0.date < $1.date }
        
        calculateIntensities(contributions: &contributions)
        
        return contributions
    }
    
    public static func calculateSummary(contributions: [DailyContribution]) -> DataSummary {
        let totalTokens = contributions.reduce(Int64(0)) { $0 + $1.totals.tokens }
        let totalCost = contributions.reduce(0.0) { $0 + $1.totals.cost }
        let activeDays = Int32(contributions.filter { $0.totals.tokens > 0 }.count)
        let maxCost = contributions.map { $0.totals.cost }.max() ?? 0.0
        
        var clientsSet = Set<String>()
        var modelsSet = Set<String>()
        
        for c in contributions {
            for s in c.clients {
                clientsSet.insert(s.client)
                modelsSet.insert(s.modelId)
            }
        }
        
        return DataSummary(
            totalTokens: totalTokens,
            totalCost: totalCost,
            totalDays: Int32(contributions.count),
            activeDays: activeDays,
            averagePerDay: activeDays > 0 ? (totalCost / Double(activeDays)) : 0.0,
            maxCostInSingleDay: maxCost,
            clients: Array(clientsSet).sorted(),
            models: Array(modelsSet).sorted()
        )
    }
    
    public static func calculateYears(contributions: [DailyContribution]) -> [YearSummary] {
        var yearsMap: [String: YearAccumulator] = [:]
        
        for c in contributions {
            if c.date.count < 4 { continue }
            
            let year = String(c.date.prefix(4))
            let entry = yearsMap[year] ?? YearAccumulator()
            yearsMap[year] = entry
            
            entry.tokens += c.totals.tokens
            entry.cost += c.totals.cost
            
            if entry.start.isEmpty || c.date < entry.start {
                entry.start = c.date
            }
            if entry.end.isEmpty || c.date > entry.end {
                entry.end = c.date
            }
        }
        
        var years = yearsMap.map { (year, acc) in
            YearSummary(
                year: year,
                totalTokens: acc.tokens,
                totalCost: acc.cost,
                rangeStart: acc.start,
                rangeEnd: acc.end
            )
        }
        
        years.sort { $0.year < $1.year }
        return years
    }
    
    public static func generateGraphResult(contributions: [DailyContribution], processingTimeMs: UInt32) -> GraphResult {
        let summary = calculateSummary(contributions: contributions)
        let years = calculateYears(contributions: contributions)
        
        let dateRangeStart = contributions.first?.date ?? ""
        let dateRangeEnd = contributions.last?.date ?? ""
        
        let formatter = ISO8601DateFormatter()
        
        return GraphResult(
            meta: GraphMeta(
                generatedAt: formatter.string(from: Date()),
                version: "1.0", // TODO: Get app version
                dateRangeStart: dateRangeStart,
                dateRangeEnd: dateRangeEnd,
                processingTimeMs: processingTimeMs
            ),
            summary: summary,
            years: years,
            contributions: contributions
        )
    }
    
    private static func calculateIntensities(contributions: inout [DailyContribution]) {
        let maxCost = contributions.map { $0.totals.cost }.max() ?? 0.0
        
        if maxCost == 0.0 { return }
        
        for i in 0..<contributions.count {
            let ratio = contributions[i].totals.cost / maxCost
            let intensity: UInt8
            if ratio >= 0.75 {
                intensity = 4
            } else if ratio >= 0.5 {
                intensity = 3
            } else if ratio >= 0.25 {
                intensity = 2
            } else if ratio > 0.0 {
                intensity = 1
            } else {
                intensity = 0
            }
            contributions[i].intensity = intensity
        }
    }
}

public func normalizeModelForGrouping(modelId: String) -> String {
    var name = modelId.lowercased()
    
    if name.count > 9 {
        let startIdx = name.index(name.endIndex, offsetBy: -8)
        let potentialDate = String(name[startIdx...])
        // Very basic check for 8 digits and preceding dash
        if potentialDate.allSatisfy({ $0.isNumber }) && name[name.index(name.endIndex, offsetBy: -9)] == "-" {
            name = String(name.prefix(name.count - 9))
        }
    }
    
    if name.contains("claude") {
        var result = ""
        let chars = Array(name)
        for i in 0..<chars.count {
            if chars[i] == ".", i > 0, i < chars.count - 1, chars[i-1].isNumber, chars[i+1].isNumber {
                result.append("-")
            } else {
                result.append(chars[i])
            }
        }
        name = result
    }
    
    return name
}
