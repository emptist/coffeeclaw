# CoffeeClaw Architecture Guide

## Overview

CoffeeClaw is a desktop AI assistant built with Electron and CoffeeScript, integrating OpenClaw with multiple AI providers (Zhipu, DeepSeek, OpenAI, OpenRouter).

## Project Structure

```
coffeeclaw/
├── src/
│   ├── main.coffee          # Main process entry point
│   ├── preload.coffee       # Preload script (context bridge)
│   │
│   ├── core/                # Core infrastructure
│   │   ├── storage.coffee      # electron-store wrapper
│   │   └── typed-storage.coffee # Type-safe storage API
│   │
│   ├── model.coffee         # AI provider model classes
│   ├── bot.coffee           # Bot configuration
│   ├── session.coffee       # Chat session management
│   ├── settings.coffee      # App settings
│   ├── license.coffee       # License management
│   ├── feishu-config.coffee # Feishu integration
│   ├── identity.coffee      # Identity management
│   ├── openclaw-config.coffee # OpenClaw config
│   ├── backup-manager.coffee # Backup operations
│   └── agent-model.coffee   # Agent model
│
├── index.html               # Renderer UI
├── package.json            # Project config
└── dist/                   # Build output
```

## Class Hierarchy

### Model Classes

```
Model (base class)
├── ZhipuModel      # Zhipu AI (GLM-4-Flash, GLM-4-Plus)
├── DeepSeekModel   # DeepSeek API
├── OpenAIModel     # OpenAI API
└── OpenRouterModel # Multi-model gateway
```

**Purpose**: Abstract AI provider differences with consistent interface.

**Key Methods**:
- `apiId()` - Returns model ID for API calls
- `openClawId()` - Returns model ID for OpenClaw
- `toJSON()` / `@fromJSON()` - Serialization

### Storage Classes

```
StorageManager (electron-store wrapper)
└── TypedStorage (type-safe API)
```

**Purpose**: Unified storage for all application data.

**Supported Data Types**:
| Type | Methods |
|------|---------|
| Settings | `getSettings()`, `saveSettings()` |
| Bots | `getBots()`, `saveBots()`, `getBot()`, `getActiveBot()`, `createBot()`, `updateBot()`, `deleteBot()`, `setActiveBot()` |
| Sessions | `getSessions()`, `saveSessions()`, `getSession()`, `createSession()`, `addMessage()`, `deleteSession()`, `listSessions()` |
| License | `getLicense()`, `saveLicense()`, `getLicenseStatus()`, `addPayment()` |
| Identity | `getIdentity()`, `saveIdentity()` |
| AgentSessions | `getAgentSessions()`, `saveAgentSessions()`, `getAgentSession()`, `addAgentMessage()`, `listAgentSessions()`, `deleteAgentSession()` |
| AgentModels | `getAgentModels()`, `saveAgentModels()`, `createDefaultAgentModels()` |
| Backups | `getBackups()`, `saveBackups()`, `createBackup()`, `getBackup()`, `deleteBackup()` |
| Export/Import | `exportAll()`, `importAll()` |

**Usage**:
```coffeescript
storage = TypedStorage.getInstance()
settings = storage.getSettings()
storage.saveSettings(settings)
```

### Domain Classes

| Class | Purpose | Key Methods |
|-------|---------|------------|
| `Bot` | AI assistant config | `update()`, `isAgent()` |
| `Session` | Single chat | `addMessage()`, `getHistoryForAPI()` |
| `SessionManager` | Multiple sessions | `addSession()`, `getAllSessions()` |
| `Settings` | App configuration | `setProvider()`, `validate()` |
| `License` | Licensing/billing | `getStatus()`, `addBalance()` |

## Data Flow

### Startup Flow

```
main.coffee
    ↓
TypedStorage.getInstance()
    ↓
┌─────────────────────────────────────┐
│ Load from electron-store:           │
│  - Settings                         │
│  - Bots                             │
│  - Sessions                         │
│  - License                          │
└─────────────────────────────────────┘
    ↓
Create BrowserWindow
    ↓
Register IPC handlers
```

### Message Flow

```
Renderer (index.html)
    ↓ (IPC)
ipcMain.handle('send-message', ...)
    ↓
callAPI(sessionId, message, settings, bot)
    ↓
HTTPS request to AI provider
    ↓
Parse response
    ↓
Save to Session via TypedStorage
    ↓ (IPC)
Renderer receives response
```

### Storage Flow

```
App Code
    ↓
TypedStorage.method()
    ↓
StorageManager.set()/save()
    ↓
In-memory cache (_cache)
    ↓
electron-store persistence
```

## IPC API

All renderer-main communication happens via IPC:

### Settings
```javascript
getSettings()     → Returns settings object
saveSettings(s)   → Saves settings
```

### Sessions
```javascript
createSession()       → Creates new session
getSession(id)        → Gets session by ID
listSessions()        → Lists all sessions
deleteSession(id)    → Deletes session
addMessage(id, role, content) → Adds message
```

### Bots
```javascript
getBots()          → Gets all bots
getBot(id)         → Gets bot by ID
getActiveBot()     → Gets active bot
createBot(config)  → Creates bot
updateBot(id, u)   → Updates bot
deleteBot(id)      → Deletes bot
setActiveBot(id)   → Sets active bot
```

### License
```javascript
getLicense()       → Gets license status
addPayment(data)   → Adds payment
```

## Configuration Files

### User Data (`.secrete/`)
All application data is now stored in a single `coffeeclaw-data.json` file managed by electron-store:

```
.secrete/
├── coffeeclaw-data.json   # All app data (electron-store)
│   ├── settings           # App settings
│   ├── bots               # Bot configurations
│   ├── sessions           # Chat history
│   ├── license            # License info
│   ├── identity           # Machine identity
│   ├── agentSessions      # OpenClaw agent sessions
│   ├── agentModels        # Agent model configs
│   └── backups            # Backup history
│
└── (legacy files - no longer used)
    ├── settings.json
    ├── bots.json
    ├── sessions.json
    ├── license.json
    └── agent-sessions.json
```

**Note**: The legacy JSON files are no longer used. Data is automatically migrated to the new format on first run.

### OpenClaw (`.openclaw/`)
```
.openclaw/
├── openclaw.json    # OpenClaw config
├── workspace/      # Agent workspace
│   └── IDENTITY.md
└── agents/         # Agent configs
```

## Compilation

### Build Commands

```bash
npm run compile    # Compile CoffeeScript → JavaScript
npm start          # Run in development
npm run build      # Build for distribution
```

### Compile Script

```json
"compile": "coffee -c -b --transpile src/"
```

| Flag | Purpose |
|------|---------|
| `-c` | Compile to .js files |
| `-b` | Bare output (no IIFE wrapper) |
| `--transpile` | Convert ES6 imports/exports to CommonJS |

## Migration History

### Phase 1: Class Introduction
- Added Model, Bot, Session, Settings classes
- Added serialization/deserialization

### Phase 2: Storage Refactor
- Added electron-store integration
- Created TypedStorage layer
- Migrated settings, bots, sessions, license

### Phase 3: OpenClaw Integration
- Added OpenClawConfig class
- Added BackupManager class
- Improved model format handling

## Known Limitations

1. **main.coffee size** - Still ~1400 lines, could be modularized further
2. **Mixed .coffee/.js** - Both source and compiled exist (build artifact)
3. **No tests** - No test infrastructure

## Recent Improvements

1. ✅ **Unified Storage** - All data now uses TypedStorage with electron-store
2. ✅ **Removed DeepSeek** - Provider removed due to lack of free tier
3. ✅ **Provider Strategy** - Clear separation: GLM-4-Flash for chat, OpenRouter for agents
4. ✅ **Agent Capable Flag** - Models now have `agentCapable` flag for OpenClaw execution
