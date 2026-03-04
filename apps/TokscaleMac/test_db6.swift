import Foundation
import SQLite3
import TokscaleMac

func testDB() {
    let fileURL = URL(fileURLWithPath: "/Users/chen/.local/share/opencode/opencode.db")
    do {
        let msgs = try OpenCodeParser.parse(fileURL: fileURL)
        print("Successfully parsed opencode db. Count: \(msgs.count)")
        for msg in msgs.prefix(3) {
            print("  - \(msg.modelId) - cost=\(msg.cost) tokens=\(msg.tokens.input)/\(msg.tokens.output)")
        }
    } catch {
        print("Error: \(error)")
    }
}
testDB()
