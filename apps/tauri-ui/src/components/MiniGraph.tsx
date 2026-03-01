import type { DailyContribution } from "../types";
import { intensityColor, formatCost, formatTokens } from "../utils";

interface Props {
  contributions: DailyContribution[];
}

export default function MiniGraph({ contributions }: Props) {
  if (contributions.length === 0) {
    return <div className="text-xs text-[#8b949e]">No data</div>;
  }

  const CELL = 10;
  const GAP = 2;
  const width = contributions.length * (CELL + GAP);
  const height = CELL;

  return (
    <svg width={width} height={height} style={{ display: "block" }}>
      {contributions.map((day, i) => (
        <g key={day.date}>
          <rect
            x={i * (CELL + GAP)}
            y={0}
            width={CELL}
            height={CELL}
            rx={2}
            fill={intensityColor(day.intensity)}
          />
          <title>{`${day.date}: ${formatTokens(day.totals.tokens)} tokens, ${formatCost(day.totals.cost)}`}</title>
        </g>
      ))}
    </svg>
  );
}
