use std::sync::Arc;
use tokio::sync::RwLock;
use tokscale_core::{GraphResult, GroupBy, ModelReport, ReportOptions};

#[derive(Debug, Clone, serde::Serialize)]
pub struct TodaySummary {
    pub total_tokens: i64,
    pub total_cost: f64,
    pub clients: Vec<ClientSummary>,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct ClientSummary {
    pub client: String,
    pub tokens: i64,
    pub cost: f64,
}

#[derive(Default)]
pub struct AppCache {
    pub graph: Option<GraphResult>,
    pub model_report: Option<ModelReport>,
    pub last_refresh: Option<std::time::Instant>,
}

pub type SharedCache = Arc<RwLock<AppCache>>;

pub fn new_cache() -> SharedCache {
    Arc::new(RwLock::new(AppCache::default()))
}

pub async fn refresh_cache(cache: &SharedCache) -> Result<(), String> {
    let options = ReportOptions {
        home_dir: None,
        clients: None,
        since: None,
        until: None,
        year: None,
        group_by: GroupBy::ClientModel,
    };

    let (graph, report) = tokio::join!(
        tokscale_core::generate_graph(options.clone()),
        tokscale_core::get_model_report(options),
    );

    let mut c = cache.write().await;
    c.graph = graph.ok();
    c.model_report = report.ok();
    c.last_refresh = Some(std::time::Instant::now());

    Ok(())
}

pub fn compute_today_summary(graph: &GraphResult) -> TodaySummary {
    let today = chrono::Utc::now().format("%Y-%m-%d").to_string();

    let day = graph.contributions.iter().find(|d| d.date == today);

    match day {
        None => TodaySummary {
            total_tokens: 0,
            total_cost: 0.0,
            clients: vec![],
        },
        Some(day) => {
            let mut client_map: std::collections::HashMap<String, (i64, f64)> =
                std::collections::HashMap::new();

            for c in &day.clients {
                let entry = client_map.entry(c.client.clone()).or_default();
                entry.0 += c.tokens.input + c.tokens.output + c.tokens.reasoning;
                entry.1 += c.cost;
            }

            let mut clients: Vec<ClientSummary> = client_map
                .into_iter()
                .map(|(client, (tokens, cost))| ClientSummary {
                    client,
                    tokens,
                    cost,
                })
                .collect();
            clients.sort_by(|a, b| b.tokens.cmp(&a.tokens));

            TodaySummary {
                total_tokens: day.totals.tokens,
                total_cost: day.totals.cost,
                clients,
            }
        }
    }
}
