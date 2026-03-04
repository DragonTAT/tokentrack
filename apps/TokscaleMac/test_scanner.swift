import Foundation
import TokscaleMac

import Foundation
import TokscaleMac

func main() async {
    let homeDir = NSHomeDirectory()
    let result = Scanner.scanAllClients(homeDir: homeDir, clients: ["opencode"])
    
    if let dbUrl = result.opencodeDB {
        print("Found DB: \(dbUrl.path)")
        do {
            let msgs = try OpenCodeParser.parse(fileURL: dbUrl)
            print("Parsed \(msgs.count) messages from DB")
            for msg in msgs.prefix(3) {
                print(" - \(msg.modelId): cost=\(msg.cost), tokens=\(msg.tokens.input)/\(msg.tokens.output)")
            }
        } catch {
            print("Error parsing DB: \(error)")
        }
    } else {
        print("No DB found")
    }
}

await main()

await main()
