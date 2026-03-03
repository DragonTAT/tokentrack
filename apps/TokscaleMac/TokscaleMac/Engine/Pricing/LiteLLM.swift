import Foundation

public class LiteLLM {
    private static let cacheFilename = "pricing-litellm.json"
    private static let pricingURL = URL(string: "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json")!
    private static let maxRetries = 3
    private static let initialBackoffMs: TimeInterval = 0.2
    
    public typealias PricingDataset = [String: ModelPricing]
    
    public static func loadCached() -> PricingDataset? {
        return PricingCache.loadCache(filename: cacheFilename)
    }
    
    public static func loadCachedIgnoreTTL() -> PricingDataset? {
        return PricingCache.loadCache(filename: cacheFilename, ignoreTTL: true)
    }
    
    public static func loadBuiltin() -> PricingDataset? {
        guard let url = Bundle.module.url(forResource: "builtin", withExtension: "json") else {
            print("[tokscale] Warning: builtin.json not found in Bundle.module")
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            print("[tokscale] Warning: Failed to read builtin.json data")
            return nil
        }
        do {
            return try JSONDecoder().decode(PricingDataset.self, from: data)
        } catch {
            print("[tokscale] Error decoding builtin.json: \(error)")
            return nil
        }
    }
    
    public static func fetch() async throws -> PricingDataset {
        if let cached = loadCached() {
            return cached
        }
        
        var lastError: Error?
        let session = URLSession(configuration: .ephemeral)
        
        for attempt in 0..<maxRetries {
            do {
                var request = URLRequest(url: pricingURL)
                request.timeoutInterval = 30
                
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 {
                    print("[tokscale] LiteLLM HTTP \(httpResponse.statusCode) (attempt \(attempt + 1)/\(maxRetries))")
                    if attempt < maxRetries - 1 {
                        let delay = initialBackoffMs * pow(2.0, Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    continue
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("[tokscale] LiteLLM HTTP \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse)
                }
                
                let dataset = try JSONDecoder().decode(PricingDataset.self, from: data)
                PricingCache.saveCache(filename: cacheFilename, data: dataset)
                return dataset
                
            } catch {
                print("[tokscale] LiteLLM network/parse error (attempt \(attempt + 1)/\(maxRetries)): \(error)")
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = initialBackoffMs * pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        if let builtin = loadBuiltin() {
            print("[tokscale] Falling back to builtin Litellm pricing")
            return builtin
        }
        
        throw lastError ?? URLError(.unknown)
    }
}
