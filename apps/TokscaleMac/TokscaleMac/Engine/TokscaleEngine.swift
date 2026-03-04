import Foundation

public class TokscaleEngine {
    
    public init() {}
    
    public func ensurePricingInitialized() async {
        var litellmData = (try? await LiteLLM.fetch()) ?? LiteLLM.loadCachedIgnoreTTL() ?? [:]
        
        // Use builtin as fallback for missing or invalid data in LiteLLM
        if let builtin = LiteLLM.loadBuiltin() {
            for (key, pricing) in builtin {
                if let existing = litellmData[key] {
                    // Only override if existing data has no valid pricing
                    let hasInput = existing.inputCostPerToken != nil && existing.inputCostPerToken! > 0
                    let hasOutput = existing.outputCostPerToken != nil && existing.outputCostPerToken! > 0
                    if !hasInput && !hasOutput {
                        litellmData[key] = pricing
                    }
                } else {
                    // Key doesn't exist in remote data, use builtin
                    litellmData[key] = pricing
                }
            }
        }
        
        let openrouterData = await OpenRouter.fetchAllModels()
        
        PricingService.shared.initialize(litellmData: litellmData, openrouterData: openrouterData)
    }
    
    // Parses and prices all client messages, deduplicating them.
    private func fetchAndParseAllMessages(scanResult: ScanResult, clients: [String]) async -> [UnifiedMessage] {
        await ensurePricingInitialized()
        
        let processMessage: (UnifiedMessage) -> UnifiedMessage = { msg in
            var m = msg
            let calculated = PricingService.shared.calculateCost(
                modelId: m.modelId,
                input: m.tokens.input,
                output: m.tokens.output,
                cacheRead: m.tokens.cacheRead,
                cacheWrite: m.tokens.cacheWrite,
                reasoning: m.tokens.reasoning
            )
            if calculated > 0 || m.cost == 0 {
                m.cost = calculated
            }
            return m
        }

        let hasAnyUsage: (UnifiedMessage) -> Bool = { msg in
            let t = msg.tokens
            return t.input > 0 ||
                t.output > 0 ||
                t.cacheRead > 0 ||
                t.cacheWrite > 0 ||
                t.reasoning > 0 ||
                msg.cost > 0
        }
        
        print("[tokscale] ScanResult total files: \(scanResult.totalFiles())")
        for (client, files) in scanResult.files {
            if !files.isEmpty {
                print("[tokscale]  - \(client.rawValue): \(files.count) files")
            }
        }
        
        var allMessages: [UnifiedMessage] = []
        var allSeen = Set<String>()
        
        let safeParse: (URL, (URL) throws -> [UnifiedMessage]) -> [UnifiedMessage] = { url, parser in
            do {
                return try parser(url)
            } catch {
                print("[tokscale] Parser error for \(url): \(error)")
                return []
            }
        }
        
        func shouldAdd(_ msg: UnifiedMessage) -> Bool {
            let key = msg.dedupKey ?? ""
            if key.isEmpty { return true }
            if allSeen.contains(key) { return false }
            allSeen.insert(key)
            return true
        }

        // 1. OpenCode
        if clients.contains("opencode") {
            var openCodeMessages: [UnifiedMessage] = []
            var openCodeSource = "json"

            if let dbURL = scanResult.opencodeDB {
                let dbMessages = safeParse(dbURL, OpenCodeParser.parse)
                if !dbMessages.isEmpty {
                    openCodeMessages = dbMessages
                    openCodeSource = "db"
                } else {
                    print("[tokscale] OpenCode DB yielded no messages, falling back to JSON storage")
                }
            }

            if openCodeMessages.isEmpty {
                for url in scanResult.files[.opencode] ?? [] {
                    openCodeMessages.append(contentsOf: safeParse(url, OpenCodeParser.parse))
                }
            }

            for m in openCodeMessages {
                let priced = processMessage(m)
                if !hasAnyUsage(priced) { continue }
                if shouldAdd(priced) {
                    allMessages.append(priced)
                }
            }
            print("[tokscale] OpenCode source: \(openCodeSource)")
            print("[tokscale] OpenCode total: \(allMessages.count) messages")
        }
        
        // 2. Claude
        if clients.contains("claude") {
            for url in scanResult.files[.claude] ?? [] {
                let msgs = safeParse(url, ClaudeParser.parse)
                for m in msgs {
                    let priced = processMessage(m)
                    if !hasAnyUsage(priced) { continue }
                    if shouldAdd(priced) {
                        allMessages.append(priced)
                    }
                }
            }
            print("[tokscale] Claude total: \(allMessages.count) messages")
        }
        
        let clientConfigs: [(String, [ClientId], (URL) throws -> [UnifiedMessage])] = [
            ("gemini", [.gemini], GeminiParser.parse),
            ("cursor", [.cursor], CursorParser.parse),
            ("amp", [.amp], AmpParser.parse),
            ("codex", [.codex], CodexParser.parse),
            ("droid", [.droid], DroidParser.parse),
            ("openclaw", [.openclaw], OpenClawParser.parse),
            ("pi", [.pi], PiParser.parse),
            ("kimi", [.kimi], KimiParser.parse)
        ]
        
        for config in clientConfigs {
            if clients.contains(config.0) {
                for type in config.1 {
                    for url in scanResult.files[type] ?? [] {
                        let msgs = safeParse(url, config.2)
                        for m in msgs {
                            let priced = processMessage(m)
                            if !hasAnyUsage(priced) { continue }
                            if shouldAdd(priced) {
                                allMessages.append(priced)
                            }
                        }
                    }
                }
                print("[tokscale] \(config.0) total: \(allMessages.count) messages")
            }
        }
        
        return allMessages
    }
    
    private func filterMessages(messages: [UnifiedMessage], options: ReportOptions) -> [UnifiedMessage] {
        var filtered = messages
        if let year = options.year {
            let prefix = "\(year)-"
            filtered = filtered.filter { $0.date.hasPrefix(prefix) }
        }
        if let since = options.since {
            filtered = filtered.filter { $0.date >= since }
        }
        if let until = options.until {
            filtered = filtered.filter { $0.date <= until }
        }
        return filtered
    }
    
    public func getModelReport(options: ReportOptions) async throws -> ModelReport {
        let startTime = Date()
        await ensurePricingInitialized()
        
        let homeDir = options.homeDir ?? NSHomeDirectory()
        let clients = options.clients ?? ClientId.allCases.map { $0.rawValue }
        
        let scanResult = Scanner.scanAllClients(homeDir: homeDir, clients: clients)
        let allMessages = await fetchAndParseAllMessages(scanResult: scanResult, clients: clients)
        let filtered = filterMessages(messages: allMessages, options: options)
        
        var modelMap: [String: ModelUsage] = [:]
        
        for msg in filtered {
            let normalized = normalizeModelForGrouping(modelId: msg.modelId)
            let key: String
            switch options.groupBy {
            case .model: key = normalized
            case .clientModel: key = "\(msg.client):\(normalized)"
            case .clientProviderModel: key = "\(msg.client):\(msg.providerId):\(normalized)"
            }
            
            if modelMap[key] == nil {
                modelMap[key] = ModelUsage(
                    client: msg.client,
                    mergedClients: options.groupBy == .model ? msg.client : nil,
                    model: normalized,
                    provider: msg.providerId,
                    input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, messageCount: 0, cost: 0.0
                )
            }
            
            var entry = modelMap[key]!
            
            if options.groupBy == .model {
                if !entry.client.components(separatedBy: ", ").contains(msg.client) {
                    entry.client = "\(entry.client), \(msg.client)"
                }
                if let merged = entry.mergedClients, !merged.components(separatedBy: ", ").contains(msg.client) {
                    entry.mergedClients = "\(merged), \(msg.client)"
                }
            }
            
            if options.groupBy != .clientProviderModel && !entry.provider.components(separatedBy: ", ").contains(msg.providerId) {
                entry.provider = "\(entry.provider), \(msg.providerId)"
            }
            
            entry.input += msg.tokens.input
            entry.output += msg.tokens.output
            entry.cacheRead += msg.tokens.cacheRead
            entry.cacheWrite += msg.tokens.cacheWrite
            entry.reasoning += msg.tokens.reasoning
            entry.messageCount += 1
            entry.cost += msg.cost
            
            modelMap[key] = entry
        }
        
        var entries = modelMap.values.map { entry -> ModelUsage in
            var m = entry
            let providers = Array(Set(m.provider.components(separatedBy: ", "))).sorted()
            m.provider = providers.joined(separator: ", ")
            return m
        }
        
        entries.sort { a, b in
            if a.cost.isNaN && b.cost.isNaN { return false }
            if a.cost.isNaN { return false }
            if b.cost.isNaN { return true }
            return a.cost > b.cost
        }
        
        let totalInput = entries.reduce(0) { $0 + $1.input }
        let totalOutput = entries.reduce(0) { $0 + $1.output }
        let totalCacheRead = entries.reduce(0) { $0 + $1.cacheRead }
        let totalCacheWrite = entries.reduce(0) { $0 + $1.cacheWrite }
        let totalMessages = entries.reduce(0) { $0 + $1.messageCount }
        let totalCost = entries.reduce(0.0) { $0 + $1.cost }
        
        let processingTime = UInt32(-startTime.timeIntervalSinceNow * 1000)
        
        return ModelReport(
            entries: entries,
            totalInput: totalInput,
            totalOutput: totalOutput,
            totalCacheRead: totalCacheRead,
            totalCacheWrite: totalCacheWrite,
            totalMessages: totalMessages,
            totalCost: totalCost,
            processingTimeMs: processingTime
        )
    }
    
    public func getMonthlyReport(options: ReportOptions) async throws -> MonthlyReport {
        let startTime = Date()
        await ensurePricingInitialized()
        
        let homeDir = options.homeDir ?? NSHomeDirectory()
        let clients = options.clients ?? ClientId.allCases.map { $0.rawValue }
        
        let scanResult = Scanner.scanAllClients(homeDir: homeDir, clients: clients)
        let allMessages = await fetchAndParseAllMessages(scanResult: scanResult, clients: clients)
        let filtered = filterMessages(messages: allMessages, options: options)
        
        class MonthAgg {
            var models = Set<String>()
            var input: Int64 = 0
            var output: Int64 = 0
            var cacheRead: Int64 = 0
            var cacheWrite: Int64 = 0
            var messageCount: Int32 = 0
            var cost: Double = 0.0
        }
        
        var monthMap: [String: MonthAgg] = [:]
        
        for msg in filtered {
            if msg.date.count < 7 { continue }
            let month = String(msg.date.prefix(7))
            
            if monthMap[month] == nil { monthMap[month] = MonthAgg() }
            let entry = monthMap[month]!
            
            entry.models.insert(normalizeModelForGrouping(modelId: msg.modelId))
            entry.input += msg.tokens.input
            entry.output += msg.tokens.output
            entry.cacheRead += msg.tokens.cacheRead
            entry.cacheWrite += msg.tokens.cacheWrite
            entry.messageCount += 1
            entry.cost += msg.cost
        }
        
        var entries = monthMap.map { (month, agg) in
            MonthlyUsage(
                month: month,
                models: Array(agg.models).sorted(),
                input: agg.input,
                output: agg.output,
                cacheRead: agg.cacheRead,
                cacheWrite: agg.cacheWrite,
                messageCount: agg.messageCount,
                cost: agg.cost
            )
        }
        
        entries.sort { $0.month < $1.month }
        
        let totalCost = entries.reduce(0.0) { $0 + $1.cost }
        let processingTime = UInt32(-startTime.timeIntervalSinceNow * 1000)
        
        return MonthlyReport(
            entries: entries,
            totalCost: totalCost,
            processingTimeMs: processingTime
        )
    }
    
    public func generateGraph(options: ReportOptions) async throws -> GraphResult {
        let startTime = Date()
        await ensurePricingInitialized()
        
        let homeDir = options.homeDir ?? NSHomeDirectory()
        let clients = options.clients ?? ClientId.allCases.map { $0.rawValue }
        
        let scanResult = Scanner.scanAllClients(homeDir: homeDir, clients: clients)
        let allMessages = await fetchAndParseAllMessages(scanResult: scanResult, clients: clients)
        let filtered = filterMessages(messages: allMessages, options: options)
        
        let contributions = Aggregator.aggregateByDate(messages: filtered)
        
        let processingTime = UInt32(-startTime.timeIntervalSinceNow * 1000)
        return Aggregator.generateGraphResult(contributions: contributions, processingTimeMs: processingTime)
    }
}
