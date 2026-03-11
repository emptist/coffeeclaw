#!/usr/bin/env python3
import json
import os

config_file = os.path.expanduser("~/.openclaw/openclaw.json")

# Read config
with open(config_file, 'r') as f:
    config = json.load(f)

# Fix plugins section
if 'plugins' in config:
    # Remove duplicate entry
    if 'entries' in config['plugins'] and 'feishu' in config['plugins']['entries']:
        del config['plugins']['entries']['feishu']
        print("✅ Removed duplicate feishu plugin entry")

    # Ensure whitelist exists
    if 'allow' not in config['plugins']:
        config['plugins']['allow'] = ['feishu']
        print("✅ Added plugin whitelist")

    # Ensure entries is empty dict
    if 'entries' not in config['plugins']:
        config['plugins']['entries'] = {}

# Write back
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Config updated successfully!")
print("\nNew plugins section:")
print(json.dumps(config.get('plugins', {}), indent=2))
