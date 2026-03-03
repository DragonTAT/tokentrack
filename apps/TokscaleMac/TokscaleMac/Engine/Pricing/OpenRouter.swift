import Foundation

public class OpenRouter {
    private static let cacheFilename = "pricing-openrouter.json"
    private static let modelsURL = URL(string: "https://openrouter.ai/api/v1/models")!
    private static let maxRetries = 3
    private static let initialBackoffMs: TimeInterval = 0.2
    
    // Structs for API responses
    struct ModelListPricing: Codable {
        let prompt: String
        let completion: String
    }
    
    struct ModelListItem: Codable {
        let id: String
        let pricing: ModelListPricing?
    }
    
    struct ModelsListResponse: Codable {
        let data: [ModelListItem]
    }
    
    struct EndpointPricing: Codable {
        let prompt: String
        let completion: String
        let input_cache_read: String?
        let input_cache_write: String?
    }
    
    struct Endpoint: Codable {
        let provider_name: String
        let pricing: EndpointPricing
    }
    
    struct EndpointData: Codable {
        let id: String
        let endpoints: [Endpoint]
    }
    
    struct EndpointsResponse: Codable {
        let data: EndpointData
    }
    
    private static func getAuthorProviderName(modelId: String) -> String? {
        let parts = modelId.split(separator: "/")
        guard let prefix = parts.first else { return nil }
        
        switch prefix.lowercased() {
        case "z-ai": return "Z.AI"
        case "x-ai": return "xAI"
        case "anthropic": return "Anthropic"
        case "openai": return "OpenAI"
        case "google": return "Google"
        case "meta-llama": return "Meta"
        case "mistralai": return "Mistral"
        case "deepseek": return "DeepSeek"
        case "qwen": return "Alibaba"
        case "cohere": return "Cohere"
        case "perplexity": return "Perplexity"
        case "moonshotai": return "Moonshot AI"
        default: return nil
        }
    }
    
    public static func loadCached() -> [String: ModelPricing]? {
        return PricingCache.loadCache(filename: cacheFilename)
    }
    
    private static func parsePrice(_ s: String?) -> Double? {
        guard let s = s, let val = Double(s.trimmingCharacters(in: .whitespaces)), val.isFinite, val >= 0 else {
            return nil
        }
        return val
    }
    
    private static func fetchAuthorPricing(modelId: String, fallbackPricing: ModelPricing?) async -> (String, ModelPricing)? {
        guard let authorName = getAuthorProviderName(modelId: modelId) else {
            return fallbackPricing.map { (modelId, $0) }
        }
        
        let url = URL(string: "https://openrouter.ai/api/v1/models/\(modelId)/endpoints")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return fallbackPricing.map { (modelId, $0) }
            }
            
            let endpointsResponse = try JSONDecoder().decode(EndpointsResponse.self, from: data)
            guard let authorEndpoint = endpointsResponse.data.endpoints.first(where: { $0.provider_name == authorName }) else {
                return fallbackPricing.map { (modelId, $0) }
            }
            
            guard let inputCost = parsePrice(authorEndpoint.pricing.prompt),
                  let outputCost = parsePrice(authorEndpoint.pricing.completion) else {
                return fallbackPricing.map { (modelId, $0) }
            }
            
            let pricing = ModelPricing(
                inputCostPerToken: inputCost,
                outputCostPerToken: outputCost,
                cacheReadInputTokenCost: parsePrice(authorEndpoint.pricing.input_cache_read),
                cacheCreationInputTokenCost: parsePrice(authorEndpoint.pricing.input_cache_write)
            )
            
            return (modelId, pricing)
        } catch {
            return fallbackPricing.map { (modelId, $0) }
        }
    }
    
    public static func fetchAllModels() async -> [String: ModelPricing] {
        if let cached = loadCached() {
            return cached
        }
        
        var modelsWithFallback: [(String, ModelPricing?)] = []
        var lastError: String?
        
        for attempt in 0..<maxRetries {
            do {
                var request = URLRequest(url: modelsURL)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 30
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 {
                    lastError = "HTTP \(httpResponse.statusCode)"
                    if attempt < maxRetries - 1 {
                        let delay = initialBackoffMs * pow(2.0, Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    continue
                }
                
                guard httpResponse.statusCode == 200 else {
                    print("[tokscale] OpenRouter models API returned \(httpResponse.statusCode)")
                    break
                }
                
                let modelsResponse = try JSONDecoder().decode(ModelsListResponse.self, from: data)
                modelsWithFallback = modelsResponse.data.map { item in
                    var fallback: ModelPricing?
                    if let p = item.pricing, let input = parsePrice(p.prompt), let output = parsePrice(p.completion) {
                        fallback = ModelPricing(inputCostPerToken: input, outputCostPerToken: output, cacheReadInputTokenCost: nil, cacheCreationInputTokenCost: nil)
                    }
                    return (item.id, fallback)
                }
                break // Success
                
            } catch {
                lastError = "Network error: \(error)"
                if attempt < maxRetries - 1 {
                    let delay = initialBackoffMs * pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        if modelsWithFallback.isEmpty {
            if let err = lastError {
                print("[tokscale] OpenRouter fetch failed: \(err)")
            }
            return [:]
        }
        
        let modelsWithAuthors = modelsWithFallback.filter { getAuthorProviderName(modelId: $0.0) != nil }
        var result = [String: ModelPricing]()
        
        // Use Swift Concurrency Task Group to fetch author endpoints concurrently
        await withTaskGroup(of: (String, ModelPricing)?.self) { group in
            for (modelId, fallback) in modelsWithAuthors {
                group.addTask {
                    await fetchAuthorPricing(modelId: modelId, fallbackPricing: fallback)
                }
            }
            
            for await item in group {
                if let (id, pricing) = item {
                    result[id] = pricing
                }
            }
        }
        
        if !result.isEmpty {
            PricingCache.saveCache(filename: cacheFilename, data: result)
        }
        
        return result
    }
}
