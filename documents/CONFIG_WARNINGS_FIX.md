# Config Warnings Fix - Complete

## Problem

Duplicate plugin warning appearing repeatedly:
```
Config warnings:
- plugins.entries.feishu: plugin feishu: duplicate plugin id detected
```

## Root Cause

CoffeeClaw was re-adding the duplicate plugin entry in [src/main.coffee:1294-1295](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/src/main.coffee#L1294-L1295):

```coffee
# Before (incorrect):
config.plugins.entries ?= {}
config.plugins.entries.feishu = { enabled: true }
```

This created a duplicate because:
1. Plugin already exists in `~/.openclaw/extensions/feishu/`
2. OpenClaw auto-discovers plugins from that directory
3. Explicit entry in config caused duplication

## Solution

### 1. Modified CoffeeClaw Code

Changed [src/main.coffee:1294-1295](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/src/main.coffee#L1294-L1295):

```coffee
# After (correct):
config.plugins ?= {}
config.plugins.allow ?= ['feishu']
```

This:
- Removes duplicate entry creation
- Adds plugin to whitelist for security
- Lets OpenClaw auto-discover the plugin

### 2. Fixed Existing Config

Ran script to clean up existing duplicate:

```bash
python3 scripts/fix_plugins_v2.py
```

Result:
```json
{
  "plugins": {
    "allow": ["feishu"],
    "entries": {}
  }
}
```

## Verification

After restart, the duplicate warning should be gone:

```bash
openclaw agent --local --agent main -m 'test'
```

Expected: **NO** duplicate plugin warnings

## Related Files

- [src/main.coffee](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/src/main.coffee) - Fixed duplicate entry creation
- [scripts/fix_plugins_v2.py](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/scripts/fix_plugins_v2.py) - Cleanup script
- [documents/config_warnings.md](file:///Users/jk/gits/hub/tools_ai/coffeeclaw/documents/config_warnings.md) - Original warnings

## Why This Works

OpenClaw plugin system:
1. Auto-discovers plugins from `~/.openclaw/extensions/`
2. Uses `plugins.allow` whitelist for security
3. `plugins.entries` is for manual overrides (not needed for auto-discovered plugins)

By removing the explicit entry and using whitelist, we:
- Avoid duplication
- Maintain security control
- Let OpenClaw manage plugin discovery
