import Foundation

/// Service that delegates to the native TokscaleEngine.
actor TokscaleService {
    private let engine: TokscaleEngine

    init() {
        self.engine = TokscaleEngine()
    }

    // MARK: - Public API
    
    /// Unified fetch: scans file system once, returns all reports.
    func fetchAll() async throws -> TokscaleEngine.EngineSnapshot {
        return try await engine.fetchAll(options: ReportOptions(timeZone: AppSettings.shared.calendar.timeZone))
    }

    func fetchModelReport() async throws -> ModelReport {
        return try await engine.getModelReport(options: ReportOptions(timeZone: AppSettings.shared.calendar.timeZone))
    }

    func fetchMonthlyReport() async throws -> MonthlyReport {
        return try await engine.getMonthlyReport(options: ReportOptions(timeZone: AppSettings.shared.calendar.timeZone))
    }

    func fetchGraphData() async throws -> GraphResult {
        return try await engine.generateGraph(options: ReportOptions(timeZone: AppSettings.shared.calendar.timeZone))
    }
}

