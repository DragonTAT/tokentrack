#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESOURCES_DIR="$SCRIPT_DIR/TokscaleMac/Resources"

echo "═══ TokenTrack macOS App Builder ═══"
echo ""

# Step 1: Build the Rust CLI in release mode
echo "▸ Building tokscale CLI (release)..."
cd "$PROJECT_ROOT"
cargo build --release -p tokscale-cli 2>&1 | tail -3

CLI_BINARY="$PROJECT_ROOT/target/release/tokscale"
if [ ! -f "$CLI_BINARY" ]; then
    echo "✗ Error: tokscale binary not found at $CLI_BINARY"
    exit 1
fi
echo "  ✓ CLI binary ready: $(du -h "$CLI_BINARY" | cut -f1)"

# Step 2: Copy binary into Swift app resources
echo "▸ Embedding CLI binary into app resources..."
mkdir -p "$RESOURCES_DIR"
cp "$CLI_BINARY" "$RESOURCES_DIR/tokscale"
chmod +x "$RESOURCES_DIR/tokscale"
echo "  ✓ Copied to $RESOURCES_DIR/tokscale"

# Step 3: Build the Swift app
echo "▸ Building Swift app..."
cd "$SCRIPT_DIR"
swift build 2>&1 | tail -3
echo "  ✓ Swift app built"

echo ""
echo "═══ Build complete! ═══"
echo "Run: cd $SCRIPT_DIR && .build/debug/TokscaleMac"
