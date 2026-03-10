# Functions to Remove from main.coffee

## Overview

This document lists functions that can be safely removed from main.coffee because they are either:
1. Replaced by OpenClawManager methods
2. Not called externally (dead code)

## Functions to Remove

### Group 1: OpenClaw Process Management (Lines ~361-398)

These functions are replaced by OpenClawManager methods and are not called externally.

| Function | Lines | Replacement | External Calls |
|----------|-------|-------------|----------------|
| `checkOpenClaw` | 361-368 | `openClawManager._checkRunning()` (internal) | None |
| `checkOpenClawPromise` | 369-372 | `openClawManager.checkRunning()` | None |
| `startOpenClaw` | 373-398 | `openClawManager.start()` | None |

**Code to remove:**
```coffee
checkOpenClaw = (callback) ->
  req = http.get 'http://127.0.0.1:18789/health', (res) ->
    callback true
  req.on 'error', -> callback false
  req.setTimeout 2000, ->
    req.destroy()
    callback false

checkOpenClawPromise = ->
  new Promise (resolve) ->
    checkOpenClaw resolve

startOpenClaw = ->
  new Promise (resolve) ->
    console.log 'Starting OpenClaw gateway...'
    child = spawn 'openclaw', ['gateway', '--dev'],
      detached: true
      stdio: 'ignore'
    child.unref()
    
    attempts = 0
    maxAttempts = 30
    check = ->
      attempts++
      checkOpenClaw (running) ->
        if running
          resolve true
        else if attempts < maxAttempts
          setTimeout check, 1000
        else
          resolve false
    setTimeout check, 2000
```

**Lines removed:** ~38 lines

---

### Group 2: Config Helpers (Lines ~400-468)

These functions are replaced by OpenClawManager methods.

| Function | Lines | Replacement | External Calls |
|----------|-------|-------------|----------------|
| `configExists` | 394-398 | `openClawManager.configExists()` | 3 places (need update) |
| `isConfigured` | 400-403 | `openClawManager.isConfigured()` | None |
| `createDefaultConfig` | 404-468 | `openClawManager.createDefaultConfig()` | None |

**Note:** `configExists` is called in 3 places:
- Line 1133: `backupOpenClawConfig`
- Line 1160: `syncProvidersToOpenClaw`
- Line 1327: `configureFeishu`

These need to be updated to use `openClawManager.configExists()` before removing.

**Code to remove:**
```coffee
configExists = ->
  try
    fs.existsSync configFile
  catch
    false

isConfigured = ->
  settings = loadSettings()
  settings.token and settings.apiKey

createDefaultConfig = (apiKey) ->
  # ... ~65 lines ...
```

**Lines removed:** ~70 lines (after updating configExists calls)

---

### Group 3: API Functions (Lines ~604-840)

These functions are replaced by OpenClawManager methods.

| Function | Lines | Replacement | External Calls |
|----------|-------|-------------|----------------|
| `callOpenClawAgent` | 604-648 | `openClawManager.callAgent()` | Only by callAPI |
| `callAPI` | 650-757 | `openClawManager.callAPI()` | None |
| `callAPIWithMessages` | 759-840 | `openClawManager._callWithMessages()` (internal) | Only by callAPI |

**Code to remove:**
```coffee
callOpenClawAgent = (sessionId, message) ->
  # ... ~45 lines ...

callAPI = (sessionId, message, settings, bot = null) ->
  # ... ~108 lines ...

callAPIWithMessages = (sessionId, messages, settings, bot, apiKey) ->
  # ... ~82 lines ...
```

**Lines removed:** ~235 lines

---

## Summary

| Group | Functions | Lines | Prerequisite |
|-------|-----------|-------|--------------|
| 1 | checkOpenClaw, checkOpenClawPromise, startOpenClaw | ~38 | None |
| 2 | configExists, isConfigured, createDefaultConfig | ~70 | Update 3 configExists calls |
| 3 | callOpenClawAgent, callAPI, callAPIWithMessages | ~235 | None |

**Total lines to remove:** ~343 lines

---

## Prerequisites for Removal

### Before removing Group 2 (configExists):

Update these calls:

1. **Line 1133** in `backupOpenClawConfig`:
```coffee
# Before
return unless configExists()

# After
return unless openClawManager.configExists()
```

2. **Line 1160** in `syncProvidersToOpenClaw`:
```coffee
# Before
return false unless configExists()

# After
return false unless openClawManager.configExists()
```

3. **Line 1327** in `configureFeishu`:
```coffee
# Before
if configExists()

# After
if openClawManager.configExists()
```

---

## Functions to Keep

These functions are still used and should remain in main.coffee:

| Function | Reason |
|----------|--------|
| `checkOpenClawInstalled` | Used by check-prerequisites and run-setup IPC handlers |
| `checkNodeInstalled` | Used by check-prerequisites IPC handler |
| `checkNpmInstalled` | Used by check-prerequisites IPC handler |
| `checkWSLInstalled` | Used by check-prerequisites IPC handler |
| `getPlatform` | Used by check-prerequisites IPC handler |
| `installOpenClaw` | Used by run-setup IPC handler |
| `createIdentity` | Used by createDefaultConfig (in OpenClawManager) |
| `loadIdentity` | Used by IPC handlers |
| `saveIdentity` | Used by IPC handlers |
| `createAgentConfig` | Used by createDefaultConfig (in OpenClawManager) |
| `configureFeishu` | Used by IPC handlers, complex logic |
| `backupOpenClawConfig` | Used by syncProvidersToOpenClaw |
| `getOpenClawConfig` | Used by app.whenReady and syncProvidersToOpenClaw |
| `syncProvidersToOpenClaw` | Used by save-settings IPC handler |

---

## Expected Result

After removal:
- **main.coffee**: ~1028 lines (from ~1371)
- **Reduction**: ~343 lines (25%)
