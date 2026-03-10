# Typed Storage - integrates electron-store with existing classes

fs = require 'fs'
path = require 'path'

{ StorageManager } = require './storage'
{ Settings } = require '../settings'
{ Bot } = require '../bot'
{ Session, SessionManager } = require '../session'
{ License } = require '../license'
{ Identity } = require '../identity'
{ Model } = require '../model'

class TypedStorage
  @instance = null
  
  @getInstance: ->
    @instance ?= new TypedStorage()
  
  constructor: ->
    @storage = StorageManager.getInstance()
    @_cache = {}
    @_migrated = false
  
  _getOldFilePath: (name) ->
    dir = path.join(path.dirname(__dirname), '..', '.secrete')
    path.join(dir, "#{name}.json")
  
  _readOldFile: (name) ->
    filePath = @_getOldFilePath(name)
    try
      if fs.existsSync(filePath)
        content = fs.readFileSync(filePath, 'utf8')
        JSON.parse(content)
    catch e
      console.error "Error reading old #{name} file:", e
      null
  
  _migrateFromOldFiles: ->
    return if @_migrated
    @_migrated = true
    
    hasNewData = @storage.get('settings') or 
                 @storage.get('bots') or 
                 @storage.get('sessions')
    
    if hasNewData
      console.log 'New storage has data, skipping migration'
      return
    
    console.log 'Checking for old storage files to migrate...'
    
    oldSettings = @_readOldFile('settings')
    if oldSettings
      console.log 'Migrating old settings...'
      @storage.set('settings', oldSettings)
      @storage.save('settings')
    
    oldBots = @_readOldFile('bots')
    if oldBots
      console.log 'Migrating old bots...'
      @storage.set('bots', oldBots)
      @storage.save('bots')
    
    oldSessions = @_readOldFile('sessions')
    if oldSessions
      console.log 'Migrating old sessions...'
      @storage.set('sessions', oldSessions)
      @storage.save('sessions')
    
    oldLicense = @_readOldFile('license')
    if oldLicense
      console.log 'Migrating old license...'
      @storage.set('license', oldLicense)
      @storage.save('license')
    
    oldAgentSessions = @_readOldFile('agent-sessions')
    if oldAgentSessions
      console.log 'Migrating old agent sessions...'
      @storage.set('agentSessions', oldAgentSessions)
      @storage.save('agentSessions')
    
    console.log 'Migration from old files completed'
  
  # Settings
  getSettings: ->
    return @_cache.settings if @_cache.settings
    
    @_migrateFromOldFiles()
    
    data = @storage.get('settings')
    if data?.__class == 'Settings'
      @_cache.settings = Settings.fromJSON(data)
    else if data
      @_cache.settings = Settings.fromLegacy(data)
    else
      @_cache.settings = new Settings()
    
    @_cache.settings
  
  saveSettings: (settings = null) ->
    @_cache.settings = settings ? @_cache.settings
    @storage.set('settings', @_cache.settings)
    @storage.save('settings')
    @
  
  # Bots
  getBots: ->
    return @_cache.bots if @_cache.bots
    
    data = @storage.get('bots')
    if data?.bots?[0]?.__class == 'Bot'
      @_cache.bots =
        bots: data.bots.map (b) -> Bot.fromJSON(b)
        activeBotId: data.activeBotId
    else if data
      @_cache.bots = @_migrateBots(data)
    else
      defaultBot = Bot.createDefaultBot()
      @_cache.bots =
        bots: [defaultBot]
        activeBotId: defaultBot.id
    
    @_cache.bots
  
  _migrateBots: (data) ->
    bots = []
    activeBotId = data?.activeBotId
    
    if data?.bots and Array.isArray(data.bots)
      for botData in data.bots
        try
          model = Model.create(botData.model ? 'glm-4-flash', 'zhipu')
          bot = new Bot(
            botData.id
            botData.name
            botData.description
            model
            botData.systemPrompt
            botData.skills ? ['*']
          )
          bot.enabled = botData.enabled ? true
          bot.createdAt = botData.createdAt
          bots.push(bot)
        catch e
          console.error 'Error migrating bot:', e
    
    if bots.length == 0
      defaultBot = Bot.createDefaultBot()
      bots.push(defaultBot)
      activeBotId = defaultBot.id
    
    { bots, activeBotId }
  
  saveBots: (bots = null) ->
    @_cache.bots = bots ? @_cache.bots
    @storage.set('bots', @_cache.bots)
    @storage.save('bots')
    @
  
  getBot: (botId) ->
    bots = @getBots()
    bots.bots.find (b) -> b.id == botId
  
  getActiveBot: ->
    bots = @getBots()
    active = bots.bots.find (b) -> b.id == bots.activeBotId
    active ? bots.bots[0]
  
  createBot: (config) ->
    return { error: 'Bot name is required' } unless config.name?.trim()
    
    bots = @getBots()
    id = Date.now().toString(36) + Math.random().toString(36).substr(2, 9)
    model = config.model ? Model.create('glm-4-flash', 'zhipu')
    
    bot = new Bot(
      id
      config.name.trim()
      config.description?.trim() ? ''
      model
      config.systemPrompt ? 'You are a helpful assistant.'
      config.skills ? ['*']
    )
    
    bots.bots.push(bot)
    @saveBots(bots)
    bot
  
  updateBot: (botId, updates) ->
    bots = @getBots()
    bot = bots.bots.find (b) -> b.id == botId
    return null unless bot
    
    bot.update(updates)
    @saveBots(bots)
    bot
  
  deleteBot: (botId) ->
    bots = @getBots()
    return { error: 'Cannot delete the last bot' } if bots.bots.length <= 1
    
    bots.bots = bots.bots.filter (b) -> b.id != botId
    if bots.activeBotId == botId
      bots.activeBotId = bots.bots[0]?.id
    
    @saveBots(bots)
    { success: true }
  
  setActiveBot: (botId) ->
    bots = @getBots()
    bot = bots.bots.find (b) -> b.id == botId
    return null unless bot
    
    bots.activeBotId = botId
    @saveBots(bots)
    bot
  
  # Sessions
  getSessions: ->
    return @_cache.sessions if @_cache.sessions
    
    data = @storage.get('sessions')
    if data?.__class == 'SessionManager'
      @_cache.sessions = SessionManager.fromJSON(data)
    else if data
      @_cache.sessions = @_migrateSessions(data)
    else
      @_cache.sessions = new SessionManager()
    
    @_cache.sessions
  
  _migrateSessions: (data) ->
    manager = new SessionManager()
    return manager unless data
    
    for sessionId, sessionData of data
      continue unless sessionData
      session = new Session(sessionId)
      session.title = sessionData.title ? ''
      session.messages = sessionData.messages ? []
      session.createdAt = sessionData.createdAt ? Date.now()
      session.updatedAt = sessionData.updatedAt ? Date.now()
      session.botId = sessionData.botId if sessionData.botId
      manager.addSession(session)
    
    manager
  
  saveSessions: (sessions = null) ->
    @_cache.sessions = sessions ? @_cache.sessions
    @storage.set('sessions', @_cache.sessions)
    @storage.save('sessions')
    @
  
  getSession: (sessionId) ->
    manager = @getSessions()
    session = manager.getSession(sessionId)
    unless session
      session = new Session(sessionId)
      manager.addSession(session)
      @saveSessions(manager)
    session
  
  createSession: ->
    id = Date.now().toString(36) + Math.random().toString(36).substr(2, 9)
    session = new Session(id)
    manager = @getSessions()
    manager.addSession(session)
    @saveSessions(manager)
    session
  
  addMessage: (sessionId, role, content) ->
    session = @getSession(sessionId)
    session.addMessage(role, content)
    session.title = content.substring(0, 50) if role == 'user' and not session.title
    manager = @getSessions()
    @saveSessions(manager)
    session
  
  deleteSession: (sessionId) ->
    manager = @getSessions()
    manager.removeSession(sessionId)
    @saveSessions(manager)
    @
  
  listSessions: ->
    manager = @getSessions()
    manager.getAllSessions()
  
  # License
  getLicense: ->
    return @_cache.license if @_cache.license
    
    data = @storage.get('license')
    if data?.__class == 'License'
      @_cache.license = License.fromJSON(data)
    else if data
      @_cache.license = License.fromLegacy(data)
    else
      @_cache.license = new License()
    
    @_cache.license
  
  saveLicense: (license = null) ->
    @_cache.license = license ? @_cache.license
    @storage.set('license', @_cache.license)
    @storage.save('license')
    @
  
  getLicenseStatus: ->
    license = @getLicense()
    license.getStatus()
  
  addPayment: (paymentData) ->
    license = @getLicense()
    { amount, method, email, currency } = paymentData
    
    return { error: 'Invalid amount' } unless amount and amount > 0
    
    currency = currency ? 'usd'
    
    if license.currency and license.currency != currency
      return { error: "Currency mismatch. Your account uses #{license.currency}" }
    
    license.balance = (license.balance ? 0) + amount
    license.paid = true
    
    lifetimeThreshold = if currency == 'cny' then 216 else 36
    if amount >= lifetimeThreshold
      license.plan = 'lifetime'
    
    license.paymentInfo ?= []
    license.paymentInfo.push({
      amount
      method
      email
      currency
      timestamp: new Date().toISOString()
    })
    
    @saveLicense(license)
    { success: true, balance: license.balance }
  
  # Identity
  getIdentity: ->
    return @_cache.identity if @_cache.identity
    
    data = @storage.get('identity')
    if data?.__class == 'Identity'
      @_cache.identity = Identity.fromJSON(data)
    else if data
      @_cache.identity = Identity.fromString(data)
    else
      @_cache.identity = new Identity()
      @saveIdentity()
    
    @_cache.identity
  
  saveIdentity: (identity = null) ->
    @_cache.identity = identity ? @_cache.identity
    @storage.set('identity', @_cache.identity)
    @storage.save('identity')
    @
  
  # Agent Sessions
  getAgentSessions: ->
    return @_cache.agentSessions if @_cache.agentSessions
    
    data = @storage.get('agentSessions', {})
    @_cache.agentSessions = data ? {}
    @_cache.agentSessions
  
  saveAgentSessions: (sessions = null) ->
    @_cache.agentSessions = sessions ? @_cache.agentSessions
    @storage.set('agentSessions', @_cache.agentSessions)
    @storage.save('agentSessions')
    @
  
  getAgentSession: (sessionId) ->
    sessions = @getAgentSessions()
    sessions[sessionId] or { 
      id: sessionId, 
      messages: [], 
      openclawSessionId: sessionId, 
      createdAt: Date.now() 
    }
  
  addAgentMessage: (sessionId, role, content) ->
    sessions = @getAgentSessions()
    session = sessions[sessionId] or { 
      id: sessionId, 
      messages: [], 
      openclawSessionId: sessionId 
    }
    session.messages.push
      role: role
      content: content
      timestamp: Date.now()
      source: 'openclaw-agent'
    if not session.title and role == 'user'
      session.title = content.substring(0, 50)
    unless session.createdAt
      session.createdAt = Date.now()
    session.updatedAt = Date.now()
    sessions[sessionId] = session
    @saveAgentSessions(sessions)
    session
  
  listAgentSessions: ->
    sessions = @getAgentSessions()
    Object.values(sessions).sort (a, b) -> 
      (b.updatedAt or 0) - (a.updatedAt or 0)
  
  deleteAgentSession: (sessionId) ->
    sessions = @getAgentSessions()
    delete sessions[sessionId]
    @saveAgentSessions(sessions)
    @
  
  # Agent Models Config
  getAgentModels: ->
    return @_cache.agentModels if @_cache.agentModels
    
    data = @storage.get('agentModels', null)
    @_cache.agentModels = data
    @_cache.agentModels
  
  saveAgentModels: (config = null) ->
    @_cache.agentModels = config ? @_cache.agentModels
    @storage.set('agentModels', @_cache.agentModels)
    @storage.save('agentModels')
    @
  
  createDefaultAgentModels: (apiKey) ->
    key = apiKey or ''
    
    agentModels =
      providers: {}
    
    if key
      agentModels.providers.glm =
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4'
        apiKey: key
        api: 'openai-completions'
        models: [
          id: 'GLM-4-Flash'
          name: 'GLM 4 Flash'
          reasoning: false
          input: ['text']
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
          contextWindow: 200000
          maxTokens: 8192
          api: 'openai-completions'
        ]
    
    @saveAgentModels(agentModels)
    agentModels
  
  # Backups
  getBackups: ->
    @storage.get('backups', [])
  
  saveBackups: (backups) ->
    @storage.set('backups', backups)
    @storage.save('backups')
    @
  
  createBackup: (data) ->
    backups = @getBackups()
    backup = {
      id: Date.now().toString(36)
      createdAt: new Date().toISOString()
      data: data
    }
    backups.unshift(backup)
    if backups.length > 10
      backups = backups.slice(0, 10)
    @saveBackups(backups)
    backup
  
  getBackup: (backupId) ->
    backups = @getBackups()
    backups.find (b) -> b.id == backupId
  
  deleteBackup: (backupId) ->
    backups = @getBackups()
    backups = backups.filter (b) -> b.id != backupId
    @saveBackups(backups)
    @
  
  # Export/Import
  exportAll: ->
    {
      version: '1.0'
      exportedAt: new Date().toISOString()
      settings: @getSettings().toJSON()
      bots: @getBots()
      sessions: @getSessions().toJSON()
      license: @getLicense().toJSON()
      identity: @getIdentity().toJSON()
    }
  
  importAll: (data, options = {}) ->
    try
      importSettings = options.settings ? true
      importBots = options.bots ? true
      importSessions = options.sessions ? true
      importLicense = options.license ? true
      importIdentity = options.identity ? true
      
      if data.settings and importSettings
        settings = Settings.fromJSON(data.settings)
        @saveSettings(settings)
      
      if data.bots and importBots
        @saveBots(data.bots)
      
      if data.sessions and importSessions
        sessions = SessionManager.fromJSON(data.sessions)
        @saveSessions(sessions)
      
      if data.license and importLicense
        license = License.fromJSON(data.license)
        @saveLicense(license)
      
      if data.identity and importIdentity
        identity = Identity.fromJSON(data.identity)
        @saveIdentity(identity)
      
      { success: true }
    catch e
      console.error 'Error importing data:', e
      { success: false, error: e.message }
  
  # Utility
  clear: ->
    @_cache = {}
    @storage.clear()
    @
  
  getStoragePath: ->
    @storage.getPath()

module.exports = { TypedStorage }
