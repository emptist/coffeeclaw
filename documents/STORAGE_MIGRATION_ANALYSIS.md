# Storage Migration Analysis

## Critical Issue: Two Storage Locations

### Old Storage (Legacy)
**Location:** `/Users/jk/gits/hub/tools_ai/coffeeclaw/.secrete/`

**Files:**
- `settings.json` - User settings with API keys, tokens, providers
- `bots.json` - Bot configurations
- `sessions.json` - Chat sessions
- `license.json` - License info
- `agent-sessions.json` - Agent sessions
- `backup.*.json` - Backup files

**Format:** Separate JSON files, one per data type

### New Storage (electron-store)
**Location:** `/Users/jk/gits/hub/tools_ai/coffeeclaw/src/.secrete/`

**Files:**
- `coffeeclaw-data.json` - Single file containing all data

**Format:** Single JSON file with all data types as keys

## The Problem

The `StorageManager` class creates the new file at:
```coffee
@store = new Store
  name: 'coffeeclaw-data'
  cwd: path.join(path.dirname(__dirname), '.secrete')
```

When `storage.coffee` is in `src/core/`, `path.dirname(__dirname)` resolves to `src/`, so the file is created at `src/.secrete/coffeeclaw-data.json`.

But the **old data** is at `.secrete/` (project root), not `src/.secrete/`!

## Current State

### Old Data (`.secrete/settings.json`):
```json
{
  "__class": "Settings",
  "version": 1,
  "token": "ca965d471f82d8d7abf301dae7ec28ec76e470093b4309f3",
  "apiKey": "9eb838b8445547c48045594c8f9d9d5b.rbFfDHucXFogUOi2",
  "activeProvider": "zhipu",
  "providers": { ... },
  "feishu": { ... }
}
```

### New Data (`src/.secrete/coffeeclaw-data.json`):
```json
{
  "settings": null,
  "bots": null,
  "sessions": null,
  "license": null,
  "agentSessions": null,
  "identity": { ... },
  "agentModels": null,
  "backups": [ ... ]
}
```

**The new storage has `null` for all data types!** This means users will lose their settings, bots, and sessions!

## Migration Path

The `TypedStorage` class has `fromLegacy` methods that can migrate old format data:

```coffee
# In typed-storage.coffee
getSettings: ->
  data = @storage.get('settings')
  if data?.__class == 'Settings'
    @_cache.settings = Settings.fromJSON(data)
  else if data
    @_cache.settings = Settings.fromLegacy(data)  # Migration
  else
    @_cache.settings = new Settings()
```

But this only works if the old data is **in the same file**. The migration doesn't handle **different file locations**!

## Solutions

### Option 1: Fix Storage Location (Recommended)
Change the `cwd` in `StorageManager` to point to the project root:

```coffee
# In storage.coffee
@store = new Store
  name: 'coffeeclaw-data'
  cwd: path.join(path.dirname(__dirname), '..', '.secrete')  # Go up one level
```

This would put the new file at `.secrete/coffeeclaw-data.json` alongside the old files.

### Option 2: Migration Script
Create a one-time migration that:
1. Reads old files from `.secrete/`
2. Merges into new `coffeeclaw-data.json`
3. Renames old files to `.bak`

### Option 3: Keep Both Storage Systems
- Keep using old JSON files for now
- Slowly migrate to electron-store
- Both systems read/write in parallel

## Current main.coffee Storage Functions

The main.coffee still has functions that read from old locations:

```coffee
settingsFile = path.join secreteDir, 'settings.json'
sessionsFile = path.join secreteDir, 'sessions.json'
botsFile = path.join secreteDir, 'bots.json'
licenseFile = path.join secreteDir, 'license.json'
agentSessionsFile = path.join secreteDir, 'agent-sessions.json'
```

These are used by:
- `loadSettings()` - calls `storage.getSettings()` (TypedStorage)
- `saveSettings()` - calls `storage.saveSettings()` (TypedStorage)
- `loadBots()` - calls `storage.getBots()` (TypedStorage)
- etc.

## What's Actually Happening

1. `TypedStorage.getSettings()` calls `@storage.get('settings')`
2. `StorageManager.get('settings')` reads from `src/.secrete/coffeeclaw-data.json`
3. That file has `settings: null`
4. So `TypedStorage` creates a **new empty Settings object**
5. User's actual settings in `.secrete/settings.json` are **ignored**!

## Impact

- **Users will lose all settings** when running the new code
- **API keys will be lost**
- **Bot configurations will be lost**
- **Chat sessions will be lost**
- **License info will be lost**

## Recommendation

**DO NOT remove the old functions from main.coffee until migration is fixed!**

The old functions in main.coffee that read from `.secrete/*.json` are currently the **only way** to access user data. The new TypedStorage system is broken because it's reading from the wrong location.

## Fix Priority

1. **HIGH**: Fix `StorageManager` to use correct path
2. **HIGH**: Add migration logic to read old files if new file is empty
3. **MEDIUM**: Test migration with real user data
4. **LOW**: Remove old functions from main.coffee (only after migration works)
