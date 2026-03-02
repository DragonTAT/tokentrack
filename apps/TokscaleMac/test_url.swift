import Foundation
let arg = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".build/debug/TokscaleMac"
let url = URL(fileURLWithPath: arg)
let execDir = url.deletingLastPathComponent()
let resolved = execDir.appendingPathComponent("../../../TokscaleMac/Resources/tokscale").standardized.path
print("Input: \(arg)")
print("URL: \(url.path)")
print("ExecDir: \(execDir.path)")
print("Resolved: \(resolved)")
