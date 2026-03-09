# CoffeeClaw Developer Guide

## Overview

CoffeeClaw is an Electron-based desktop application that provides a chat interface for AI models, with integration to OpenClaw for agent capabilities.

## Architecture

### Tech Stack
- **Frontend**: Vanilla JavaScript + HTML/CSS (in `index.html`)
- **Backend**: Electron + CoffeeScript (in `src/`)
- **Build**: CoffeeScript → JavaScript compilation
- **AI Integration**: OpenClaw framework

### File Structure

```
coffeeclaw/
├── index.html           # Main UI (frontend)
├── src/
│   ├── main.coffee      # Electron main process (CoffeeScript)
│   ├── main.js          # Compiled JavaScript (generated)
│   ├── preload.coffee   # Preload script for IPC bridge
│   └── preload.js       # Compiled (generated)
├── .secrete/
│   └── settings.json    # CoffeeClaw's settings (API keys, etc.)
├── documents/           # Developer documentation
└── AGENT_COLLAB_PLAN.md # Agent collaboration plan
```

## Startup Flow

```
app.whenReady()
    │
    ├── 1. backupSettings()          # Backup settings to .secrete/backup.timestamp.json
    │
    └── 2. createWindow()             # Create Electron browser window
           │
           ├── Load index.html         # UI loads
           │
           └── Frontend calls initApp()
                  │
                  └── checkStatus()
                        │
                        ├── checkOpenClawPromise()  # Is gateway running?
                        ├── isConfigured()          # Has token + apiKey?
                        ├── ensureOpenClawConfig()  # Sync providers if needed
                        └── If not running but configured → startOpenClaw()
```

### Key Functions at Startup

| Step | Function | What it does |
|------|----------|--------------|
| 1 | `backupSettings()` | Backs up settings/sessions/bots/license to `backup.YYYY-MM-DD.json` |
| 2 | `createWindow()` | Creates 1200x800 browser window, loads `index.html` |
| 3 | Frontend `initApp()` | Calls `window.api.checkStatus()` |
| 4 | `check-status` handler | Checks if OpenClaw is running & configured |
| 5 | `ensureOpenClawConfig()` | Syncs providers if CoffeeClaw settings are newer |
| 6 | Auto-start | If configured but not running → starts OpenClaw |

### Provider Sync Logic (ensureOpenClawConfig)

The startup now includes automatic provider sync:

```
ensureOpenClawConfig()
    │
    ├── Load settings from .secrete/settings.json
    ├── Check if providers exist
    ├── Check if ~/.openclaw/openclaw.json exists
    ├── Compare timestamps:
    │   └── settingsFile.mtime > openclaw.json.mtime ?
    │
    └── If newer → syncProvidersToOpenClaw()
              │
              ├── Check if any API key actually changed
              ├── Backup openclaw.json (keep last 5)
              └── Write updated providers
```

## Configuration Files

### CoffeeClaw Settings
- **Location**: `.secrete/settings.json`
- **Contents**: API keys, providers, active provider, user email, Feishu config

### OpenClaw Config
- **Location**: `~/.openclaw/openclaw.json`
- **Purpose**: Used by OpenClaw agent for API calls

### Important: Provider Sync

When a user saves provider settings in CoffeeClaw UI:
1. Saved to `.secrete/settings.json` (CoffeeClaw's own config)
2. Synced to `~/.openclaw/openclaw.json` (for OpenClaw agent to use)

This ensures both the chat UI and OpenClaw agent use the same API keys.

## Development Commands

| Command | Description |
|---------|-------------|
| `npm run compile` | Compile CoffeeScript → JavaScript |
| `coffee -c -w src/` | Watch mode - auto-compile on changes |
| `npm start` | Run the app |
| `electron -r coffee-script/register .` | Run directly with CoffeeScript |
| `npm run build` | Build for distribution |

## Code Walkthrough

### Main Process (main.coffee)

**Key IPC Handlers:**

| Handler | Purpose |
|---------|---------|
| `send-message` | Send chat message to AI |
| `check-status` | Check OpenClaw gateway status |
| `save-settings` | Save settings (also syncs to OpenClaw) |
| `get-models` | Get available AI models |
| `call-openclaw-agent` | Invoke OpenClaw agent |

### Provider Models (MODELS)

Defined at line ~810 in `main.coffee`:

```coffeescript
MODELS =
  zhipu:
    name: 'Zhipu GLM'
    models: [...]
    baseUrl: 'open.bigmodel.cn'
  openrouter:
    name: 'OpenRouter'
    models: [...]
    baseUrl: 'openrouter.ai'
  openai: ...
  deepseek: ...
```

### Frontend (index.html)

- Dynamic provider rendering (line ~1660): Loops through MODELS and renders input for each
- `saveProviderKey()`: Saves to `settings.providers[providerId]`
- Uses `window.api.saveSettings()` (NOT `saveApiKey`)

## Known Issues / Historical Notes

### Dead Code: save-api-key Handler

The `save-api-key` IPC handler (now commented out) was dead code:
- **Never called**: UI uses `save-settings` instead
- **Was hardcoded**: Only handled Zhipu, not other providers
- **Fixed**: Added `syncProvidersToOpenClaw()` in `save-settings` handler

### Provider Sync Fix (v1.1.0)

**Problem**: When user configured OpenRouter in CoffeeClaw UI, OpenClaw agent still used Zhipu because:
1. CoffeeClaw saved to `.secrete/settings.json`
2. OpenClaw read from `~/.openclaw/openclaw.json`
3. They didn't sync automatically

**Solution**: Two-way sync mechanism:

1. **On save**: `save-settings` handler calls `syncProvidersToOpenClaw()` to immediately sync
2. **On startup**: `ensureOpenClawConfig()` compares timestamps and syncs if CoffeeClaw settings are newer

**Key functions** (in `main.coffee`):
- `ensureOpenClawConfig()` - Called at startup, compares timestamps
- `syncProvidersToOpenClaw(providers, activeProvider)` - Performs actual sync with change detection
- `backupOpenClawConfig()` - Creates backup before modifying (keeps last 5)
- `PROVIDER_NAME_MAP` - Maps CoffeeClaw names to OpenClaw names (zhipu→glm)

**Backup**: Before modifying `openclaw.json`, creates timestamped backup:
```
~/.openclaw/openclaw.json.backup.2026-03-09T14-32-37-267Z
```

**Note on Default Provider**: OpenClaw's config uses `agents.defaults.model.primary` (NOT `defaults.model.primary` which is invalid). The sync code writes to the correct path:
```
config.agents.defaults.model.primary = "openrouter/auto"
```

## Contributing

1. Make changes in `.coffee` files
2. Run `npm run compile` to generate `.js`
3. Test with `npm start` or `electron -r coffee-script/register .`
