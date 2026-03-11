# How to Fix OpenClaw Config Warnings

## Quick Fix

Run this command in your terminal:

```bash
./scripts/fix_openclaw_config.sh
```

## What It Does

1. **Creates backup** of your current OpenClaw config
2. **Removes duplicate** feishu plugin entry
3. **Adds plugin whitelist** for security
4. **Updates config** automatically

## Expected Output

```
🔧 Fixing OpenClaw config warnings...
📦 Creating backup: ~/.openclaw/openclaw.json.backup.20260311_XXXXXX
✅ Removed duplicate feishu plugin entry
✅ Added plugin whitelist: ['feishu']
✅ Config updated successfully!

✨ Done! Config warnings should be fixed.
📝 Backup saved to: ~/.openclaw/openclaw.json.backup.20260311_XXXXXX

To verify, run:
  openclaw agent --local --agent main -m 'test'
```

## After Running

The duplicate plugin warnings will be gone:

**Before:**
```
Config warnings:
- plugins.entries.feishu: plugin feishu: duplicate plugin id detected
```

**After:**
```
(no warnings)
```

## Manual Verification

Check the config file:
```bash
cat ~/.openclaw/openclaw.json | grep -A 5 '"plugins"'
```

Should show:
```json
"plugins": {
  "allow": ["feishu"],
  "entries": {}
}
```

## Troubleshooting

**If script doesn't run:**
```bash
chmod +x ./scripts/fix_openclaw_config.sh
./scripts/fix_openclaw_config.sh
```

**If something goes wrong:**
```bash
# Restore from backup
cp ~/.openclaw/openclaw.json.backup.* ~/.openclaw/openclaw.json
```

## What Changed

**Before:**
```json
"plugins": {
  "entries": {
    "feishu": { "enabled": true }  // ← Duplicate!
  }
}
```

**After:**
```json
"plugins": {
  "allow": ["feishu"],  // ← Whitelist for security
  "entries": {}         // ← Empty (plugin auto-discovered)
}
```

## Why This Works

- Plugin in `~/.openclaw/extensions/feishu/` is **automatically discovered**
- Explicit entry in config caused **duplication**
- Whitelist provides **security control** over which plugins can load
