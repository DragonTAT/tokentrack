import Foundation

public class PricingCache {
    private static let cacheTTL: TimeInterval = 3600 // 1 hour
    
    public static func getCacheDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let tokscaleDir = appSupport.appendingPathComponent("Tokscale", isDirectory: true)
        if !FileManager.default.fileExists(atPath: tokscaleDir.path) {
            try? FileManager.default.createDirectory(at: tokscaleDir, withIntermediateDirectories: true)
        }
        return tokscaleDir
    }
    
    public static func getCachePath(filename: String) -> URL {
        return getCacheDirectory().appendingPathComponent(filename)
    }
    
    struct CachedData<T: Codable>: Codable {
        let timestamp: TimeInterval
        let data: T
    }
    
    public static func loadCache<T: Codable>(filename: String, ignoreTTL: Bool = false) -> T? {
        let fileURL = getCachePath(filename: filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        
        do {
            let cached = try JSONDecoder().decode(CachedData<T>.self, from: data)
            let now = Date().timeIntervalSince1970
            
            if !ignoreTTL {
                if cached.timestamp > now || (now - cached.timestamp) > cacheTTL {
                    return nil // Expired
                }
            }
            return cached.data
        } catch {
            return nil
        }
    }
    
    public static func saveCache<T: Codable>(filename: String, data: T) {
        let cached = CachedData(timestamp: Date().timeIntervalSince1970, data: data)
        let fileURL = getCachePath(filename: filename)
        
        do {
            let encoded = try JSONEncoder().encode(cached)
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(".\(filename).\(UUID().uuidString).tmp")
            
            try encoded.write(to: tempFile, options: .atomic)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tempFile, to: fileURL)
        } catch {
            print("[tokscale] Failed to save cache to \(fileURL.path): \(error)")
        }
    }
}
