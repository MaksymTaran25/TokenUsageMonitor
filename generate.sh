#!/bin/bash
# Generates the Xcode project from project.yml using xcodegen.
# Run this once after cloning, then open TokenUsageMonitor.xcodeproj in Xcode.

set -e

if ! command -v xcodegen &>/dev/null; then
    echo "xcodegen not found - installing via Homebrew..."
    brew install xcodegen
fi

xcodegen generate
echo "Done. Opening Xcode..."
open TokenUsageMonitor.xcodeproj
