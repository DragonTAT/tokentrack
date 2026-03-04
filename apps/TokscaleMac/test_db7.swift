import Foundation
import TokscaleMac

func main() async {
    let homeDir = NSHomeDirectory()
    let engine = TokscaleEngine()
    
    // ensure pricing
    await engine.ensurePricingInitialized()
    
    let report = try? await engine.getModelReport(options: ReportOptions(clients: ["opencode"]))
    
    if let report = report {
        print("Total cost opencode: $\(report.totalCost)")
        if report.entries.isEmpty {
            print("No entries returned from getModelReport specifically for opencode")
        }
        for entry in report.entries.prefix(5) {
            print("  - \(entry.model) cost=\(entry.cost)")
        }
    } else {
        print("Failed to get report")
    }
}
await main()
