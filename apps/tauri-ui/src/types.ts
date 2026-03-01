export interface TokenBreakdown {
  input: number;
  output: number;
  cache_read: number;
  cache_write: number;
  reasoning: number;
}

export interface ClientSummary {
  client: string;
  tokens: number;
  cost: number;
}

export interface TodaySummary {
  total_tokens: number;
  total_cost: number;
  clients: ClientSummary[];
}

export interface ClientContribution {
  client: string;
  model_id: string;
  provider_id: string;
  tokens: TokenBreakdown;
  cost: number;
  messages: number;
}

export interface DailyTotals {
  tokens: number;
  cost: number;
  messages: number;
}

export interface DailyContribution {
  date: string;
  totals: DailyTotals;
  intensity: number; // 0-4
  token_breakdown: TokenBreakdown;
  clients: ClientContribution[];
}

export interface YearSummary {
  year: string;
  total_tokens: number;
  total_cost: number;
  range_start: string;
  range_end: string;
}

export interface DataSummary {
  total_tokens: number;
  total_cost: number;
  total_days: number;
  active_days: number;
  average_per_day: number;
  max_cost_in_single_day: number;
  clients: string[];
  models: string[];
}

export interface GraphMeta {
  generated_at: string;
  version: string;
  date_range_start: string;
  date_range_end: string;
  processing_time_ms: number;
}

export interface GraphResult {
  meta: GraphMeta;
  summary: DataSummary;
  years: YearSummary[];
  contributions: DailyContribution[];
}

export interface ModelUsage {
  client: string;
  merged_clients: string | null;
  model: string;
  provider: string;
  input: number;
  output: number;
  cache_read: number;
  cache_write: number;
  reasoning: number;
  message_count: number;
  cost: number;
}

export interface ModelReport {
  entries: ModelUsage[];
  total_input: number;
  total_output: number;
  total_cache_read: number;
  total_cache_write: number;
  total_messages: number;
  total_cost: number;
  processing_time_ms: number;
}

export interface MonthlyUsage {
  month: string;
  models: string[];
  input: number;
  output: number;
  cache_read: number;
  cache_write: number;
  message_count: number;
  cost: number;
}

export interface MonthlyReport {
  entries: MonthlyUsage[];
  total_cost: number;
  processing_time_ms: number;
}

export interface SupportedClient {
  id: string;
  label: string;
}
