import Foundation
import TokscaleMac

@main
struct TokscaleTest {
    static func main() async {
        let engine = TokscaleEngine()
        await engine.ensurePricingInitialized()
        
        do {
            let report = try await engine.getModelReport(options: ReportOptions())
            print("Total entries: \(report.entries.count)")
            
            var opencodeCount = 0
            for entry in report.entries {
                print("Model: \(entry.model), Client: \(entry.client), Cost: \(entry.cost)")
                if entry.client == "opencode" {
                    opencodeCount += 1
                }
            }
            print("Total Opencode entries: \(opencodeCount)")
        } catch {
            print("Failed: \(error)")
        }
    }
}
