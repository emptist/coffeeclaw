# OOP Integration Plan for main.coffee

## Current State (Updated)

**main.coffee**: ~1371 lines (reduced from ~1400)

**Completed:**
- ✅ Phase 1: Import OOP classes
- ✅ Phase 2: Initialize managers
- ✅ Phase 3: Pass SKILLS to APIClient
- ✅ Phase 4: IPC handlers use openClawManager
- ✅ Phase 5: Removed ensureOpenClawConfig, sendToOpenClaw

**Remaining:**
- Remove unused functions (checkOpenClaw, checkOpenClawPromise, startOpenClaw, etc.)
- Update configExists calls
- Remove callAPI, callAPIWithMessages, callOpenClawAgent

## Functions Still in main.coffee (to remove)

| Function | Status | Notes |
|----------|--------|-------|
| `checkOpenClaw` | Used internally by startOpenClaw | Remove both together |
| `checkOpenClawPromise` | Not used externally | Remove |
| `startOpenClaw` | Not used externally | Remove |
| `configExists` | Used in 3 places | Replace with openClawManager.configExists() |
| `isConfigured` | Not used externally | Remove |
| `createDefaultConfig` | Not used externally | Remove |
| `callOpenClawAgent` | Used by callAPI | Remove with callAPI |
| `callAPI` | Not used externally | Remove |
| `callAPIWithMessages` | Used by callAPI | Remove with callAPI |

## Functions to Keep

| Function | Reason |
|----------|--------|
| `checkOpenClawInstalled` | Utility, used in IPC handlers |
| `checkNodeInstalled` | Utility, used in IPC handlers |
| `checkNpmInstalled` | Utility, used in IPC handlers |
| `checkWSLInstalled` | Utility, used in IPC handlers |
| `getPlatform` | Utility, used in IPC handlers |
| `installOpenClaw` | Utility, used in run-setup |
| `createIdentity` | Uses storage, keep in main |
| `loadIdentity` | Uses storage, keep in main |
| `saveIdentity` | Uses storage, keep in main |
| `createAgentConfig` | Uses storage, keep in main |
| `configureFeishu` | Complex, keep in main |
| `backupOpenClawConfig` | Used by syncProvidersToOpenClaw |
| `getOpenClawConfig` | Used by app.whenReady and syncProvidersToOpenClaw |
| `syncProvidersToOpenClaw` | Used by ensureOpenClawConfig (removed) but still defined |

## Integration Strategy

### Phase 1: Import and Initialize Classes

**Before:**
```coffee
# Import typed storage
{ TypedStorage } = require './core/typed-storage'
storage = TypedStorage.getInstance()
```

**After:**
```coffee
# Import typed storage
{ TypedStorage } = require './core/typed-storage'
storage = TypedStorage.getInstance()

# Import new OOP classes
{ IPCHandlers } = require './ipc-handlers'
{ OpenClawManager } = require './openclaw-manager'
{ APIClient } = require './api-client'
```

### Phase 2: Initialize Managers

Add after imports:
```coffee
# Initialize OpenClaw manager
openClawManager = OpenClawManager.getInstance
  openclawDir: openclawDir
  configFile: configFile
  workspaceDir: workspaceDir
  identityFile: identityFile
  agentDir: agentDir
  agentMdFile: agentMdFile
  agentModelsFile: agentModelsFile
  storage: storage
  models: MODELS

# Initialize API client
apiClient = APIClient.getInstance
  models: MODELS
  storage: storage
  skills: SKILL_FUNCTIONS
```

### Phase 3: Replace IPC Handlers

**Before (lines 879-1394):**
```coffee
ipcMain.handle 'send-message', (event, sessionId, message) ->
  ...
ipcMain.handle 'check-status', ->
  ...
# ... 40 more handlers
```

**After:**
```coffee
# Register IPC handlers
ipcHandlers = new IPCHandlers
  storage: storage
  settings: Settings
  bots: Bot
  sessions: Session
  license: License
  identity: Identity
  agentSessions: AgentSession
  openClaw: openClawManager
  feishu: feishuManager
  backup: backupManager
  secreteDir: secreteDir
  settingsFile: settingsFile
  licensePrices: LICENSE_PRICES
  models: MODELS

ipcHandlers.registerAll()
```

### Phase 4: Remove Duplicated Functions

**Functions to REMOVE from main.coffee:**

| Function | Line | Replacement |
|----------|------|-------------|
| `checkOpenClaw` | 356 | `openClawManager.checkRunning()` |
| `checkOpenClawPromise` | 364 | `openClawManager.checkRunning()` |
| `startOpenClaw` | 368 | `openClawManager.start()` |
| `configExists` | 389 | `openClawManager.configExists()` |
| `isConfigured` | 395 | `openClawManager.isConfigured()` |
| `createDefaultConfig` | 399 | `openClawManager.createDefaultConfig()` |
| `createIdentity` | 470 | (keep in main, uses storage) |
| `loadIdentity` | 480 | (keep in main) |
| `saveIdentity` | 485 | (keep in main) |
| `createAgentConfig` | 491 | (keep in main) |
| `checkOpenClawInstalled` | 518 | (keep in main, utility) |
| `checkNodeInstalled` | 524 | (keep in main, utility) |
| `checkNpmInstalled` | 529 | (keep in main, utility) |
| `checkWSLInstalled` | 534 | (keep in main, utility) |
| `getPlatform` | 539 | (keep in main, utility) |
| `installOpenClaw` | 542 | (keep in main, utility) |
| `callOpenClawAgent` | 582 | `openClawManager.callAgent()` |
| `callAPI` | 628 | `apiClient.call()` |
| `callAPIWithMessages` | 737 | `apiClient.callWithMessages()` |
| `sendToOpenClaw` | 816 | `openClawManager.sendMessage()` |
| `getOpenClawProviderConfig` | 1103 | `openClawManager.getProviderConfig()` |
| `backupOpenClawConfig` | 1132 | `openClawManager.backup()` |
| `getOpenClawConfig` | 1154 | `openClawManager.getConfig()` |
| `syncProvidersToOpenClaw` | 1159 | `openClawManager.syncProviders()` |
| `ensureOpenClawConfig` | 1190 | `openClawManager.ensureConfig()` |
| `configureFeishu` | 1340 | (keep in main, complex) |

### Phase 5: Update App Lifecycle

**Before:**
```coffee
app.whenReady().then ->
  backupSettings()
  # Fix OpenClaw config...
  createWindow()
```

**After:**
```coffee
app.whenReady().then ->
  storage.createBackup()
  openClawManager.ensureConfig()
  createWindow()
```

### Phase 6: Create Missing Dependencies

Need to create:
1. `FeishuManager` class (or keep functions in main)
2. `SKILL_FUNCTIONS` constant

## Expected Result

**main.coffee**: ~400 lines
- Imports (30 lines)
- Constants (50 lines)
- Storage wrappers (100 lines)
- Utility functions (50 lines)
- App lifecycle (50 lines)
- createWindow (30 lines)
- IPCHandlers setup (20 lines)
- Feishu functions (70 lines)

**Total reduction**: ~1000 lines (70% smaller)

## Execution Order

1. Add imports for new classes
2. Initialize managers after imports
3. Create FeishuManager class (optional, can keep in main)
4. Define SKILL_FUNCTIONS constant
5. Replace IPC handlers with IPCHandlers.registerAll()
6. Remove duplicated functions
7. Update app lifecycle calls
8. Test compilation
9. Test functionality

## Risk Assessment

**Low Risk:**
- IPC handlers are simple wrappers
- OpenClaw functions are self-contained
- API functions are stateless

**Medium Risk:**
- Feishu functions have complex state
- Identity functions interact with storage

**Mitigation:**
- Keep Feishu functions in main for now
- Keep Identity functions in main for now
- Test each phase before proceeding
