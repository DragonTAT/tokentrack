import { useMemo } from "react";
import type { MonthlyReport, MonthlyUsage } from "../types";
import { formatCost } from "../utils";

interface Props {
  report: MonthlyReport;
}

export default function MonthlyChart({ report }: Props) {
  const entries = useMemo(() => [...report.entries].reverse(), [report.entries]);
  const maxCost = useMemo(
    () => Math.max(...report.entries.map((e) => e.cost), 0.001),
    [report.entries]
  );

  return (
    <div className="space-y-4">
      <div className="text-sm">
        <span className="text-[#8b949e]">Total: </span>
        <span className="font-medium">{formatCost(report.total_cost)}</span>
      </div>

      <div className="space-y-1">
        {entries.map((entry) => (
          <MonthRow key={entry.month} entry={entry} maxCost={maxCost} />
        ))}
      </div>
    </div>
  );
}

function MonthRow({ entry, maxCost }: { entry: MonthlyUsage; maxCost: number }) {
  const barWidth = (entry.cost / maxCost) * 100;
  const totalTokens = entry.input + entry.output + entry.cache_read + entry.cache_write;

  return (
    <div className="flex items-center gap-3 py-1">
      <div className="text-xs text-[#8b949e] w-16 shrink-0">{entry.month}</div>
      <div className="flex-1 flex items-center gap-2">
        <div className="flex-1 bg-[#21262d] rounded-full h-2 overflow-hidden">
          <div
            className="h-2 bg-[#6c8ef0] rounded-full transition-all"
            style={{ width: `${barWidth}%` }}
          />
        </div>
        <div className="text-xs text-[#e6edf3] w-16 text-right shrink-0">
          {formatCost(entry.cost)}
        </div>
        <div className="text-xs text-[#8b949e] w-20 text-right shrink-0">
          {(totalTokens / 1_000).toFixed(0)}K tok
        </div>
      </div>
    </div>
  );
}
