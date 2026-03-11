# Fix OpenClaw Config Warnings Plan

## Problem Analysis

### Issue 1: Duplicate Plugin Warning
```
plugin feishu: duplicate plugin id detected; later plugin may be overridden
(/Users/jk/.openclaw/extensions/feishu/index.ts)
```

**Root Cause:**
- Feishu plugin is being loaded from TWO sources:
  1. Explicit config entry in `openclaw.json` → `plugins.entries.feishu`
  2. Auto-discovery from `~/.openclaw/extensions/feishu/` directory

**Impact:**
- Plugin loads twice, causing unpredictable behavior
- Later instance may override earlier configuration
- Warnings appear 5 times during startup

### Issue 2: Missing Plugin Whitelist
```
plugins.allow is empty; discovered non-bundled plugins may auto-load: feishu
Set plugins.allow to explicit trusted ids.
```

**Root Cause:**
- No `plugins.allow` array in config to whitelist trusted plugins
- Any plugin in extensions directory can auto-load

**Security Risk:**
- Untrusted plugins could be loaded automatically
- No control over which plugins are allowed

## Solution Plan

### Step 1: Remove Duplicate Plugin Entry
**File:** `~/.openclaw/openclaw.json`

**Current:**
```json
"plugins": {
  "entries": {
    "feishu": {
      "enabled": true
    }
  }
}
```

**Change:** Remove `plugins.entries.feishu` section since plugin is auto-discovered from extensions directory.

**Rationale:** Plugin in `extensions/` directory is automatically discovered and loaded. Explicit entry causes duplication.

### Step 2: Add Plugin Whitelist
**File:** `~/.openclaw/openclaw.json`

**Add:**
```json
"plugins": {
  "allow": ["feishu"],
  "entries": {}
}
```

**Rationale:** 
- Explicitly whitelist trusted plugins
- Prevents unauthorized plugins from auto-loading
- Improves security posture

### Step 3: Verify Plugin Configuration
**File:** `~/.openclaw/extensions/feishu/openclaw.plugin.json`

Check that plugin metadata is correct and matches expected plugin ID.

## Implementation Steps

1. **Backup current config**
   ```bash
   cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup
   ```

2. **Update plugins section**
   - Remove `plugins.entries.feishu`
   - Add `plugins.allow: ["feishu"]`

3. **Test configuration**
   ```bash
   openclaw agent --local --agent main -m "test"
   ```

4. **Verify no warnings**
   - Check that duplicate plugin warning is gone
   - Check that whitelist warning is gone

## Expected Outcome

After fixes:
- ✅ No duplicate plugin warnings
- ✅ No security warnings about empty whitelist
- ✅ Feishu plugin loads once from extensions directory
- ✅ Only whitelisted plugins can load
- ✅ Cleaner startup logs

## Files to Modify

1. `~/.openclaw/openclaw.json` - Update plugins configuration

## Testing Checklist

- [ ] Backup created
- [ ] Config updated
- [ ] No duplicate warnings on startup
- [ ] No whitelist warnings
- [ ] Feishu tools still work (feishu_doc, feishu_chat, etc.)
- [ ] Agent commands work correctly
