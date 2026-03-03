import Foundation

public protocol SessionParser {
    static func parse(fileURL: URL) throws -> [UnifiedMessage]
}

extension SessionParser {
    public static func parse(fileURL: URL) throws -> [UnifiedMessage] {
        return []
    }
}
