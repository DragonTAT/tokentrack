import Foundation
import SQLite3

struct OpenCodeCache: Codable {
    let read: Int64?
    let write: Int64?
}

struct OpenCodeTokens: Codable {
    let input: Int64?
    let output: Int64?
    let reasoning: Int64?
    let cache: OpenCodeCache?
}

struct OpenCodeMessage: Codable {
    let role: String
    let tokens: OpenCodeTokens?
}

func testDB() {
    let fileURL = URL(fileURLWithPath: "/Users/chen/.local/share/opencode/opencode.db")
    var db: OpaquePointer?
    if sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) != SQLITE_OK {
        print("Failed to open DB")
        return
    }
    defer { sqlite3_close(db) }
    
    let query = "SELECT data FROM message LIMIT 5"
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
        print("Failed to prepare")
        return
    }
    defer { sqlite3_finalize(stmt) }
    
    var count = 0
    while sqlite3_step(stmt) == SQLITE_ROW {
        count += 1
        if let dataCStr = sqlite3_column_text(stmt, 0) {
            let dataStr = String(cString: dataCStr)
            print("Row \(count): \(dataStr.prefix(100))...")
            
            if let data = dataStr.data(using: .utf8) {
                do {
                    let msg = try JSONDecoder().decode(OpenCodeMessage.self, from: data)
                    print("  Parsed: role=\(msg.role), tokens=\(msg.tokens != nil)")
                } catch {
                    print("  Decode error: \(error)")
                }
            }
        }
    }
    print("Total rows step: \(count)")
}

testDB()
