# Main.coffee Refactoring Plan

## Goal
Update main.coffee to use the new class hierarchy for data management.

## Current State Analysis

### Data Files Managed in main.coffee
1. `settings.json` - Application settings
2. `bots.json` - Bot configurations
3. `sessions.json` - Chat sessions
4. `license.json` - User license
5. `identity` - Machine identity (plain text)
6. `~/.openclaw/openclaw.json` - OpenClaw configuration
7. `agentModels.json` - Agent model configurations
8. `agentSessions.json` - Agent chat sessions
9. Backups in `~/.coffeeclaw/backups/`

### Current Issues
- Direct JSON read/write scattered throughout code
- Manual ID format conversion (provider/model vs model only)
- No validation of data structure
- Difficult to track where data modifications happen

## Refactoring Steps

### Phase 1: Import and Initialize Classes

**Changes:**
```coffee
# At top of file
{ Model, ZhipuModel, DeepSeekModel, OpenAIModel, OpenRouterModel } = require './model'
{ Bot } = require './bot'
{ Session, SessionManager } = require './session'
{ Settings } = require './settings'
{ FeishuConfig } = require './feishu-config'
{ OpenClawConfig } = require './openclaw-config'
{ License } = require './license'
{ Identity } = require './identity'
{ BackupManager } = require './backup-manager'
{ AgentModel, AgentModelManager } = require './agent-model'

# Initialize managers
backupManager = new BackupManager()
openClawConfig = new OpenClawConfig()
```

### Phase 2: Replace Settings Management

**Current:**
```coffee
loadSettings = ->
  if fs.existsSync(settingsFile)
    settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'))
  else
    settings = defaultSettings
```

**New:**
```coffee
loadSettings = ->
  if fs.existsSync(settingsFile)
    data = JSON.parse(fs.readFileSync(settingsFile, 'utf8'))
    # Check if already using new format
    if data.__class == 'Settings'
      settings = Settings.fromJSON(data)
    else
      # Migrate from legacy
      settings = Settings.fromLegacy(data)
      saveSettings()  # Save in new format
  else
    settings = new Settings()
    saveSettings()

saveSettings = ->
  fs.writeFileSync(settingsFile, JSON.stringify(settings.toJSON(), null, 2))
```

### Phase 3: Replace Bot Management

**Current:**
```coffee
bots = if fs.existsSync(botsFile) then JSON.parse(fs.readFileSync(botsFile, 'utf8')) else []
```

**New:**
```coffee
loadBots = ->
  if fs.existsSync(botsFile)
    data = JSON.parse(fs.readFileSync(botsFile, 'utf8'))
    if Array.isArray(data)
      # Check if first item has __class
      if data.length > 0 and data[0].__class == 'Bot'
        bots = data.map (b) -> Bot.fromJSON(b)
      else
        # Legacy format - need migration
        bots = migrateLegacyBots(data)
    else
      bots = []
  else
    bots = [Bot.createDefaultBot()]
    saveBots()

saveBots = ->
  fs.writeFileSync(botsFile, JSON.stringify(bots.map((b) -> b.toJSON()), null, 2))
```

### Phase 4: Replace Session Management

**Current:**
```coffee
sessions = if fs.existsSync(sessionsFile) then JSON.parse(...) else { sessions: [] }
```

**New:**
```coffee
sessionManager = new SessionManager()

loadSessions = ->
  if fs.existsSync(sessionsFile)
    data = JSON.parse(fs.readFileSync(sessionsFile, 'utf8'))
    if data.__class == 'SessionManager'
      sessionManager = SessionManager.fromJSON(data)
    else
      # Legacy format
      sessionManager = migrateLegacySessions(data)
```

### Phase 5: Replace License Management

**Current:**
```coffee
license = if fs.existsSync(licenseFile) then JSON.parse(...) else {}
```

**New:**
```coffee
loadLicense = ->
  if fs.existsSync(licenseFile)
    data = JSON.parse(fs.readFileSync(licenseFile, 'utf8'))
    if data.__class == 'License'
      license = License.fromJSON(data)
    else
      license = License.fromLegacy(data)
  else
    license = new License()
```

### Phase 6: Replace Identity Management

**Current:**
```coffee
identity = if fs.existsSync(identityFile) then fs.readFileSync(identityFile, 'utf8') else generateIdentity()
```

**New:**
```coffee
loadIdentity = ->
  if fs.existsSync(identityFile)
    content = fs.readFileSync(identityFile, 'utf8')
    try
      data = JSON.parse(content)
      if data.__class == 'Identity'
        identity = Identity.fromJSON(data)
      else
        # Legacy: plain string
        identity = Identity.fromString(content)
    catch
      identity = Identity.fromString(content)
  else
    identity = new Identity()
    saveIdentity()

saveIdentity = ->
  fs.writeFileSync(identityFile, JSON.stringify(identity.toJSON()))
```

### Phase 7: Replace OpenClaw Sync

**Current:**
```coffee
syncProvidersToOpenClaw = (providers, activeProvider, token) ->
  # Manual JSON manipulation
  config = JSON.parse(fs.readFileSync(configFile, 'utf8'))
  config.models.providers[openClawName] = {...}
```

**New:**
```coffee
syncProvidersToOpenClaw = ->
  openClawConfig.syncFromSettings(settings)
  # Or use individual methods:
  # openClawConfig.setProvider('zhipu', apiKey, baseUrl)
  # openClawConfig.setPrimaryModel('zhipu', modelId)
  # openClawConfig.setToken(token)
  # openClawConfig.save()
```

### Phase 8: Replace Backup Management

**Current:**
```coffee
backupData = ->
  backup =
    settings: settings
    sessions: sessions
    bots: bots
    license: license
  fs.writeFileSync(backupFile, JSON.stringify(backup))
```

**New:**
```coffee
createBackup = ->
  backupManager.createBackup(
    settings: settings.toJSON()
    sessions: sessionManager.toJSON()
    bots: bots.map((b) -> b.toJSON())
    license: license.toJSON()
  )

restoreBackup = (filename) ->
  backupManager.restoreBackup(filename, (data) ->
    # Restore each component
    settings = Settings.fromJSON(data.settings)
    sessionManager = SessionManager.fromJSON(data.sessions)
    bots = data.bots.map((b) -> Bot.fromJSON(b))
    license = License.fromJSON(data.license)
    # Save all
    saveAll()
  )
```

### Phase 9: Update IPC Handlers

**Current:**
```coffee
ipcMain.handle 'get-settings', -> settings
ipcMain.handle 'save-settings', (event, newSettings) ->
  settings = newSettings
  fs.writeFileSync(settingsFile, JSON.stringify(settings))
```

**New:**
```coffee
ipcMain.handle 'get-settings', -> settings.toJSON()
ipcMain.handle 'save-settings', (event, newSettingsData) ->
  # Update settings object
  settings = Settings.fromJSON(newSettingsData)
  saveSettings()
  # Sync to OpenClaw
  openClawConfig.syncFromSettings(settings)
```

### Phase 10: Update API Calls

**Current:**
```coffee
sendToAPI = (provider, model, messages) ->
  modelId = if provider == 'zhipu' then model else "#{provider}/#{model}"
  # API call...
```

**New:**
```coffee
sendToAPI = (model, messages) ->
  # model is now a Model instance
  modelId = model.apiId()  # Correct format for the provider
  provider = model.provider
  # API call...
```

## Migration Strategy

### 1. Gradual Migration
- Keep both old and new code paths initially
- Use feature flag or version check
- Migrate data on first load, then use new format

### 2. Data Validation
- Add validation in `fromLegacy()` methods
- Log warnings for invalid data
- Provide defaults for missing fields

### 3. Rollback Plan
- Keep backup of old data format
- Allow reverting to old code if needed
- Test thoroughly before removing old code

## Testing Checklist

- [ ] Settings load/save correctly
- [ ] Bots load/save correctly
- [ ] Sessions load/save correctly
- [ ] License load/save correctly
- [ ] Identity load/save correctly
- [ ] OpenClaw sync works correctly
- [ ] Backup/restore works correctly
- [ ] Legacy data migration works
- [ ] All IPC handlers work
- [ ] API calls use correct model IDs
- [ ] No data loss during migration

## Files to Modify

1. `src/main.coffee` - Main refactoring
2. `src/preload.coffee` - May need updates for IPC
3. `src/renderer.coffee` - May need updates for data handling

## Estimated Effort

- Phase 1-2: 2 hours (Settings)
- Phase 3: 1 hour (Bots)
- Phase 4: 1 hour (Sessions)
- Phase 5: 30 min (License)
- Phase 6: 30 min (Identity)
- Phase 7: 1 hour (OpenClaw)
- Phase 8: 1 hour (Backup)
- Phase 9: 2 hours (IPC)
- Phase 10: 2 hours (API calls)
- Testing: 3 hours

**Total: ~14 hours**

## Next Steps

1. Review this plan
2. Start with Phase 1-2 (Settings) as it's the foundation
3. Test each phase before moving to next
4. Commit after each phase
