import { invoke } from "@tauri-apps/api/core";
import type {
  TodaySummary,
  GraphResult,
  ModelReport,
  MonthlyReport,
  SupportedClient,
} from "./types";

async function invokeCommand<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  try {
    return await invoke<T>(cmd, args);
  } catch (e) {
    // Tauri errors are strings; wrap them into proper Error objects.
    const message = typeof e === "string" ? e : String(e);
    throw new Error(`[${cmd}] ${message}`);
  }
}

export async function getTodaySummary(): Promise<TodaySummary> {
  return invokeCommand("get_today_summary");
}

export async function getGraphData(params?: {
  since?: string;
  until?: string;
  clients?: string[];
}): Promise<GraphResult> {
  return invokeCommand("get_graph_data", {
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
  return invokeCommand("get_model_report", {
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
  return invokeCommand("get_monthly_report", {
    since: params?.since ?? null,
    until: params?.until ?? null,
    clients: params?.clients ?? null,
  });
}

export async function refreshData(): Promise<void> {
  return invokeCommand("refresh_data");
}

export async function getSupportedClients(): Promise<SupportedClient[]> {
  return invokeCommand("get_supported_clients");
}
