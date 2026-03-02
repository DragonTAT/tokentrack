# TokenTrack (macOS Menu Bar App)

TokenTrack is a native macOS menu bar app for tracking AI token usage and cost.

It uses the Rust `tokscale` engine under the hood for parsing, aggregation, and pricing, then presents the data through a SwiftUI desktop experience.

## What It Does

- Runs as a menu bar app (`MenuBarExtra`) on macOS
- Shows a compact popover summary (`Today / Week / Month`)
- Opens a full dashboard window with 4 tabs:
  - `Overview`
  - `Models`
  - `Daily`
  - `Stats`
- Supports sorting by `Cost / Tokens / Date`
- Auto-refreshes data every 5 minutes (manual refresh supported)

## Tech Stack

- **Frontend/Desktop:** SwiftUI (macOS native)
- **Data engine:** Rust (`tokscale-core`, `tokscale-cli`)
- **Bridge:** local CLI invocation from Swift (`TokscaleService`)

## Repository Structure

```text
apps/
  TokscaleMac/           # macOS SwiftUI app
crates/
  tokscale-core/         # Rust parsing + aggregation + pricing core
  tokscale-cli/          # Rust CLI used by the app
```

## Prerequisites

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools / Swift toolchain (Swift 5.9+)
- Rust toolchain (stable)

## Run Locally

### Option A (recommended): one-step builder

```bash
cd /Users/chen/Desktop/claude/tokentrack
./apps/TokscaleMac/build.sh
./apps/TokscaleMac/.build/debug/TokscaleMac
```

This script will:
1. Build `tokscale-cli` in release mode
2. Copy the binary into `apps/TokscaleMac/TokscaleMac/Resources/tokscale`
3. Build the Swift app

### Option B: manual

```bash
cd /Users/chen/Desktop/claude/tokentrack
cargo build --release -p tokscale-cli

mkdir -p apps/TokscaleMac/TokscaleMac/Resources
cp target/release/tokscale apps/TokscaleMac/TokscaleMac/Resources/tokscale
chmod +x apps/TokscaleMac/TokscaleMac/Resources/tokscale

cd apps/TokscaleMac
swift build
./.build/debug/TokscaleMac
```

## Notes

- The app resolves the `tokscale` binary from multiple candidate paths; embedding it into `Resources/` is the most reliable setup.
- If data is missing, first verify the CLI runs correctly:

```bash
cd /Users/chen/Desktop/claude/tokentrack
./target/release/tokscale models --json --no-spinner
```

## Acknowledgment

This project is based on the excellent **[tokscale](https://github.com/junhoyeo/tokscale)** project.

Huge thanks to the original author and all contributors for building and open-sourcing the Rust token-tracking foundation that makes this app possible.

## License

MIT — see [LICENSE](./LICENSE).
