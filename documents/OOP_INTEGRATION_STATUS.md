# OOP Integration Status

## Overview

This document tracks the progress of refactoring main.coffee to use OOP classes.

## Completed Phases

### Phase 1: Import OOP Classes ✅
**Commit:** `3b05521`

Added imports for:
- `OpenClawManager` from `./openclaw-manager`
- `APIClient` from `./api-client`

### Phase 2: Initialize Managers ✅
**Commit:** `eff76d7`

Initialized after imports:
- `openClawManager = OpenClawManager.getInstance {...}`
- `apiClient = APIClient.getInstance {...}`

### Phase 3: Pass SKILLS to APIClient ✅
**Commit:** `3a89305`

- Changed `skills: {}` to `skills: SKILLS` in APIClient initialization
- APIClient now has access to skill functions

### Phase 4: IPC Handlers Use OpenClawManager ✅
**Commit:** `acd2b9b`

Updated IPC handlers:
- `send-message`: uses `openClawManager.sendMessage()`
- `check-status`: uses `openClawManager.checkRunning()`, `isConfigured()`, `ensureConfig()`, `start()`
- `call-openclaw-agent`: uses `openClawManager.callAgent()`
- `run-setup`: uses `openClawManager.createDefaultConfig()`, `start()`
- `save-settings`: uses `openClawManager.syncProviders()`

### Phase 5: Remove Unused Functions ✅
**Commit:** `11e6842`

Removed:
- `ensureOpenClawConfig` - replaced by `openClawManager.ensureConfig()`
- `sendToOpenClaw` - replaced by `openClawManager.sendMessage()`

Updated `openClawManager.sendMessage()` to handle session updates.

## Current State

### File Sizes
- **main.coffee**: ~1371 lines (reduced from ~1400)
- **openclaw-manager.coffee**: ~350 lines
- **api-client.coffee**: ~200 lines
- **ipc-handlers.coffee**: ~300 lines

### Functions Still in main.coffee

#### Used (Keep)
| Function | Used By | Notes |
|----------|---------|-------|
| `checkOpenClawInstalled` | check-prerequisites, run-setup | Utility |
| `checkNodeInstalled` | check-prerequisites | Utility |
| `checkNpmInstalled` | check-prerequisites | Utility |
| `checkWSLInstalled` | check-prerequisites | Utility |
| `getPlatform` | check-prerequisites | Utility |
| `installOpenClaw` | run-setup | Utility |
| `createIdentity` | createDefaultConfig | Uses storage |
| `loadIdentity` | IPC handlers | Uses storage |
| `saveIdentity` | IPC handlers | Uses storage |
| `createAgentConfig` | createDefaultConfig | Uses storage |
| `configureFeishu` | IPC handlers | Complex, keep in main |
| `backupOpenClawConfig` | syncProvidersToOpenClaw | Used internally |
| `getOpenClawConfig` | app.whenReady, syncProvidersToOpenClaw | Used in 2 places |
| `syncProvidersToOpenClaw` | save-settings IPC | Still used |
| `configExists` | backupOpenClawConfig, syncProvidersToOpenClaw, configureFeishu | Used in 3 places |

#### Unused (Can Remove)
| Function | Reason |
|----------|--------|
| `checkOpenClaw` | Only used by startOpenClaw |
| `checkOpenClawPromise` | Not called externally |
| `startOpenClaw` | Not called externally |
| `isConfigured` | Not called externally |
| `createDefaultConfig` | Not called externally |
| `callOpenClawAgent` | Only used by callAPI |
| `callAPI` | Not called externally |
| `callAPIWithMessages` | Only used by callAPI |

## Architecture

```
main.coffee
├── Imports (including OpenClawManager, APIClient)
├── Constants (MODELS, SKILLS, LICENSE_PRICES)
├── Manager Initialization
│   ├── openClawManager = OpenClawManager.getInstance()
│   └── apiClient = APIClient.getInstance()
├── Storage Wrappers (loadSettings, saveSettings, etc.)
├── Utility Functions (checkNodeInstalled, etc.)
├── OpenClaw Functions (some remaining)
├── API Functions (callAPI, etc. - unused)
├── App Lifecycle
│   └── app.whenReady() -> createWindow()
└── IPC Handlers (42 handlers)
    └── Uses openClawManager for key operations
```

## Classes

### OpenClawManager
**File:** `src/openclaw-manager.coffee`

**Methods:**
- `checkRunning()` - Check if OpenClaw gateway is running
- `start()` - Start OpenClaw gateway
- `configExists()` - Check if config file exists
- `isConfigured()` - Check if token and apiKey are set
- `createDefaultConfig(apiKey)` - Create default OpenClaw config
- `sendMessage(sessionId, message)` - Send message (handles session updates)
- `callAPI(sessionId, message, settings, bot)` - Call API
- `callAgent(sessionId, message)` - Call OpenClaw agent
- `syncProviders(providers, activeProvider, token)` - Sync providers to config
- `ensureConfig()` - Ensure config is in sync with settings
- `backup()` - Backup config file

### APIClient
**File:** `src/api-client.coffee`

**Methods:**
- `call(sessionId, message, settings, bot)` - Make API call
- `callWithMessages(sessionId, messages, settings, bot, apiKey)` - Call with message history

## Testing Checklist

### Compilation
- [ ] `npm run compile` succeeds
- [ ] No CoffeeScript syntax errors
- [ ] No missing imports

### Basic Functionality
- [ ] App starts without errors
- [ ] Settings load correctly
- [ ] Bots load correctly
- [ ] Sessions work

### OpenClaw Integration
- [ ] check-status returns correct state
- [ ] send-message works with regular bot
- [ ] send-message works with agent bot
- [ ] Settings sync to OpenClaw config

### API Calls
- [ ] Zhipu API works
- [ ] OpenRouter API works
- [ ] OpenAI API works

## Next Steps

1. **Test current code** - Verify compilation and basic functionality
2. **Remove unused functions** - Clean up checkOpenClaw, callAPI, etc.
3. **Update configExists calls** - Replace with openClawManager.configExists()
4. **Consider moving more functions** - evaluate what else can be moved to classes

## Risk Areas

1. **Tool calls** - OpenClawManager.callAPI doesn't handle tool calls yet
2. **Session management** - Verify session updates work correctly
3. **Feishu integration** - Complex, kept in main for now
4. **Identity management** - Uses storage, kept in main for now
