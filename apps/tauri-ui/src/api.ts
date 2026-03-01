import { invoke } from "@tauri-apps/api/core";
import type {
  TodaySummary,
  GraphResult,
  ModelReport,
  MonthlyReport,
  SupportedClient,
} from "./types";

export async function getTodaySummary(): Promise<TodaySummary> {
  return invoke("get_today_summary");
}

export async function getGraphData(params?: {
  since?: string;
  until?: string;
  clients?: string[];
}): Promise<GraphResult> {
  return invoke("get_graph_data", {
    since: params?.since ?? null,
    until: params?.until ?? null,
    clients: params?.clients ?? null,
  });
}

export async function getModelReport(params?: {
  since?: string;
  until?: string;
  clients?: string[];
  groupBy?: string;
}): Promise<ModelReport> {
  return invoke("get_model_report", {
    since: params?.since ?? null,
    until: params?.until ?? null,
    clients: params?.clients ?? null,
    groupBy: params?.groupBy ?? null,
  });
}

export async function getMonthlyReport(params?: {
  since?: string;
  until?: string;
  clients?: string[];
}): Promise<MonthlyReport> {
  return invoke("get_monthly_report", {
    since: params?.since ?? null,
    until: params?.until ?? null,
    clients: params?.clients ?? null,
  });
}

export async function refreshData(): Promise<void> {
  return invoke("refresh_data");
}

export async function getSupportedClients(): Promise<SupportedClient[]> {
  return invoke("get_supported_clients");
}
