import Foundation

public struct ScanResult {
    public var files: [ClientId: [URL]] = [:]
    public var opencodeDB: URL? = nil
    
    public init() {
        for client in ClientId.allCases {
            files[client] = []
        }
    }
    
    public func totalFiles() -> Int {
        return files.values.reduce(0) { $0 + $1.count }
    }
}

public class Scanner {
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func headlessRoots(homeDir: String) -> [URL] {
        if let envPath = ProcessInfo.processInfo.environment["TOKSCALE_HEADLESS_DIR"], !envPath.isEmpty {
            return [URL(fileURLWithPath: envPath)]
        }
        
        let configRoot = URL(fileURLWithPath: homeDir).appendingPathComponent(".config/tokscale/headless")
        let macRoot = URL(fileURLWithPath: homeDir).appendingPathComponent("Library/Application Support/tokscale/headless")
        
        return [configRoot, macRoot]
    }
    
    public func scanDirectory(root: URL, pattern: String) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        
        var foundPaths: [URL] = []
        
        // This is a synchronous recursive scan. Depending on scale we may want to dispatch to background threads.
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [] // Removed skipsHiddenFiles so it scans inside ~/.local, ~/.config, etc.
        ) else { return [] }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }
            } catch {
                continue
            }
            
            let isArchive = fileURL.pathComponents.contains { $0.lowercased() == "archive" }
            let fileName = fileURL.lastPathComponent
            
            var matches = false
            
            switch pattern {
            case "*.json":
                matches = fileName.hasSuffix(".json")
            case "*.jsonl":
                matches = fileName.hasSuffix(".jsonl")
            case "*.csv":
                matches = fileName.hasSuffix(".csv")
            case "usage*.csv":
                if !isArchive {
                    if fileName == "usage.csv" {
                        matches = true
                    } else if fileName.hasPrefix("usage.") && fileName.hasSuffix(".csv") {
                        if !fileName.hasPrefix("usage.backup") {
                            matches = true
                        }
                    }
                }
            case "session-*.json":
                matches = fileName.hasPrefix("session-") && fileName.hasSuffix(".json")
            case "T-*.json":
                matches = fileName.hasPrefix("T-") && fileName.hasSuffix(".json")
            case "*.settings.json":
                matches = fileName.hasSuffix(".settings.json")
            case "sessions.json":
                matches = fileName == "sessions.json"
            case "wire.jsonl":
                matches = fileName == "wire.jsonl"
            case "state.vscdb":
                matches = fileName == "state.vscdb"
            default:
                matches = false
            }
            
            if matches {
                foundPaths.append(fileURL)
            }
        }
        
        return foundPaths
    }

    public static func scanAllClients(homeDir: String, clients: [String]) -> ScanResult {
        let scanner = Scanner()
        var result = ScanResult()
        
        let enabled = clients.isEmpty ? ClientId.allCases.map { $0.rawValue } : clients
        
        if enabled.contains("opencode") {
            let xdgData = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] ?? "\(homeDir)/.local/share"
            let dbPath = URL(fileURLWithPath: "\(xdgData)/opencode/opencode.db")
            if FileManager.default.fileExists(atPath: dbPath.path) {
                result.opencodeDB = dbPath
            }
            let opencodePath = URL(fileURLWithPath: "\(xdgData)/opencode/storage/message")
            result.files[.opencode] = scanner.scanDirectory(root: opencodePath, pattern: "*.json")
        }
        
        if enabled.contains("claude") {
            let claudeCode = URL(fileURLWithPath: "\(homeDir)/.claude/projects")
            result.files[.claude] = scanner.scanDirectory(root: claudeCode, pattern: "*.jsonl")
        }
        
        if enabled.contains("codex") {
            let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] ?? "\(homeDir)/.codex"
            var codexFiles: [URL] = []
            codexFiles.append(contentsOf: scanner.scanDirectory(root: URL(fileURLWithPath: "\(codexHome)/sessions"), pattern: "*.jsonl"))
            codexFiles.append(contentsOf: scanner.scanDirectory(root: URL(fileURLWithPath: "\(codexHome)/archived_sessions"), pattern: "*.jsonl"))
            for root in scanner.headlessRoots(homeDir: homeDir) {
                codexFiles.append(contentsOf: scanner.scanDirectory(root: root.appendingPathComponent("codex"), pattern: "*.jsonl"))
            }
            result.files[.codex] = codexFiles
        }
        
        if enabled.contains("cursor") {
            let path = URL(fileURLWithPath: "\(homeDir)/Library/Application Support/Cursor/User/workspaceStorage")
            result.files[.cursor] = scanner.scanDirectory(root: path, pattern: "state.vscdb")
        }
        
        if enabled.contains("gemini") {
            var geminiFiles: [URL] = []
            let geminiDesktop = URL(fileURLWithPath: "\(homeDir)/Library/Application Support/Google/Gemini/Sessions")
            geminiFiles.append(contentsOf: scanner.scanDirectory(root: geminiDesktop, pattern: "*.json"))
            
            let geminiCli = URL(fileURLWithPath: "\(homeDir)/.gemini/tmp")
            geminiFiles.append(contentsOf: scanner.scanDirectory(root: geminiCli, pattern: "session-*.json"))
            
            result.files[.gemini] = geminiFiles
        }
        
        if enabled.contains("amp") {
            let path = URL(fileURLWithPath: "\(homeDir)/Library/Application Support/Amp/chat/history")
            result.files[.amp] = scanner.scanDirectory(root: path, pattern: "*.json")
        }
        
        if enabled.contains("droid") {
            let path = URL(fileURLWithPath: "\(homeDir)/Library/Application Support/Droid/sessions")
            result.files[.droid] = scanner.scanDirectory(root: path, pattern: "session-*.json")
        }
        
        if enabled.contains("openclaw") {
            var clawFiles: [URL] = []
            let paths = [
                "\(homeDir)/.openclaw/agents",
                "\(homeDir)/.clawdbot/agents",
                "\(homeDir)/.moltbot/agents",
                "\(homeDir)/.moldbot/agents"
            ]
            for p in paths {
                clawFiles.append(contentsOf: scanner.scanDirectory(root: URL(fileURLWithPath: p), pattern: "*.jsonl"))
            }
            result.files[.openclaw] = clawFiles
        }
        
        if enabled.contains("pi") {
            let path = URL(fileURLWithPath: "\(homeDir)/Library/Application Support/Pi/storage/chat")
            result.files[.pi] = scanner.scanDirectory(root: path, pattern: "usage*.csv")
        }
        
        if enabled.contains("kimi") {
            let path = URL(fileURLWithPath: "\(homeDir)/Library/Application Support/Kimi/chats")
            result.files[.kimi] = scanner.scanDirectory(root: path, pattern: "wire.jsonl")
        }
        
        return result
    }
}
