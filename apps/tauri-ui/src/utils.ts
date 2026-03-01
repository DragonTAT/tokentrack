export function formatCost(cost: number): string {
  if (cost < 0.01) return `$${cost.toFixed(4)}`;
  if (cost < 1) return `$${cost.toFixed(3)}`;
  return `$${cost.toFixed(2)}`;
}

export function formatTokens(tokens: number): string {
  if (tokens >= 1_000_000) return `${(tokens / 1_000_000).toFixed(1)}M`;
  if (tokens >= 1_000) return `${(tokens / 1_000).toFixed(1)}K`;
  return `${tokens}`;
}

const CLIENT_COLORS: Record<string, string> = {
  claude: "#d97706",
  gemini: "#2563eb",
  antigravity: "#7c3aed",
  codex: "#16a34a",
  opencode: "#0891b2",
  cursor: "#db2777",
  amp: "#ea580c",
  droid: "#65a30d",
  openclaw: "#9333ea",
  pi: "#0d9488",
  kimi: "#dc2626",
};

const FALLBACK_COLORS = [
  "#6c8ef0",
  "#f472b6",
  "#34d399",
  "#fb923c",
  "#a78bfa",
  "#38bdf8",
];
let colorIdx = 0;
const dynamicColors: Record<string, string> = {};

export function clientColor(client: string): string {
  const key = client.toLowerCase();
  if (CLIENT_COLORS[key]) return CLIENT_COLORS[key];
  if (!dynamicColors[key]) {
    dynamicColors[key] = FALLBACK_COLORS[colorIdx % FALLBACK_COLORS.length];
    colorIdx++;
  }
  return dynamicColors[key];
}

/** Map intensity 0-4 to a CSS color */
export function intensityColor(intensity: number): string {
  const colors = [
    "#161b22", // 0 - empty
    "#0e4429", // 1
    "#006d32", // 2
    "#26a641", // 3
    "#39d353", // 4
  ];
  return colors[Math.min(intensity, 4)];
}
