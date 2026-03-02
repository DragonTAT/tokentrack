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
    const { WebviewWindow } = await import("@tauri-apps/api/webviewWindow");
    const main = await WebviewWindow.getByLabel("main");
    if (main) {
      await main.show();
      await main.setFocus();
    }
  };

  if (loading) {
    return (
      <div
        className="flex items-center justify-center h-screen bg-[#0d1117]"
        style={{ fontFamily: "ui-monospace, 'Cascadia Code', 'Fira Code', monospace" }}
      >
        <span className="text-xs text-[#484f58]">loading…</span>
      </div>
    );
  }

  const totalTokens = summary?.total_tokens ?? 0;
  const totalCost = summary?.total_cost ?? 0;
  const clients = summary?.clients ?? [];

  return (
    <div
      className="flex flex-col h-screen bg-[#0d1117] text-[#c9d1d9] overflow-hidden select-none"
      style={{
        width: 380,
        fontFamily: "ui-monospace, 'Cascadia Code', 'Fira Code', monospace",
        fontSize: 12,
      }}
    >
      {/* ── Header ─────────────────────────────────────── */}
      <div className="flex items-center justify-between px-3 py-2 border-b border-[#21262d]">
        <div className="flex items-center gap-1.5">
          <span className="text-[#58a6ff] font-bold text-[13px]">tokscale</span>
          <span className="text-[#30363d]">/</span>
          <span className="text-[#8b949e] text-xs">today</span>
        </div>
        <div className="flex gap-1">
          <button
            onClick={handleRefresh}
            disabled={refreshing}
            title="Refresh"
            className="w-6 h-6 flex items-center justify-center rounded text-[#8b949e] hover:text-[#c9d1d9] hover:bg-[#21262d] transition-colors disabled:opacity-40 text-xs"
          >
            {refreshing ? "…" : "↻"}
          </button>
          <button
            onClick={openDashboard}
            title="Open Dashboard"
            className="w-6 h-6 flex items-center justify-center rounded text-[#8b949e] hover:text-[#c9d1d9] hover:bg-[#21262d] transition-colors text-xs"
          >
            ⤢
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-hidden flex flex-col gap-2 px-3 py-2.5">

        {/* ── Today summary ───────────────────────────── */}
        <Section label="today">
          <div className="flex items-end gap-6 px-3 py-2.5">
            <Stat
              value={formatTokens(totalTokens)}
              label="tokens"
              valueClass="text-[#e6edf3]"
            />
            <Stat
              value={formatCost(totalCost)}
              label="cost"
              valueClass="text-[#3fb950]"
            />
          </div>
        </Section>

        {/* ── Per-client breakdown ─────────────────────── */}
        {clients.length > 0 && (
          <Section label="clients">
            <div className="px-3 py-1.5 space-y-[5px]">
              {clients.map((c) => (
                <div key={c.client} className="flex items-center gap-2">
                  <span style={{ color: clientColor(c.client) }}>●</span>
                  <span className="flex-1 text-[#8b949e] capitalize">{c.client}</span>
                  <span className="text-[#c9d1d9] tabular-nums">
                    {formatTokens(c.tokens)}
                  </span>
                  <span className="text-[#3fb950] tabular-nums w-[58px] text-right">
                    {formatCost(c.cost)}
                  </span>
                </div>
              ))}
            </div>
          </Section>
        )}

        {clients.length === 0 && (
          <Section label="clients">
            <div className="px-3 py-3 text-[#484f58] text-center">
              no activity today
            </div>
          </Section>
        )}

        {/* ── 30-day mini graph ────────────────────────── */}
        <Section label="last 30 days" className="flex-1 flex flex-col min-h-0">
          <div className="px-2 py-2 flex-1 flex items-center min-h-0">
            <MiniGraph contributions={recent} />
          </div>
        </Section>

      </div>

      {/* ── Footer ─────────────────────────────────────── */}
      <div className="border-t border-[#21262d] px-3 py-1.5 flex items-center justify-between">
        <button
          onClick={openDashboard}
          className="text-[11px] text-[#388bfd] hover:text-[#58a6ff] transition-colors"
        >
          open dashboard →
        </button>
      </div>
    </div>
  );
}

/* ── Sub-components ──────────────────────────────────── */

function Section({
  label,
  children,
  className = "",
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`border border-[#30363d] rounded ${className}`}>
      <div className="px-3 py-[3px] border-b border-[#21262d] text-[#484f58] text-[10px] tracking-widest uppercase">
        {label}
      </div>
      {children}
    </div>
  );
}

function Stat({
  value,
  label,
  valueClass = "",
}: {
  value: string;
  label: string;
  valueClass?: string;
}) {
  return (
    <div>
      <div className={`text-2xl font-bold leading-none ${valueClass}`}>{value}</div>
      <div className="text-[10px] text-[#484f58] mt-1">{label}</div>
    </div>
  );
}
