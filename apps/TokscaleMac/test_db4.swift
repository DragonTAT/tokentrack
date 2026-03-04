import Foundation
import SQLite3

struct OpenCodeCache: Codable {
    let read: Int64?
    let write: Int64?
}

struct OpenCodeTokens: Codable {
    let total: Int64?
    let input: Int64?
    let output: Int64?
    let reasoning: Int64?
    let cache: OpenCodeCache?
}

struct OpenCodeTime: Codable {
    let created: Double
    let completed: Double?
}

struct OpenCodeMessage: Codable {
    let id: String?
    let sessionID: String?
    let role: String
    let modelID: String?
    let providerID: String?
    let cost: Double?
    let tokens: OpenCodeTokens?
    let time: OpenCodeTime
    let agent: String?
    let mode: String?
}

func testDB() {
    let fileURL = URL(fileURLWithPath: "/Users/chen/.local/share/opencode/opencode.db")
    var db: OpaquePointer?
    sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
    defer { sqlite3_close(db) }
    
    let query = "SELECT data FROM message WHERE json_extract(data, '$.role') = 'assistant' AND json_extract(data, '$.tokens') IS NOT NULL LIMIT 5"
    var stmt: OpaquePointer?
    sqlite3_prepare_v2(db, query, -1, &stmt, nil)
    defer { sqlite3_finalize(stmt) }
    
    while sqlite3_step(stmt) == SQLITE_ROW {
        if let dataCStr = sqlite3_column_text(stmt, 0) {
            let dataStr = String(cString: dataCStr)
            if let data = dataStr.data(using: .utf8) {
                do {
                    let msg = try JSONDecoder().decode(OpenCodeMessage.self, from: data)
                    print("Success: \(msg)")
                } catch {
                    print("Error: \(error) on data: \(dataStr.prefix(150))")
                }
            }
        }
    }
}
testDB()
