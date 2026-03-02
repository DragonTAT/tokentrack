import Foundation

/// Service that calls tokscale CLI binary and parses JSON output.
actor TokscaleService {
    private let cliBinaryPath: String

    init() {
        // Find the tokscale binary
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/claude/tokentrack/target/release/tokscale").path,
            "/usr/local/bin/tokscale",
            "/opt/homebrew/bin/tokscale",
        ]

        // Check which one exists
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            self.cliBinaryPath = found
        } else {
            // Try to find via `which`
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
        // Graph command writes JSON to a file, not stdout
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
