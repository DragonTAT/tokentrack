import { useEffect, useState, useCallback } from "react";
import { getGraphData, getModelReport, getMonthlyReport, refreshData } from "../api";
import type { GraphResult, ModelReport, MonthlyReport } from "../types";
import { formatCost, formatTokens } from "../utils";
import ContribGraph from "../components/ContribGraph";
import ModelTable from "../components/ModelTable";
import MonthlyChart from "../components/MonthlyChart";

type Tab = "overview" | "models" | "monthly";

export default function Dashboard() {
  const [tab, setTab] = useState<Tab>("overview");
  const [graph, setGraph] = useState<GraphResult | null>(null);
  const [modelReport, setModelReport] = useState<ModelReport | null>(null);
  const [monthlyReport, setMonthlyReport] = useState<MonthlyReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    try {
      const [g, m, mo] = await Promise.all([
        getGraphData(),
        getModelReport(),
        getMonthlyReport(),
      ]);
      setGraph(g);
      setModelReport(m);
      setMonthlyReport(mo);
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

  return (
    <div className="flex flex-col h-screen bg-[#0d1117] text-[#e6edf3]">
      {/* Top bar */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-[#30363d]">
        <h1 className="text-base font-semibold">TokenTrack</h1>
        <button
          onClick={handleRefresh}
          disabled={refreshing}
          className="text-sm px-3 py-1 rounded bg-[#21262d] hover:bg-[#30363d] text-[#e6edf3] transition-colors disabled:opacity-50 border border-[#30363d]"
        >
          {refreshing ? "Refreshing…" : "↻ Refresh"}
        </button>
      </div>

      {/* Summary cards */}
      {graph && (
        <div className="grid grid-cols-4 gap-4 px-6 py-4">
          <StatCard label="Total Tokens" value={formatTokens(graph.summary.total_tokens)} />
          <StatCard label="Total Cost" value={formatCost(graph.summary.total_cost)} />
          <StatCard label="Active Days" value={`${graph.summary.active_days}`} />
          <StatCard
            label="Avg Cost / Day"
            value={formatCost(graph.summary.average_per_day)}
          />
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 px-6 border-b border-[#30363d]">
        {(["overview", "models", "monthly"] as Tab[]).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-3 py-2 text-sm capitalize transition-colors border-b-2 ${
              tab === t
                ? "border-[#6c8ef0] text-[#e6edf3]"
                : "border-transparent text-[#8b949e] hover:text-[#e6edf3]"
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="flex-1 overflow-auto px-6 py-4">
        {loading && (
          <div className="flex items-center justify-center h-full text-[#8b949e]">
            Loading…
          </div>
        )}

        {!loading && tab === "overview" && graph && (
          <div className="space-y-6">
            <section>
              <h2 className="text-sm font-medium text-[#8b949e] mb-3">Contribution Graph</h2>
              <ContribGraph contributions={graph.contributions} />
            </section>
            <section>
              <h2 className="text-sm font-medium text-[#8b949e] mb-3">Active Clients</h2>
              <div className="flex flex-wrap gap-2">
                {graph.summary.clients.map((c) => (
                  <span
                    key={c}
                    className="text-xs px-2 py-1 rounded-full bg-[#161b22] border border-[#30363d] text-[#e6edf3] capitalize"
                  >
                    {c}
                  </span>
                ))}
              </div>
            </section>
          </div>
        )}

        {!loading && tab === "models" && modelReport && (
          <ModelTable report={modelReport} />
        )}

        {!loading && tab === "monthly" && monthlyReport && (
          <MonthlyChart report={monthlyReport} />
        )}
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-[#161b22] rounded-lg border border-[#30363d] px-4 py-3">
      <div className="text-xs text-[#8b949e] mb-1">{label}</div>
      <div className="text-lg font-semibold text-[#e6edf3]">{value}</div>
    </div>
  );
}
