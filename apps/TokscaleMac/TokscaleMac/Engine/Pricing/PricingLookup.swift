import Foundation

public struct ModelPricing: Codable, Equatable {
    public var inputCostPerToken: Double?
    public var outputCostPerToken: Double?
    public var cacheReadInputTokenCost: Double?
    public var cacheCreationInputTokenCost: Double?

    enum CodingKeys: String, CodingKey {
        case inputCostPerToken = "input_cost_per_token"
        case outputCostPerToken = "output_cost_per_token"
        case cacheReadInputTokenCost = "cache_read_input_token_cost"
        case cacheCreationInputTokenCost = "cache_creation_input_token_cost"
    }

    public init(
        inputCostPerToken: Double? = nil,
        outputCostPerToken: Double? = nil,
        cacheReadInputTokenCost: Double? = nil,
        cacheCreationInputTokenCost: Double? = nil
    ) {
        self.inputCostPerToken = inputCostPerToken
        self.outputCostPerToken = outputCostPerToken
        self.cacheReadInputTokenCost = cacheReadInputTokenCost
        self.cacheCreationInputTokenCost = cacheCreationInputTokenCost
    }
}

public struct LookupResult {
    public let pricing: ModelPricing
    public let source: String
    public let matchedKey: String
}

public class PricingLookup {
    private let litellm: [String: ModelPricing]
    private let openrouter: [String: ModelPricing]
    private let cursor: [String: ModelPricing]
    
    private let litellmKeys: [String]
    private let openrouterKeys: [String]
    
    private let litellmLower: [String: String]
    private let openrouterLower: [String: String]
    private let openrouterModelPart: [String: String]
    private let cursorLower: [String: String]
    
    private var lookupCache: [String: LookupResult?] = [:]
    private let cacheLock = NSLock()
    
    fileprivate static let providerPrefixes = [
        "openai/", "anthropic/", "google/", "meta-llama/", "mistralai/",
        "deepseek/", "qwen/", "cohere/", "perplexity/", "x-ai/"
    ]
    
    fileprivate static let originalProviderPrefixes = [
        "x-ai/", "xai/", "anthropic/", "openai/", "google/", "meta-llama/",
        "mistralai/", "deepseek/", "z-ai/", "qwen/", "cohere/", "perplexity/",
        "moonshotai/"
    ]
    
    fileprivate static let resellerProviderPrefixes = [
        "azure/", "azure_ai/", "bedrock/", "vertex_ai/", "together/",
        "together_ai/", "fireworks_ai/", "groq/", "openrouter/"
    ]
    
    fileprivate static let fuzzyBlocklist = ["auto", "mini", "chat", "base"]
    fileprivate static let maxLookupCacheEntries = 512
    fileprivate static let minFuzzyMatchLen = 5
    fileprivate static let minModelNameLen = 2
    fileprivate static let maxPrefixStripSegments = 2
    fileprivate static let maxSuffixStripSegments = 4
    
    public init(
        litellm: [String: ModelPricing],
        openrouter: [String: ModelPricing],
        cursor: [String: ModelPricing]
    ) {
        self.litellm = litellm
        self.openrouter = openrouter
        self.cursor = cursor
        
        self.litellmKeys = litellm.keys.sorted { $0.count > $1.count }
        self.openrouterKeys = openrouter.keys.sorted { $0.count > $1.count }
        
        var lLower = [String: String]()
        for key in litellmKeys {
            lLower[key.lowercased()] = key
        }
        self.litellmLower = lLower
        
        var oLower = [String: String]()
        var oModelPart = [String: String]()
        for key in openrouterKeys {
            let lower = key.lowercased()
            oLower[lower] = key
            if let lastSlash = lower.lastIndex(of: "/") {
                let modelPart = String(lower[lower.index(after: lastSlash)...])
                if modelPart != lower {
                    oModelPart[modelPart] = key
                }
            }
        }
        self.openrouterLower = oLower
        self.openrouterModelPart = oModelPart
        
        var cLower = [String: String]()
        for key in cursor.keys {
            cLower[key.lowercased()] = key
        }
        self.cursorLower = cLower
    }
    
    public func lookup(modelId: String) -> LookupResult? {
        cacheLock.lock()
        if let cached = lookupCache[modelId] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        let result = lookupWithSource(modelId: modelId, forceSource: nil)
        
        cacheLock.lock()
        if lookupCache.count >= Self.maxLookupCacheEntries {
            lookupCache.removeAll()
        }
        lookupCache[modelId] = result
        cacheLock.unlock()
        
        return result
    }
    
    public func lookupWithSource(modelId: String, forceSource: String?) -> LookupResult? {
        // Assume aliases are resolved before calling or handled by a separate ALIAS class.
        // For now, we will just use the raw string.
        let canonical = modelId // TODO: Add aliases.resolve_alias(model_id) if needed
        let lower = canonical.lowercased()
        
        let doLookup: (String) -> LookupResult? = { id in
            switch forceSource {
            case "litellm": return self.lookupLitellmOnly(modelId: id)
            case "openrouter": return self.lookupOpenRouterOnly(modelId: id)
            default: return self.lookupAuto(modelId: id)
            }
        }
        
        if let result = doLookup(lower) { return result }
        
        if let result = tryStripUnknownSuffix(modelId: lower, doLookup: doLookup) { return result }
        
        if let result = tryStripUnknownPrefix(modelId: lower, doLookup: doLookup) { return result }
        
        return nil
    }
    
    private func tryStripUnknownSuffix(modelId: String, doLookup: (String) -> LookupResult?) -> LookupResult? {
        let parts = modelId.components(separatedBy: "-")
        if parts.count < 2 { return nil }
        
        let maxStrip = min(parts.count - 1, Self.maxSuffixStripSegments)
        for strip in 1...maxStrip {
            let candidateParts = parts.dropLast(strip)
            let candidate = candidateParts.joined(separator: "-")
            if candidate.count >= Self.minModelNameLen {
                if let result = doLookup(candidate) {
                    return result
                }
            }
        }
        return nil
    }
    
    private func tryStripUnknownPrefix(modelId: String, doLookup: (String) -> LookupResult?) -> LookupResult? {
        let parts = modelId.components(separatedBy: "-")
        if parts.count < 2 { return nil }
        
        let maxSkip = min(parts.count - 1, Self.maxPrefixStripSegments)
        for skip in 1...maxSkip {
            let candidateParts = parts.dropFirst(skip)
            let candidate = candidateParts.joined(separator: "-")
            
            if candidate.count >= Self.minModelNameLen {
                if let result = doLookup(candidate) {
                    return result
                }
                
                if let result = tryStripUnknownSuffix(modelId: candidate, doLookup: doLookup) {
                    return result
                }
            }
        }
        return nil
    }
    
    private func lookupAuto(modelId: String) -> LookupResult? {
        if let result = exactMatchCursor(modelId: modelId) { return result }
        if let versionNormalized = normalizeVersionSeparator(modelId: modelId) {
            if let result = exactMatchCursor(modelId: versionNormalized) { return result }
        }
        
        if let result = exactMatchLitellm(modelId: modelId) { return result }
        if let result = exactMatchOpenrouter(modelId: modelId) { return result }
        
        if let versionNormalized = normalizeVersionSeparator(modelId: modelId) {
            if let result = exactMatchLitellm(modelId: versionNormalized) { return result }
            if let result = exactMatchOpenrouter(modelId: versionNormalized) { return result }
        }
        
        if let normalized = normalizeModelName(modelId: modelId) {
            if let result = exactMatchLitellm(modelId: normalized) { return result }
            if let result = exactMatchOpenrouter(modelId: normalized) { return result }
        }
        
        if let result = prefixMatchLitellm(modelId: modelId) { return result }
        if let result = prefixMatchOpenrouter(modelId: modelId) { return result }
        
        if let versionNormalized = normalizeVersionSeparator(modelId: modelId) {
            if let result = prefixMatchLitellm(modelId: versionNormalized) { return result }
            if let result = prefixMatchOpenrouter(modelId: versionNormalized) { return result }
        }
        
        if !isFuzzyEligible(modelId: modelId) { return nil }
        
        let litellmResult = fuzzyMatchLitellm(modelId: modelId)
        let openrouterResult = fuzzyMatchOpenrouter(modelId: modelId)
        
        switch (litellmResult, openrouterResult) {
        case let (l?, o?):
            let lIsOriginal = isOriginalProvider(key: l.matchedKey)
            let oIsOriginal = isOriginalProvider(key: o.matchedKey)
            let lIsReseller = isResellerProvider(key: l.matchedKey)
            let oIsReseller = isResellerProvider(key: o.matchedKey)
            
            if oIsOriginal && !lIsOriginal { return o }
            if lIsOriginal && !oIsOriginal { return l }
            if !lIsReseller && oIsReseller { return l }
            if !oIsReseller && lIsReseller { return o }
            return l
        case let (l?, nil): return l
        case let (nil, o?): return o
        case (nil, nil): return nil
        }
    }
    
    private func lookupLitellmOnly(modelId: String) -> LookupResult? {
        if let result = exactMatchLitellm(modelId: modelId) { return result }
        if let versionNormalized = normalizeVersionSeparator(modelId: modelId) {
            if let result = exactMatchLitellm(modelId: versionNormalized) { return result }
        }
        if let normalized = normalizeModelName(modelId: modelId) {
            if let result = exactMatchLitellm(modelId: normalized) { return result }
        }
        if let result = prefixMatchLitellm(modelId: modelId) { return result }
        if let versionNormalized = normalizeVersionSeparator(modelId: modelId) {
            if let result = prefixMatchLitellm(modelId: versionNormalized) { return result }
        }
        if isFuzzyEligible(modelId: modelId) {
            if let result = fuzzyMatchLitellm(modelId: modelId) { return result }
        }
        return nil
    }
    
    private func lookupOpenRouterOnly(modelId: String) -> LookupResult? {
        if let result = exactMatchOpenrouter(modelId: modelId) { return result }
        if let versionNormalized = normalizeVersionSeparator(modelId: modelId) {
            if let result = exactMatchOpenrouter(modelId: versionNormalized) { return result }
        }
        if let normalized = normalizeModelName(modelId: modelId) {
            if let result = exactMatchOpenrouter(modelId: normalized) { return result }
        }
        if let result = prefixMatchOpenrouter(modelId: modelId) { return result }
        if let versionNormalized = normalizeVersionSeparator(modelId: modelId) {
            if let result = prefixMatchOpenrouter(modelId: versionNormalized) { return result }
        }
        if isFuzzyEligible(modelId: modelId) {
            if let result = fuzzyMatchOpenrouter(modelId: modelId) { return result }
        }
        return nil
    }
    
    private func exactMatchLitellm(modelId: String) -> LookupResult? {
        guard let key = litellmLower[modelId], let pricing = litellm[key] else { return nil }
        return LookupResult(pricing: pricing, source: "LiteLLM", matchedKey: key)
    }
    
    private func exactMatchOpenrouter(modelId: String) -> LookupResult? {
        if let key = openrouterLower[modelId], let pricing = openrouter[key] {
            return LookupResult(pricing: pricing, source: "OpenRouter", matchedKey: key)
        }
        if let key = openrouterModelPart[modelId], let pricing = openrouter[key] {
            return LookupResult(pricing: pricing, source: "OpenRouter", matchedKey: key)
        }
        return nil
    }
    
    private func exactMatchCursor(modelId: String) -> LookupResult? {
        if let key = cursorLower[modelId], let pricing = cursor[key] {
            return LookupResult(pricing: pricing, source: "Cursor", matchedKey: key)
        }
        if let lastSlash = modelId.lastIndex(of: "/") {
            let modelPart = String(modelId[modelId.index(after: lastSlash)...])
            if modelPart != modelId {
                if let key = cursorLower[modelPart], let pricing = cursor[key] {
                    return LookupResult(pricing: pricing, source: "Cursor", matchedKey: key)
                }
            }
        }
        return nil
    }
    
    private func prefixMatchLitellm(modelId: String) -> LookupResult? {
        for prefix in Self.providerPrefixes {
            let key = prefix + modelId
            if let litellmKey = litellmLower[key], let pricing = litellm[litellmKey] {
                return LookupResult(pricing: pricing, source: "LiteLLM", matchedKey: litellmKey)
            }
        }
        return nil
    }
    
    private func prefixMatchOpenrouter(modelId: String) -> LookupResult? {
        for prefix in Self.providerPrefixes {
            let key = prefix + modelId
            if let orKey = openrouterLower[key], let pricing = openrouter[orKey] {
                return LookupResult(pricing: pricing, source: "OpenRouter", matchedKey: orKey)
            }
        }
        return nil
    }
    
    private func fuzzyMatchLitellm(modelId: String) -> LookupResult? {
        let family = extractModelFamily(modelId: modelId)
        var familyMatchesList: [String] = []
        
        for key in litellmKeys {
            let lowerKey = key.lowercased()
            if familyMatches(key: lowerKey, family: family) && containsModelId(key: lowerKey, modelId: modelId) {
                familyMatchesList.append(key)
            }
        }
        
        if let result = selectBestMatch(matches: familyMatchesList, dataset: litellm, source: "LiteLLM") {
            return result
        }
        
        var allMatches: [String] = []
        for key in litellmKeys {
            let lowerKey = key.lowercased()
            if containsModelId(key: lowerKey, modelId: modelId) {
                allMatches.append(key)
            }
        }
        
        return selectBestMatch(matches: allMatches, dataset: litellm, source: "LiteLLM")
    }
    
    private func fuzzyMatchOpenrouter(modelId: String) -> LookupResult? {
        let family = extractModelFamily(modelId: modelId)
        var familyMatchesList: [String] = []
        
        for key in openrouterKeys {
            let lowerKey = key.lowercased()
            let modelPart: String
            if let lastSlash = lowerKey.lastIndex(of: "/") {
                modelPart = String(lowerKey[lowerKey.index(after: lastSlash)...])
            } else {
                modelPart = lowerKey
            }
            if familyMatches(key: modelPart, family: family) && containsModelId(key: modelPart, modelId: modelId) {
                familyMatchesList.append(key)
            }
        }
        
        if let result = selectBestMatch(matches: familyMatchesList, dataset: openrouter, source: "OpenRouter") {
            return result
        }
        
        var allMatches: [String] = []
        for key in openrouterKeys {
            let lowerKey = key.lowercased()
            let modelPart: String
            if let lastSlash = lowerKey.lastIndex(of: "/") {
                modelPart = String(lowerKey[lowerKey.index(after: lastSlash)...])
            } else {
                modelPart = lowerKey
            }
            if containsModelId(key: modelPart, modelId: modelId) {
                allMatches.append(key)
            }
        }
        
        return selectBestMatch(matches: allMatches, dataset: openrouter, source: "OpenRouter")
    }
    
    private func selectBestMatch(matches: [String], dataset: [String: ModelPricing], source: String) -> LookupResult? {
        if matches.isEmpty { return nil }
        
        if let key = matches.first(where: { isOriginalProvider(key: $0) }), let pricing = dataset[key] {
            return LookupResult(pricing: pricing, source: source, matchedKey: key)
        }
        
        if let key = matches.first(where: { !isResellerProvider(key: $0) }), let pricing = dataset[key] {
            return LookupResult(pricing: pricing, source: source, matchedKey: key)
        }
        
        let key = matches[0]
        if let pricing = dataset[key] {
            return LookupResult(pricing: pricing, source: source, matchedKey: key)
        }
        return nil
    }
    
    public func calculateCost(
        modelId: String,
        input: Int64,
        output: Int64,
        cacheRead: Int64,
        cacheWrite: Int64,
        reasoning: Int64
    ) -> Double {
        guard let result = lookup(modelId: modelId) else { return 0.0 }
        
        return computeCost(
            pricing: result.pricing,
            input: input,
            output: output,
            cacheRead: cacheRead,
            cacheWrite: cacheWrite,
            reasoning: reasoning
        )
    }
}

public func computeCost(
    pricing: ModelPricing,
    input: Int64,
    output: Int64,
    cacheRead: Int64,
    cacheWrite: Int64,
    reasoning: Int64
) -> Double {
    let safePrice = { (opt: Double?) -> Double in
        guard let v = opt, v.isFinite, v >= 0 else { return 0.0 }
        return v
    }
    
    let inputClamped = Double(max(0, input))
    let outputTotal = max(0, output) + max(0, reasoning)
    let outputClamped = Double(outputTotal)
    let cacheReadClamped = Double(max(0, cacheRead))
    let cacheWriteClamped = Double(max(0, cacheWrite))
    
    let inP = safePrice(pricing.inputCostPerToken)
    let outP = safePrice(pricing.outputCostPerToken)
    
    let inputCost = inputClamped * inP
    let outputCost = outputClamped * outP
    let cacheReadCost = cacheReadClamped * safePrice(pricing.cacheReadInputTokenCost)
    let cacheWriteCost = cacheWriteClamped * safePrice(pricing.cacheCreationInputTokenCost)
    
    return inputCost + outputCost + cacheReadCost + cacheWriteCost
}

private func extractModelFamily(modelId: String) -> String {
    let lower = modelId.lowercased()
    
    if lower.contains("gpt-5") { return "gpt-5" }
    if lower.contains("gpt-4.1") { return "gpt-4.1" }
    if lower.contains("gpt-4o") { return "gpt-4o" }
    if lower.contains("gpt-4") { return "gpt-4" }
    if lower.contains("o3") { return "o3" }
    if lower.contains("o4") { return "o4" }
    
    if lower.contains("opus") { return "opus" }
    if lower.contains("sonnet") { return "sonnet" }
    if lower.contains("haiku") { return "haiku" }
    if lower.contains("claude") { return "claude" }
    
    if lower.contains("gemini-3") { return "gemini-3" }
    if lower.contains("gemini-2.5") { return "gemini-2.5" }
    if lower.contains("gemini-2") { return "gemini-2" }
    if lower.contains("gemini") { return "gemini" }
    
    if lower.contains("llama") { return "llama" }
    if lower.contains("mistral") { return "mistral" }
    if lower.contains("deepseek") { return "deepseek" }
    if lower.contains("qwen") { return "qwen" }
    
    let parts = lower.components(separatedBy: CharacterSet(charactersIn: "-_."))
    return parts.first ?? lower
}

private func familyMatches(key: String, family: String) -> Bool {
    if family.isEmpty { return true }
    return key.contains(family)
}

private func containsModelId(key: String, modelId: String) -> Bool {
    guard let range = key.range(of: modelId) else { return false }
    
    let beforeOk = range.lowerBound == key.startIndex || !key[key.index(before: range.lowerBound)].isLetter && !key[key.index(before: range.lowerBound)].isNumber
    let afterOk = range.upperBound == key.endIndex || !key[range.upperBound].isLetter && !key[range.upperBound].isNumber
    
    return beforeOk && afterOk
}

private func normalizeModelName(modelId: String) -> String? {
    let lower = modelId.lowercased()
    
    if lower.contains("opus") {
        if lower.contains("4.5") || lower.contains("4-5") { return "claude-opus-4-5" }
        else if lower.contains("4") { return "claude-opus-4" }
    }
    if lower.contains("sonnet") {
        if lower.contains("4.5") || lower.contains("4-5") { return "claude-sonnet-4-5" }
        else if lower.contains("4") && !lower.contains("3.") && !lower.contains("3-") { return "claude-sonnet-4" }
        else if lower.contains("3.7") || lower.contains("3-7") { return "claude-3-7-sonnet" }
        else if lower.contains("3.5") || lower.contains("3-5") { return "claude-3.5-sonnet" }
    }
    if lower.contains("haiku") {
        if lower.contains("4.5") || lower.contains("4-5") { return "claude-haiku-4-5" }
        else if lower.contains("3.5") || lower.contains("3-5") { return "claude-3.5-haiku" }
    }
    
    return nil
}

private func normalizeVersionSeparator(modelId: String) -> String? {
    var result = ""
    let chars = Array(modelId)
    var changed = false
    
    for i in 0..<chars.count {
        if chars[i] == "-", i > 0, i < chars.count - 1, chars[i-1].isNumber, chars[i+1].isNumber {
            let isMultiDigitBefore = i >= 2 && chars[i-2].isNumber
            let isMultiDigitAfter = i + 2 < chars.count && chars[i+2].isNumber
            let looksLikeDate = isMultiDigitBefore || isMultiDigitAfter
            
            if looksLikeDate {
                result.append(chars[i])
            } else {
                result.append(".")
                changed = true
            }
        } else {
            result.append(chars[i])
        }
    }
    
    return changed ? result : nil
}

private func isFuzzyEligible(modelId: String) -> Bool {
    if modelId.count < PricingLookup.minFuzzyMatchLen { return false }
    return !PricingLookup.fuzzyBlocklist.contains(modelId)
}

private func isOriginalProvider(key: String) -> Bool {
    let lower = key.lowercased()
    return PricingLookup.originalProviderPrefixes.contains(where: { lower.hasPrefix($0) })
}

private func isResellerProvider(key: String) -> Bool {
    let lower = key.lowercased()
    return PricingLookup.resellerProviderPrefixes.contains(where: { lower.hasPrefix($0) })
}
