import Foundation

/// Service that delegates to the native TokscaleEngine.
actor TokscaleService {
    private let engine: TokscaleEngine

    init() {
        self.engine = TokscaleEngine()
    }

    // MARK: - Public API

    func fetchModelReport() async throws -> ModelReport {
        return try await engine.getModelReport(options: ReportOptions())
    }

    func fetchMonthlyReport() async throws -> MonthlyReport {
        return try await engine.getMonthlyReport(options: ReportOptions())
    }

    func fetchGraphData() async throws -> GraphResult {
        return try await engine.generateGraph(options: ReportOptions())
    }
}

