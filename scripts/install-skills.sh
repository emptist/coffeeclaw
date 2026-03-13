#!/bin/bash
# Install CoffeeClaw skills to OpenClaw extensions directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OPENCLAW_EXT_DIR="$HOME/.openclaw/extensions/coffeeclaw/skills"

echo "Installing CoffeeClaw skills to OpenClaw..."
echo "Source: $PROJECT_DIR/skills"
echo "Target: $OPENCLAW_EXT_DIR"

# Create extension directory
mkdir -p "$OPENCLAW_EXT_DIR"

# Copy skills
cp -r "$PROJECT_DIR/skills/content-creator" "$OPENCLAW_EXT_DIR/"
cp -r "$PROJECT_DIR/skills/economic-tracker" "$OPENCLAW_EXT_DIR/"
cp -r "$PROJECT_DIR/skills/memory-enhancer" "$OPENCLAW_EXT_DIR/"

echo "Skills installed successfully!"
echo ""
echo "Installed skills:"
ls -la "$OPENCLAW_EXT_DIR/"
echo ""
echo "Note: You may need to restart OpenClaw to load the new skills."
