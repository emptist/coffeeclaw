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

    # Ensure entries is empty dict
    config['plugins']['entries'] = {}

# Write back
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Config updated successfully!")

# Verify
with open(config_file, 'r') as f:
    verify = json.load(f)
print("\nNew plugins section:")
print(json.dumps(verify.get('plugins', {}), indent=2))
