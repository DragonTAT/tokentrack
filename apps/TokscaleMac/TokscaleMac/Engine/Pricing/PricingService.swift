import Foundation

public class PricingService {
    public static let shared = PricingService()
    
    private var lookup: PricingLookup?
    private let initializationLock = NSLock()
    private var isInitialized = false
    
    private let excludedLiteLLMPrefixes = ["github_copilot/"]
    
    private init() {
        // Defer fetch to initialization
    }
    
    public func initialize(litellmData: [String: ModelPricing], openrouterData: [String: ModelPricing]) {
        initializationLock.lock()
        defer { initializationLock.unlock() }
        
        // Allow re-initialization to update pricing data
        
        let filteredLiteLLM = filterLiteLLMData(litellmData)
        let cursorOverrides = buildCursorOverrides()
        
        self.lookup = PricingLookup(
            litellm: filteredLiteLLM,
            openrouter: openrouterData,
            cursor: cursorOverrides
        )
        self.isInitialized = true
    }
    
    private func filterLiteLLMData(_ data: [String: ModelPricing]) -> [String: ModelPricing] {
        var filtered = [String: ModelPricing]()
        for (key, pricing) in data {
            let lower = key.lowercased()
            let isExcluded = excludedLiteLLMPrefixes.contains { lower.hasPrefix($0) }
            if !isExcluded {
                filtered[key] = pricing
            }
        }
        return filtered
    }
    
    private func buildCursorOverrides() -> [String: ModelPricing] {
        var overrides = [String: ModelPricing]()
        
        let entries: [(id: String, input: Double, output: Double, cacheRead: Double?)] = [
            ("gpt-5.3", 0.00000175, 0.000014, 1.75e-7),
            ("gpt-5.3-codex", 0.00000175, 0.000014, 1.75e-7),
            ("gpt-5.3-codex-spark", 0.00000175, 0.000014, 1.75e-7),
            ("gpt-5.2-codex", 0.00000175, 0.000014, 1.75e-7),
            ("minimax-m2.5-free", 0.0, 0.0, 0.0)
        ]
        
        for entry in entries {
            overrides[entry.id] = ModelPricing(
                inputCostPerToken: entry.input,
                outputCostPerToken: entry.output,
                cacheReadInputTokenCost: entry.cacheRead,
                cacheCreationInputTokenCost: nil
            )
        }
        
        return overrides
    }
    
    public func lookupWithSource(modelId: String, forceSource: String? = nil) -> LookupResult? {
        // Ensure initialize has been called; if not, return nil or handle gracefully
        guard let lookup = lookup else { return nil }
        return lookup.lookupWithSource(modelId: modelId, forceSource: forceSource)
    }
    
    public func calculateCost(
        modelId: String,
        input: Int64,
        output: Int64,
        cacheRead: Int64,
        cacheWrite: Int64,
        reasoning: Int64
    ) -> Double {
        guard let lookup = lookup else { return 0.0 }
        return lookup.calculateCost(
            modelId: modelId,
            input: input,
            output: output,
            cacheRead: cacheRead,
            cacheWrite: cacheWrite,
            reasoning: reasoning
        )
    }
}
