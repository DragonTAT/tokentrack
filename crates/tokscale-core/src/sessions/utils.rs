//! Shared parsing helpers for session logs.

use serde_json::Value;
use std::path::Path;
use std::time::SystemTime;

pub(crate) fn extract_i64(value: Option<&Value>) -> Option<i64> {
    value.and_then(|val| {
        val.as_i64()
            .or_else(|| val.as_u64().map(|v| v as i64))
            .or_else(|| val.as_str().and_then(|s| s.parse::<i64>().ok()))
    })
}

pub(crate) fn extract_string(value: Option<&Value>) -> Option<String> {
    value.and_then(|val| val.as_str().map(|s| s.to_string()))
}

pub(crate) fn parse_timestamp_value(value: &Value) -> Option<i64> {
    if let Some(ts) = value.as_str() {
        return parse_timestamp_str(ts);
    }

    let numeric = value
        .as_i64()
        .or_else(|| value.as_u64().map(|v| v as i64))?;
    // Heuristic: values >= 1e12 are treated as milliseconds, smaller values as seconds.
    if numeric >= 1_000_000_000_000 {
        Some(numeric)
    } else {
        Some(numeric * 1000)
    }
}

pub(crate) fn parse_timestamp_str(value: &str) -> Option<i64> {
    if let Ok(dt) = chrono::DateTime::parse_from_rfc3339(value) {
        return Some(dt.timestamp_millis());
    }

    if let Ok(numeric) = value.parse::<i64>() {
        if numeric >= 1_000_000_000_000 {
            return Some(numeric);
        }
        return Some(numeric * 1000);
    }

    None
}

pub(crate) fn file_modified_timestamp_ms(path: &Path) -> i64 {
    std::fs::metadata(path)
        .and_then(|meta| meta.modified())
        .ok()
        .and_then(|time| time.duration_since(SystemTime::UNIX_EPOCH).ok())
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or_else(|| chrono::Utc::now().timestamp_millis())
}

/// Infer the AI provider from a model name string.
///
/// Checks well-known model name fragments in priority order.
/// Returns `fallback` when no fragment matches — callers should pass their
/// client-specific default (e.g. `"cursor"`, `"anthropic"`, `"unknown"`).
pub(crate) fn infer_provider_with_fallback(model: &str, fallback: &'static str) -> &'static str {
    let lower = model.to_lowercase();

    if lower.contains("claude")
        || lower.contains("anthropic")
        || lower.contains("opus")
        || lower.contains("sonnet")
        || lower.contains("haiku")
    {
        "anthropic"
    } else if lower.contains("gpt")
        || lower.contains("openai")
        || lower.contains("o1")
        || lower.contains("o3")
    {
        "openai"
    } else if lower.contains("gemini") || lower.contains("google") {
        "google"
    } else if lower.contains("grok") {
        "xai"
    } else if lower.contains("deepseek") {
        "deepseek"
    } else if lower.contains("llama") || lower.contains("mixtral") {
        "meta"
    } else {
        fallback
    }
}
