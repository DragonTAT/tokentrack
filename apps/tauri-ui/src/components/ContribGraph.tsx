import { useState, useMemo } from "react";
import type { DailyContribution } from "../types";
import { intensityColor, formatCost, formatTokens } from "../utils";

interface Props {
  contributions: DailyContribution[];
}

const CELL = 12;
const GAP = 3;
const WEEKS = 53;
const DAYS = 7;

const DAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export default function ContribGraph({ contributions }: Props) {
  const [tooltip, setTooltip] = useState<{
    day: DailyContribution;
    x: number;
    y: number;
  } | null>(null);

  const byDate = useMemo(
    () => new Map(contributions.map((c) => [c.date, c])),
    [contributions]
  );

  const weeks = useMemo(() => {
    const today = new Date();
    const dayOfWeek = today.getDay();
    const gridStart = new Date(today);
    gridStart.setDate(gridStart.getDate() - (WEEKS * DAYS - 1 + dayOfWeek));

    const result: (DailyContribution | null)[][] = [];
    const cursor = new Date(gridStart);
    for (let w = 0; w < WEEKS; w++) {
      const week: (DailyContribution | null)[] = [];
      for (let d = 0; d < DAYS; d++) {
        week.push(byDate.get(cursor.toISOString().slice(0, 10)) ?? null);
        cursor.setDate(cursor.getDate() + 1);
      }
      result.push(week);
    }
    return result;
  }, [byDate]);

  const monthLabels = useMemo(() => {
    const labels: { label: string; col: number }[] = [];
    let lastMonth = -1;
    weeks.forEach((week, wi) => {
      const firstDay = week.find((d) => d !== null);
      if (!firstDay) return;
      const m = new Date(firstDay.date).getMonth();
      if (m !== lastMonth) {
        labels.push({
          label: new Date(firstDay.date).toLocaleString("default", { month: "short" }),
          col: wi,
        });
        lastMonth = m;
      }
    });
    return labels;
  }, [weeks]);

  const svgWidth = WEEKS * (CELL + GAP);
  const svgHeight = DAYS * (CELL + GAP) + 20; // 20 for month labels

  return (
    <div className="relative">
      <svg width={svgWidth} height={svgHeight} style={{ display: "block" }}>
        {/* Month labels */}
        {monthLabels.map(({ label, col }) => (
          <text
            key={`${label}-${col}`}
            x={col * (CELL + GAP)}
            y={10}
            fill="#8b949e"
            fontSize={9}
          >
            {label}
          </text>
        ))}

        {/* Day cells */}
        {weeks.map((week, wi) =>
          week.map((day, di) => {
            const x = wi * (CELL + GAP);
            const y = di * (CELL + GAP) + 18;
            return (
              <rect
                key={`${wi}-${di}`}
                x={x}
                y={y}
                width={CELL}
                height={CELL}
                rx={2}
                fill={day ? intensityColor(day.intensity) : "#161b22"}
                onMouseEnter={
                  day
                    ? (e) =>
                        setTooltip({
                          day,
                          x: e.clientX,
                          y: e.clientY,
                        })
                    : undefined
                }
                onMouseLeave={() => setTooltip(null)}
                style={{ cursor: day ? "pointer" : "default" }}
              />
            );
          })
        )}
      </svg>

      {/* Tooltip */}
      {tooltip && (
        <div
          className="fixed z-50 bg-[#1c2128] border border-[#30363d] rounded px-2 py-1 text-xs pointer-events-none"
          style={{ left: tooltip.x + 10, top: tooltip.y - 30 }}
        >
          <div className="font-medium">{tooltip.day.date}</div>
          <div className="text-[#8b949e]">
            {formatTokens(tooltip.day.totals.tokens)} tokens ·{" "}
            {formatCost(tooltip.day.totals.cost)}
          </div>
        </div>
      )}

      {/* Legend */}
      <div className="flex items-center gap-1 mt-2 justify-end">
        <span className="text-xs text-[#8b949e]">Less</span>
        {[0, 1, 2, 3, 4].map((i) => (
          <rect
            key={i}
            style={{
              display: "inline-block",
              width: CELL,
              height: CELL,
              background: intensityColor(i),
              borderRadius: 2,
            }}
          />
        ))}
        <span className="text-xs text-[#8b949e]">More</span>
      </div>
    </div>
  );
}
