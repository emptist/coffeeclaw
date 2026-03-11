#!/bin/bash
# Fix OpenClaw Config Warnings
# This script fixes duplicate plugin warnings and adds plugin whitelist

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
BACKUP_FILE="$HOME/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)"

echo "🔧 Fixing OpenClaw config warnings..."

# Backup current config
echo "📦 Creating backup: $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Create temporary Python script to modify JSON
cat > /tmp/fix_openclaw_config.py << 'EOF'
import json
import sys

config_file = sys.argv[1]

with open(config_file, 'r') as f:
    config = json.load(f)

# Fix plugins section
if 'plugins' not in config:
    config['plugins'] = {}

# Remove duplicate entry
if 'entries' in config['plugins'] and 'feishu' in config['plugins']['entries']:
    del config['plugins']['entries']['feishu']
    print("✅ Removed duplicate feishu plugin entry")

# Add whitelist
config['plugins']['allow'] = ['feishu']
print("✅ Added plugin whitelist: ['feishu']")

# Ensure entries exists but is empty
if 'entries' not in config['plugins']:
    config['plugins']['entries'] = {}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Config updated successfully!")
EOF

# Run the Python script
python3 /tmp/fix_openclaw_config.py "$CONFIG_FILE"

# Clean up
rm /tmp/fix_openclaw_config.py

echo ""
echo "✨ Done! Config warnings should be fixed."
echo "📝 Backup saved to: $BACKUP_FILE"
echo ""
echo "To verify, run:"
echo "  openclaw agent --local --agent main -m 'test'"
