#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_BIN="$SCRIPT_DIR/aerospace-monitor-daemon"

echo "🔨 Building AeroSpace Monitor Daemon..."

# Compile the Swift program
swiftc -O "$SCRIPT_DIR/main.swift" -o "$OUTPUT_BIN"

# Make it executable
chmod +x "$OUTPUT_BIN"

echo "✅ Build complete: $OUTPUT_BIN"
echo "   Run with: $OUTPUT_BIN"
