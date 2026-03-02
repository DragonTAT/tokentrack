import Foundation
let execDir = URL(fileURLWithPath: "/Users/chen/Desktop/claude/tokentrack/apps/TokscaleMac/.build/debug")
let paths = [
    execDir.appendingPathComponent("../../../TokscaleMac/Resources/tokscale").standardized.path,
    execDir.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("TokscaleMac/Resources/tokscale").path
]
print(paths)
