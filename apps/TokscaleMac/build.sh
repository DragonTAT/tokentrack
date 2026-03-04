#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "═══ TokenTrack macOS App Builder (Swift Native) ═══"
echo ""

# The project has been migrated to a native Swift engine.
# No need for Rust building or CLI embedding.

# Step 1: Clean build directory if requested
if [[ "${1:-}" == "--clean" ]]; then
    echo "▸ Cleaning build directory..."
    cd "$SCRIPT_DIR"
    rm -rf .build
    echo "  ✓ Cleaned"
fi

# Step 2: Build the Swift app
echo "▸ Building Swift app (SwiftPM)..."
cd "$SCRIPT_DIR"
swift build 2>&1 | tail -5
echo "  ✓ Swift app built"

echo ""
echo "═══ Build complete! ═══"
echo "Run: cd $SCRIPT_DIR && .build/debug/TokscaleMac"
echo "Note: The engine is now natively integrated into the Swift app."
