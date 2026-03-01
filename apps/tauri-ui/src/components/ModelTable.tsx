import type { ModelReport, ModelUsage } from "../types";
import { formatCost, formatTokens } from "../utils";

interface Props {
  report: ModelReport;
}

export default function ModelTable({ report }: Props) {
  const totalTokens =
    report.total_input +
    report.total_output +
    report.total_cache_read +
    report.total_cache_write;

  return (
    <div className="space-y-4">
      {/* Summary row */}
      <div className="flex gap-6 text-sm">
        <div>
          <span className="text-[#8b949e]">Total: </span>
          <span className="font-medium">{formatTokens(totalTokens)} tokens</span>
        </div>
        <div>
          <span className="text-[#8b949e]">Cost: </span>
          <span className="font-medium">{formatCost(report.total_cost)}</span>
        </div>
        <div>
          <span className="text-[#8b949e]">Messages: </span>
          <span className="font-medium">{report.total_messages.toLocaleString()}</span>
        </div>
      </div>

      {/* Table */}
      <div className="overflow-auto">
        <table className="w-full text-xs">
          <thead>
            <tr className="text-[#8b949e] border-b border-[#30363d]">
              <th className="text-left pb-2 font-medium">Client</th>
              <th className="text-left pb-2 font-medium">Model</th>
              <th className="text-right pb-2 font-medium">Input</th>
              <th className="text-right pb-2 font-medium">Output</th>
              <th className="text-right pb-2 font-medium">Cache R/W</th>
              <th className="text-right pb-2 font-medium">Messages</th>
              <th className="text-right pb-2 font-medium">Cost</th>
            </tr>
          </thead>
          <tbody>
            {report.entries.map((entry, i) => (
              <ModelRow key={i} entry={entry} totalCost={report.total_cost} />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function ModelRow({
  entry,
  totalCost,
}: {
  entry: ModelUsage;
  totalCost: number;
}) {
  const pct = totalCost > 0 ? (entry.cost / totalCost) * 100 : 0;

  return (
    <tr className="border-b border-[#21262d] hover:bg-[#161b22]">
      <td className="py-2 pr-3 capitalize text-[#8b949e]">{entry.client}</td>
      <td className="py-2 pr-3 font-mono text-[#e6edf3]">{entry.model}</td>
      <td className="py-2 pr-3 text-right">{formatTokens(entry.input)}</td>
      <td className="py-2 pr-3 text-right">{formatTokens(entry.output)}</td>
      <td className="py-2 pr-3 text-right text-[#8b949e]">
        {formatTokens(entry.cache_read)}/{formatTokens(entry.cache_write)}
      </td>
      <td className="py-2 pr-3 text-right">{entry.message_count.toLocaleString()}</td>
      <td className="py-2 text-right">
        <div className="flex items-center justify-end gap-2">
          <div
            className="h-1 bg-[#6c8ef0] rounded-full"
            style={{ width: `${Math.max(pct, 2)}px` }}
          />
          <span>{formatCost(entry.cost)}</span>
        </div>
      </td>
    </tr>
  );
}
