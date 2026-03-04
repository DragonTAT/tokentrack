# TokenTrack (macOS)

A lightweight, native macOS menu bar app for tracking AI token usage and costs across all your favorite AI clients.

Powered by a fully native Swift engine — no external dependencies, no Rust, no CLI binaries.

---

## Features

- **Menu bar native**: Lives in your macOS menu bar (`MenuBarExtra`). Always accessible, zero overhead.
- **Quick summary**: Click the icon to see Today / Week / Month token and spend at a glance.
- **Full dashboard** with 4 tabs:
  - `Overview` — time-series chart and recent trends
  - `Models` — per-model breakdown of tokens, cost, and message count
  - `Daily` — per-day usage detail
  - `Stats` — aggregate statistics
- **Token breakdown**: Input, Output, Cache Read, Cache Write, and Reasoning tokens tracked separately.
- **Smart pricing**: LiteLLM live sync → OpenRouter supplement → Built-in fallback (`builtin.json`). Builtin data never overrides fresher remote prices.

---

## Supported Clients

| Client | Format |
|--------|--------|
| Claude (Desktop) | `.jsonl` |
| Gemini | Session JSON / JSONL |
| Cursor | `usage.csv` |
| Codex | `.jsonl` |
| OpenCode | JSON files / SQLite `.db` |
| OpenClaw | `sessions.json` + `.jsonl` |
| Amp | `.jsonl` |
| Droid | `.settings.json` + `.jsonl` |
| Pi | `usage*.csv` (JSONL content) |
| Kimi | `wire.jsonl` |

---

## Requirements

- macOS 14 Sonoma or later
- Xcode 15+ / Swift 5.9+

---

## Build & Run

```bash
cd apps/TokscaleMac
swift build
.build/debug/TokscaleMac
```

Or use the helper script:

```bash
cd apps/TokscaleMac
./build.sh
```

Run in headless mode to print a quick model report:

```bash
.build/debug/TokscaleMac --light
```

---

## How Pricing Works

1. On launch, the app fetches the latest pricing JSON from the LiteLLM mirror.
2. OpenRouter data is fetched to supplement any missing models.
3. `builtin.json` (bundled in the app) provides offline fallback for 30+ key models. It only applies when remote data is missing or invalid.
4. Cost formula:

```
cost = (input × inputPrice)
     + (output × outputPrice)
     + (cacheRead × cacheReadPrice)
     + (cacheWrite × cacheWritePrice)
     + (reasoning × outputPrice)
```

---

## Acknowledgment

This project is inspired by and based on the excellent **[tokscale](https://github.com/junhoyeo/tokscale)** project.

Big thanks to the original author and all contributors for building the token-tracking foundation that made this project possible.
