# OpenClaw Manager - Handles all OpenClaw operations
# Encapsulates gateway management, agent calls, and configuration

{ spawn, exec } = require 'child_process'
fs = require 'fs'
path = require 'path'
http = require 'http'
https = require 'https'
crypto = require 'crypto'

{ Model } = require './model'

class OpenClawManager
  @instance = null
  
  @getInstance: (options) ->
    @instance ?= new OpenClawManager(options)
  
  constructor: (options = {}) ->
    @openclawDir = options.openclawDir or path.join(process.env.HOME, '.openclaw')
    @configFile = options.configFile or path.join(@openclawDir, 'openclaw.json')
    @workspaceDir = options.workspaceDir or path.join(@openclawDir, 'workspace')
    @identityFile = options.identityFile or path.join(@workspaceDir, 'IDENTITY.md')
    @agentDir = options.agentDir or path.join(@openclawDir, 'agents', 'main', 'agent')
    @agentMdFile = options.agentMdFile or path.join(@agentDir, 'agent.md')
    @agentModelsFile = options.agentModelsFile or path.join(@agentDir, 'models.json')
    @storage = options.storage
    @MODELS = options.models
  
  selectProvider: (settings, bot) ->
    isAgent = bot?.isAgent?() or bot?.model?.rawId?() == 'openclaw-agent'
    
    if isAgent
      if settings.providers?.openrouter?.apiKey
        return 'openrouter'
      else if settings.providers?.openai?.apiKey
        return 'openai'
      else
        return 'zhipu'
    else
      return 'zhipu'
  
  checkRunning: ->
    new Promise (resolve) ->
      req = http.get 'http://127.0.0.1:18789/health', (res) ->
        resolve true
      req.on 'error', -> resolve false
      req.setTimeout 2000, ->
        req.destroy()
        resolve false
  
  start: ->
    new Promise (resolve) ->
      console.log 'Starting OpenClaw gateway...'
      child = spawn 'openclaw', ['gateway', '--dev'],
        detached: true
        stdio: 'ignore'
      child.unref()
      
      attempts = 0
      maxAttempts = 30
      check = =>
        attempts++
        @checkRunning().then (running) ->
          if running
            resolve true
          else if attempts < maxAttempts
            setTimeout check, 1000
          else
            resolve false
      setTimeout check, 2000
  
  configExists: ->
    try
      fs.existsSync @configFile
    catch
      false
  
  isConfigured: ->
    settings = @storage.getSettings()
    settings.token and settings.apiKey
  
  createDefaultConfig: (apiKey) ->
    console.log 'Creating OpenClaw config...'
    
    settings = @storage.getSettings()
    token = settings.token or @generateToken()
    key = apiKey or settings.apiKey or ''
    
    fs.mkdirSync @openclawDir, { recursive: true } unless fs.existsSync @openclawDir
    fs.mkdirSync @workspaceDir, { recursive: true } unless fs.existsSync @workspaceDir
    fs.mkdirSync @agentDir, { recursive: true } unless fs.existsSync @agentDir
    
    defaultConfig =
      meta:
        lastTouchedVersion: '2026.3.2'
        lastTouchedAt: new Date().toISOString()
      env: {}
      models:
        providers: {}
      agents:
        defaults:
          model:
            primary: 'glm/glm-4-flash'
          models:
            'glm/glm-4-flash': {}
          compaction:
            mode: 'safeguard'
      commands:
        native: 'auto'
        nativeSkills: 'auto'
        restart: true
        ownerDisplay: 'raw'
      channels:
        feishu:
          enabled: false
      gateway:
        mode: 'local'
        http:
          endpoints:
            chatCompletions:
              enabled: true
        auth:
          mode: 'token'
          token: token

    if key
      defaultConfig.env.ZHIPU_API_KEY = key
      defaultConfig.models.providers.glm =
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4'
        apiKey: key
        api: 'openai-completions'
        models: [
          { id: 'GLM-4-Flash', name: 'GLM 4 Flash' }
          { id: 'GLM-4.5-air', name: 'GLM 4.5 air' }
          { id: 'GLM-4.7', name: 'GLM 4.7' }
        ]

    fs.writeFileSync @configFile, JSON.stringify(defaultConfig, null, 2)
    console.log 'Config created at:', @configFile
    
    settings.token = token
    settings.apiKey = key if key
    @storage.saveSettings(settings)
    
    token
  
  generateToken: ->
    crypto.randomBytes(24).toString 'hex'
  
  callAgent: (sessionId, message) ->
    new Promise (resolve, reject) =>
      unless /^[a-zA-Z0-9_-]+$/.test sessionId
        return reject new Error "Invalid sessionId - must match ^[a-zA-Z0-9_-]+$"

      args = [
        'agent'
        '--local'
        '--session-id', sessionId
        '--message', message
        '--json'
      ]

      child = spawn 'openclaw', args, stdio: ['ignore', 'pipe', 'pipe']

      stdout = ''
      stderr = ''

      child.stdout.on 'data', (chunk) -> stdout += chunk.toString()
      child.stderr.on 'data', (chunk) -> stderr += chunk.toString()

      child.on 'error', (err) -> reject err

      child.on 'close', (code) ->
        if code is 0
          try
            jsonMatch = stdout.match /\{[\s\S]*"payloads"[\s\S]*\}/
            if jsonMatch
              result = JSON.parse jsonMatch[0]
              payloads = result?.payloads or []
              text = ''
              for p in payloads
                if p.type == 'text' or p.text
                  text += p.text or p.content or ''
              if not text and result?.meta?.agentMeta
                text = 'Response received (check session for details)'
              resolve text or 'No response'
            else
              resolve stdout.trim() or 'Response received'
          catch e
            resolve stdout.trim() or 'Response received'
        else
          reject new Error "Command exited with code #{code}: #{stderr}"
  
  sendMessage: (sessionId, message) ->
    settings = @storage.getSettings()
    bot = @storage.getActiveBot()
    
    apiKey = settings.apiKey
    unless apiKey
      throw new Error 'No API key configured'
    
    isAgent = bot?.isAgent?() or bot?.model?.rawId?() == 'openclaw-agent'
    
    if isAgent
      @storage.addAgentMessage(sessionId, 'user', message)
      response = await @callAPI(sessionId, message, settings, bot)
      @storage.addAgentMessage(sessionId, 'assistant', response)
    else
      @storage.addMessage(sessionId, 'user', message)
      response = await @callAPI(sessionId, message, settings, bot)
      @storage.addMessage(sessionId, 'assistant', response)
    
    response
  
  callAPI: (sessionId, message, settings, bot = null) ->
    rawModel = bot?.model or settings.model or 'glm-4-flash'
    
    if (typeof rawModel == 'string' and rawModel == 'openclaw-agent') or bot?.isAgent?()
      return await @callAgent(sessionId, message)
    
    new Promise (resolve, reject) =>
      provider = @selectProvider(settings, bot)
      
      if settings.providers and settings.providers[provider]
        providerConfig = settings.providers[provider]
        apiKey = providerConfig.apiKey
        if provider == 'zhipu' and not bot?.model?
          rawModel = 'glm-4-flash'
        else
          rawModel = bot?.model or providerConfig.model or 'glm-4-flash'
      else
        apiKey = settings.apiKey
        rawModel = bot?.model or settings.model or 'glm-4-flash'
      
      modelInstance = if typeof rawModel == 'object' and rawModel?.apiId
        rawModel
      else
        Model.create(String(rawModel), provider)
      model = modelInstance.apiId()
      
      config = @MODELS[provider]
      unless config
        return reject new Error "Unknown provider: #{provider}"
      
      session = @storage.getSession(sessionId)
      systemPrompt = bot?.systemPrompt or 'You are CoffeeClaw, a helpful AI assistant. Respond in the same language the user uses. Be friendly and helpful.'
      messages = [
        { role: 'system', content: systemPrompt }
      ]
      
      if session.messages
        for msg in session.messages
          messages.push
            role: msg.role
            content: msg.content
      
      messages.push
        role: 'user'
        content: message
      
      postData = JSON.stringify
        model: model
        messages: messages
        stream: false

      options =
        hostname: config.baseUrl
        port: 443
        path: config.apiPath
        method: 'POST'
        headers:
          'Content-Type': 'application/json'
          'Authorization': "Bearer #{apiKey}"
          'Content-Length': Buffer.byteLength(postData)
      
      if provider == 'openrouter'
        options.headers['HTTP-Referer'] = 'https://coffeeclaw.app'
        options.headers['X-Title'] = 'CoffeeClaw'

      req = https.request options, (res) =>
        data = ''
        res.on 'data', (chunk) -> data += chunk
        res.on 'end', =>
          try
            result = JSON.parse data
            if result.error
              reject new Error result.error.message or 'API error'
            else if result.choices and result.choices[0]
              choice = result.choices[0]
              resolve choice.message.content
            else
              reject new Error 'Unknown response format'
          catch e
            reject e
      
      req.on 'error', reject
      req.write postData
      req.end()
  
  syncProviders: (providers, activeProvider, token) ->
    try
      config = {}
      if fs.existsSync @configFile
        config = JSON.parse fs.readFileSync @configFile, 'utf8'
      
      config.models ?= {}
      config.models.providers ?= {}
      
      providerNameMap =
        zhipu: 'glm'
        openrouter: 'openrouter'
        openai: 'openai'
      
      for providerId, providerData of providers
        continue unless providerData.apiKey
        openClawName = providerNameMap[providerId] or providerId
        
        config.models.providers[openClawName] =
          baseUrl: @getProviderBaseUrl(providerId)
          apiKey: providerData.apiKey
          api: 'openai-completions'
          models: @getProviderModels(providerId)
      
      if token
        config.gateway ?= {}
        config.gateway.auth ?= {}
        config.gateway.auth.token = token
      
      fs.writeFileSync @configFile, JSON.stringify(config, null, 2)
      console.log 'Providers synced to OpenClaw config'
      true
    catch e
      console.error 'Failed to sync providers to OpenClaw:', e
      false
  
  getProviderBaseUrl: (providerId) ->
    urls =
      zhipu: 'https://open.bigmodel.cn/api/paas/v4'
      openrouter: 'https://openrouter.ai/api/v1'
      openai: 'https://api.openai.com/v1'
    urls[providerId] or ''
  
  getProviderModels: (providerId) ->
    models =
      zhipu: [
        { id: 'GLM-4-Flash', name: 'GLM 4 Flash' }
        { id: 'GLM-4.5-air', name: 'GLM 4.5 air' }
        { id: 'GLM-4.7', name: 'GLM 4.7' }
      ]
      openrouter: [
        { id: 'auto', name: 'Auto' }
      ]
      openai: [
        { id: 'gpt-4o', name: 'GPT-4o' }
        { id: 'gpt-4o-mini', name: 'GPT-4o Mini' }
      ]
    models[providerId] or []
  
  ensureConfig: ->
    settings = @storage.getSettings()
    return unless settings.providers
    
    return unless @configExists()
    return unless fs.existsSync(@storage.storage.getPath())
    
    try
      openclawConfigMtime = fs.statSync(@configFile).mtime.getTime()
      settingsMtime = fs.statSync(@storage.storage.getPath()).mtime.getTime()
      
      if settingsMtime > openclawConfigMtime
        console.log 'CoffeeClaw settings are newer than OpenClaw config, syncing...'
        @syncProviders(settings.providers, settings.activeProvider, settings.token)
    catch e
      console.error 'Failed to ensure OpenClaw config:', e
  
  backup: ->
    try
      timestamp = new Date().toISOString().replace(/[:.]/g, '-')
      backupFile = path.join path.dirname(@configFile), "openclaw.#{timestamp}.json"
      
      if fs.existsSync @configFile
        config = JSON.parse fs.readFileSync @configFile, 'utf8'
        fs.writeFileSync backupFile, JSON.stringify(config, null, 2)
        console.log "OpenClaw config backed up to: #{backupFile}"
        true
      else
        false
    catch e
      console.error 'Error backing up OpenClaw config:', e
      false
  
  getConfig: ->
    try
      if fs.existsSync @configFile
        JSON.parse fs.readFileSync @configFile, 'utf8'
      else
        null
    catch e
      console.error 'Error reading OpenClaw config:', e
      null

module.exports = { OpenClawManager }
