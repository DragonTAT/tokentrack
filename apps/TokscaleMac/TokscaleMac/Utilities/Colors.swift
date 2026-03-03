import SwiftUI

enum AppColors {
    // MARK: - Base Theme Colors (GitHub dark)
    static let background = Color(red: 13/255, green: 17/255, blue: 23/255)
    static let foreground = Color(red: 201/255, green: 209/255, blue: 217/255)
    static let border = Color(red: 48/255, green: 54/255, blue: 61/255)
    static let muted = Color(red: 139/255, green: 148/255, blue: 158/255)
    static let selection = Color(red: 48/255, green: 54/255, blue: 61/255)
    static let stripedRow = Color(red: 20/255, green: 24/255, blue: 30/255)

    // MARK: - Token Type Colors
    static let inputTokens = Color(red: 100/255, green: 200/255, blue: 100/255)
    static let outputTokens = Color(red: 200/255, green: 100/255, blue: 100/255)
    static let cacheReadTokens = Color(red: 100/255, green: 150/255, blue: 200/255)
    static let cacheWriteTokens = Color(red: 200/255, green: 150/255, blue: 100/255)
    static let costColor = Color.green

    // MARK: - Client Colors
    static func clientColor(_ client: String) -> Color {
        switch client.lowercased() {
        case "opencode": return Color(red: 34/255, green: 197/255, blue: 94/255)
        case "claude": return Color(red: 218/255, green: 119/255, blue: 86/255)
        case "codex": return Color(red: 59/255, green: 130/255, blue: 246/255)
        case "cursor": return Color(red: 168/255, green: 85/255, blue: 247/255)
        case "gemini": return Color(red: 6/255, green: 182/255, blue: 212/255)
        case "amp": return Color(red: 236/255, green: 72/255, blue: 153/255)
        case "droid": return Color(red: 16/255, green: 185/255, blue: 129/255)
        case "openclaw": return Color(red: 239/255, green: 68/255, blue: 68/255)
        case "pi": return Color(red: 13/255, green: 148/255, blue: 136/255)
        case "kimi": return Color(red: 220/255, green: 38/255, blue: 38/255)
        default: return Color(red: 136/255, green: 136/255, blue: 136/255)
        }
    }

    // MARK: - Model Colors (by provider)
    static func modelColor(_ model: String) -> Color {
        let provider = providerFromModel(model)
        switch provider {
        case "anthropic": return Color(red: 218/255, green: 119/255, blue: 86/255)
        case "openai": return Color(red: 16/255, green: 185/255, blue: 129/255)
        case "google": return Color(red: 59/255, green: 130/255, blue: 246/255)
        case "cursor": return Color(red: 139/255, green: 92/255, blue: 246/255)
        case "deepseek": return Color(red: 6/255, green: 182/255, blue: 212/255)
        case "xai": return Color(red: 234/255, green: 179/255, blue: 8/255)
        case "meta": return Color(red: 99/255, green: 102/255, blue: 241/255)
        default: return Color.white
        }
    }

    // MARK: - Provider Detection
    static func providerFromModel(_ model: String) -> String {
        let m = model.lowercased()
        if m.contains("claude") || m.contains("sonnet") || m.contains("opus") || m.contains("haiku") {
            return "anthropic"
        } else if m.contains("gpt") || m.hasPrefix("o1") || m.hasPrefix("o3") || m.contains("codex")
                    || m.contains("text-embedding") || m.contains("dall-e") || m.contains("whisper") || m.contains("tts") {
            return "openai"
        } else if m.contains("gemini") {
            return "google"
        } else if m.contains("deepseek") {
            return "deepseek"
        } else if m.contains("grok") {
            return "xai"
        } else if m.contains("llama") {
            return "meta"
        } else if m == "auto" || m.contains("cursor") {
            return "cursor"
        }
        return "unknown"
    }

    // MARK: - Client Display Names
    static func clientDisplayName(_ client: String) -> String {
        switch client.lowercased() {
        case "claude": return "Claude Code"
        case "gemini": return "Gemini CLI"
        case "codex": return "Codex CLI"
        case "opencode": return "OpenCode"
        case "cursor": return "Cursor"
        case "amp": return "Amp"
        case "droid": return "Droid"
        case "openclaw": return "🦞 OpenClaw"
        case "pi": return "Pi"
        case "kimi": return "Kimi"
        default: return client
        }
    }

    // MARK: - Provider Display Names
    static func providerDisplayName(_ provider: String) -> String {
        switch provider.lowercased() {
        case "anthropic": return "Anthropic"
        case "openai": return "OpenAI"
        case "google": return "Google"
        case "cursor": return "Cursor"
        case "deepseek": return "DeepSeek"
        case "xai": return "xAI"
        case "meta": return "Meta"
        case "mistral": return "Mistral"
        case "cohere": return "Cohere"
        case "opencode": return "OpenCode"
        case let s where s.contains("copilot") || s.hasPrefix("github-cop"):
            return "GitHub Copilot"
        default:
            return provider.prefix(1).uppercased() + provider.dropFirst()
        }
    }
}
