import Foundation

public enum ClientId: String, CaseIterable, Codable {
    case opencode = "opencode"
    case claude = "claude"
    case codex = "codex"
    case cursor = "cursor"
    case gemini = "gemini"
    case amp = "amp"
    case droid = "droid"
    case openclaw = "openclaw"
    case pi = "pi"
    case kimi = "kimi"
    
    var supportsHeadless: Bool {
        switch self {
        case .codex: return true
        default: return false
        }
    }
    
    var parseLocal: Bool {
        switch self {
        case .cursor: return false
        default: return true
        }
    }
}
