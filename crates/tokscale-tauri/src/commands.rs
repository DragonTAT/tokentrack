use tauri::State;
use tokscale_core::{GraphResult, ModelReport, MonthlyReport, ReportOptions, GroupBy};

use crate::state::{SharedCache, TodaySummary, compute_today_summary, refresh_cache};

fn make_options(
    since: Option<String>,
    until: Option<String>,
    clients: Option<Vec<String>>,
    group_by: Option<String>,
) -> ReportOptions {
    let group_by = match group_by.as_deref() {
        Some("model") => GroupBy::Model,
        Some("client_provider_model") => GroupBy::ClientProviderModel,
        _ => GroupBy::ClientModel,
    };
    ReportOptions {
        home_dir: None,
        clients,
        since,
        until,
        year: None,
        group_by,
    }
}

#[tauri::command]
pub async fn get_today_summary(cache: State<'_, SharedCache>) -> Result<TodaySummary, String> {
    let c = cache.read().await;
    match &c.graph {
        Some(graph) => Ok(compute_today_summary(graph)),
        None => {
            drop(c);
            refresh_cache(&cache).await?;
            let c = cache.read().await;
            Ok(c.graph.as_ref().map(compute_today_summary).unwrap_or(TodaySummary {
                total_tokens: 0,
                total_cost: 0.0,
                clients: vec![],
            }))
        }
    }
}

#[tauri::command]
pub async fn get_graph_data(
    since: Option<String>,
    until: Option<String>,
    clients: Option<Vec<String>>,
    cache: State<'_, SharedCache>,
) -> Result<GraphResult, String> {
    // If no filters, use cached data
    if since.is_none() && until.is_none() && clients.is_none() {
        let c = cache.read().await;
        if let Some(graph) = &c.graph {
            return Ok(graph.clone());
        }
    }
    let options = make_options(since, until, clients, None);
    tokscale_core::generate_graph(options).await
}

#[tauri::command]
pub async fn get_model_report(
    since: Option<String>,
    until: Option<String>,
    clients: Option<Vec<String>>,
    group_by: Option<String>,
    cache: State<'_, SharedCache>,
) -> Result<ModelReport, String> {
    if since.is_none() && until.is_none() && clients.is_none() && group_by.is_none() {
        let c = cache.read().await;
        if let Some(report) = &c.model_report {
            return Ok(report.clone());
        }
    }
    let options = make_options(since, until, clients, group_by);
    tokscale_core::get_model_report(options).await
}

#[tauri::command]
pub async fn get_monthly_report(
    since: Option<String>,
    until: Option<String>,
    clients: Option<Vec<String>>,
) -> Result<MonthlyReport, String> {
    let options = make_options(since, until, clients, None);
    tokscale_core::get_monthly_report(options).await
}

#[tauri::command]
pub async fn refresh_data(cache: State<'_, SharedCache>) -> Result<(), String> {
    refresh_cache(&cache).await
}

#[tauri::command]
pub fn get_supported_clients() -> Vec<serde_json::Value> {
    tokscale_core::ClientId::iter()
        .map(|c| {
            serde_json::json!({
                "id": c.as_str(),
                "label": client_label(c.as_str()),
            })
        })
        .collect()
}

fn client_label(id: &str) -> &str {
    match id {
        "claude" => "Claude Code",
        "gemini" => "Gemini CLI",
        "antigravity" => "Antigravity",
        "codex" => "Codex CLI",
        "opencode" => "OpenCode",
        "cursor" => "Cursor",
        "amp" => "Amp",
        "droid" => "Droid",
        "openclaw" => "OpenClaw",
        "pi" => "Pi",
        "kimi" => "Kimi",
        _ => id,
    }
}
