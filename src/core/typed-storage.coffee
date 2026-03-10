# Typed Storage - integrates electron-store with existing classes

{ StorageManager } = require './storage'
{ Settings } = require '../settings'
{ Bot } = require '../bot'
{ Session, SessionManager } = require '../session'
{ License } = require '../license'
{ Model } = require '../model'

class TypedStorage
  @instance = null
  
  @getInstance: ->
    @instance ?= new TypedStorage()
  
  constructor: ->
    @storage = StorageManager.getInstance()
    @_cache = {}
  
  # Settings
  getSettings: ->
    return @_cache.settings if @_cache.settings
    
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
  
  # Utility
  clear: ->
    @_cache = {}
    @storage.clear()
    @
  
  getStoragePath: ->
    @storage.getPath()

module.exports = { TypedStorage }
