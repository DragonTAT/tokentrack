import { useEffect, useState, useCallback } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { getTodaySummary, getGraphData, refreshData } from "../api";
import type { TodaySummary, DailyContribution } from "../types";
import { formatCost, formatTokens, clientColor } from "../utils";
import MiniGraph from "../components/MiniGraph";

export default function TrayPopover() {
  const [summary, setSummary] = useState<TodaySummary | null>(null);
  const [recent, setRecent] = useState<DailyContribution[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    try {
      const [s, graph] = await Promise.all([getTodaySummary(), getGraphData()]);
      setSummary(s);
      // Last 30 days for the mini graph
      setRecent(graph.contributions.slice(-30));
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      await refreshData();
      await load();
    } finally {
      setRefreshing(false);
    }
  };

  const openDashboard = async () => {
    const win = await getCurrentWindow();
    await win.hide();
    // The main window is opened via Tauri events
    const { WebviewWindow } = await import("@tauri-apps/api/webviewWindow");
    const main = await WebviewWindow.getByLabel("main");
    if (main) {
      await main.show();
      await main.setFocus();
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-[#0d1117] text-[#8b949e]">
        <span className="text-sm">Loading…</span>
      </div>
    );
  }

  return (
    <div
      className="flex flex-col h-screen bg-[#0d1117] text-[#e6edf3] overflow-hidden"
      style={{ width: 380 }}
    >
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-[#30363d]">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold">TokenTrack</span>
          <span className="text-xs text-[#8b949e]">Today</span>
        </div>
        <div className="flex gap-2">
          <button
            onClick={handleRefresh}
            disabled={refreshing}
            className="text-xs px-2 py-1 rounded text-[#8b949e] hover:text-[#e6edf3] hover:bg-[#30363d] transition-colors disabled:opacity-50"
          >
            {refreshing ? "…" : "↻"}
          </button>
          <button
            onClick={openDashboard}
            className="text-xs px-2 py-1 rounded text-[#8b949e] hover:text-[#e6edf3] hover:bg-[#30363d] transition-colors"
          >
            ⤢
          </button>
        </div>
      </div>

      {/* Today stats */}
      <div className="px-4 pt-4 pb-3">
        <div className="flex gap-4 mb-4">
          <div>
            <div className="text-2xl font-bold text-[#e6edf3]">
              {formatTokens(summary?.total_tokens ?? 0)}
            </div>
            <div className="text-xs text-[#8b949e]">tokens today</div>
          </div>
          <div>
            <div className="text-2xl font-bold text-[#e6edf3]">
              {formatCost(summary?.total_cost ?? 0)}
            </div>
            <div className="text-xs text-[#8b949e]">cost today</div>
          </div>
        </div>

        {/* Per-client breakdown */}
        {summary && summary.clients.length > 0 && (
          <div className="space-y-1">
            {summary.clients.map((c) => (
              <div key={c.client} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span
                    className="inline-block w-2 h-2 rounded-full"
                    style={{ background: clientColor(c.client) }}
                  />
                  <span className="text-xs text-[#8b949e] capitalize">{c.client}</span>
                </div>
                <div className="flex gap-3">
                  <span className="text-xs text-[#e6edf3]">{formatTokens(c.tokens)}</span>
                  <span className="text-xs text-[#8b949e]">{formatCost(c.cost)}</span>
                </div>
              </div>
            ))}
          </div>
        )}

        {summary?.clients.length === 0 && (
          <div className="text-xs text-[#8b949e]">No activity today</div>
        )}
      </div>

      {/* Divider */}
      <div className="border-t border-[#30363d] mx-4" />

      {/* Mini 30-day graph */}
      <div className="px-4 py-3">
        <div className="text-xs text-[#8b949e] mb-2">Last 30 days</div>
        <MiniGraph contributions={recent} />
      </div>

      {/* Footer */}
      <div className="mt-auto border-t border-[#30363d] px-4 py-2 flex justify-between items-center">
        <button
          onClick={openDashboard}
          className="text-xs text-[#6c8ef0] hover:underline"
        >
          Open Dashboard →
        </button>
      </div>
    </div>
  );
}
