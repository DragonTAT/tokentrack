import Foundation

/// Service that calls the bundled tokscale CLI binary and parses JSON output.
actor TokscaleService {
    private let cliBinaryPath: String

    init() {
        // Priority order:
        // 1. Bundled binary in app's Resources/
        // 2. Adjacent to the executable (SPM .build/debug layout)
        // 3. Well-known install paths
        // 4. `which tokscale` fallback

        let candidates: [String] = {
            var paths: [String] = []

            // 1. Resources dir next to source (for SPM dev builds)
            if let execURL = Bundle.main.executableURL ?? URL(string: CommandLine.arguments[0]) {
                var searchDir = URL(fileURLWithPath: execURL.path)
                // Search upwards up to 4 levels to find TokscaleMac/Resources/tokscale
                for _ in 0..<4 {
                    searchDir = searchDir.deletingLastPathComponent()
                    let testPath = searchDir.appendingPathComponent("TokscaleMac/Resources/tokscale").path
                    if FileManager.default.isExecutableFile(atPath: testPath) {
                        paths.append(testPath)
                        break
                    }
                }
                
                // Also check relative to the binary directly
                paths.append(execURL.deletingLastPathComponent().appendingPathComponent("tokscale").path)
            }

            // 2. App bundle (when built as .app)
            if let bundlePath = Bundle.main.path(forResource: "tokscale", ofType: nil) {
                paths.append(bundlePath)
            }

            // 3. Well-known development path
            paths.append(
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Desktop/claude/tokentrack/target/release/tokscale").path
            )

            // 4. System paths
            paths.append("/usr/local/bin/tokscale")
            paths.append("/opt/homebrew/bin/tokscale")

            return paths
        }()

        // Find first executable
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            self.cliBinaryPath = found
            print("TokscaleService initialized with binary at: \(found)")
        } else {
            // Last resort: try `which`
            let which = Process()
            which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            which.arguments = ["tokscale"]
            let pipe = Pipe()
            which.standardOutput = pipe
            try? which.run()
            which.waitUntilExit()
            let path = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.cliBinaryPath = path.isEmpty ? "tokscale" : path
            print("TokscaleService fallback configured with path: \(self.cliBinaryPath)")
        }
    }

    // MARK: - Public API

    func fetchModelReport() async throws -> ModelReport {
        let data = try await runCLI(args: ["models", "--json", "--no-spinner"])
        return try JSONDecoder().decode(ModelReport.self, from: data)
    }

    func fetchMonthlyReport() async throws -> MonthlyReport {
        let data = try await runCLI(args: ["monthly", "--json", "--no-spinner"])
        return try JSONDecoder().decode(MonthlyReport.self, from: data)
    }

    func fetchGraphData() async throws -> GraphResult {
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokscale_graph_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        _ = try await runCLI(args: ["graph", "--output", tmpFile.path, "--no-spinner"], expectOutput: false)

        let data = try Data(contentsOf: tmpFile)
        return try JSONDecoder().decode(GraphResult.self, from: data)
    }

    // MARK: - Process Execution

    private func runCLI(args: [String], expectOutput: Bool = true) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliBinaryPath)
        process.arguments = args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMsg = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            throw TokscaleError.cliFailed(status: process.terminationStatus, message: errorMsg)
        }

        if expectOutput && outputData.isEmpty {
            throw TokscaleError.emptyOutput
        }

        return outputData
    }
}

enum TokscaleError: LocalizedError {
    case cliFailed(status: Int32, message: String)
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .cliFailed(let status, let message):
            return "CLI exited with status \(status): \(message)"
        case .emptyOutput:
            return "CLI returned empty output"
        }
    }
}
