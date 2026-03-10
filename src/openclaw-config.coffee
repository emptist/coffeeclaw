# OpenClaw configuration class
# Manages OpenClaw agent configuration file (~/.openclaw/openclaw.json)

fs = require 'fs'
path = require 'path'

class OpenClawConfig
  # Class properties
  @CONFIG_DIR: path.join process.env.HOME, '.openclaw'
  @CONFIG_FILE: path.join process.env.HOME, '.openclaw', 'openclaw.json'
  @PROVIDER_NAME_MAP:
    zhipu: 'glm'
    openrouter: 'openrouter'
    deepseek: 'deepseek'
    openai: 'openai'
  
  constructor: ->
    @data = @load()
  
  # Load config from file
  load: ->
    try
      if fs.existsSync(OpenClawConfig.CONFIG_FILE)
        JSON.parse fs.readFileSync(OpenClawConfig.CONFIG_FILE, 'utf8')
      else
        @createDefault()
    catch e
      console.error 'Failed to load OpenClaw config:', e
      @createDefault()
  
  # Create default config structure
  createDefault: ->
    {
      models:
        providers: {}
      agents:
        defaults:
          model:
            primary: null
      gateway:
        auth:
          mode: 'token'
          token: null
        remote:
          token: null
    }
  
  # Save config to file
  save: ->
    try
      # Ensure directory exists
      unless fs.existsSync(OpenClawConfig.CONFIG_DIR)
        fs.mkdirSync(OpenClawConfig.CONFIG_DIR, recursive: true)
      
      fs.writeFileSync OpenClawConfig.CONFIG_FILE, JSON.stringify(@data, null, 2)
      true
    catch e
      console.error 'Failed to save OpenClaw config:', e
      false
  
  # Check if config exists
  exists: ->
    fs.existsSync(OpenClawConfig.CONFIG_FILE)
  
  # Get provider config for OpenClaw
  getProviderConfig: (providerId) ->
    openClawName = OpenClawConfig.PROVIDER_NAME_MAP[providerId]
    return null unless openClawName
    
    @data.models?.providers?[openClawName]
  
  # Set provider config
  setProvider: (providerId, apiKey, baseUrl, api = 'openai-completions') ->
    openClawName = OpenClawConfig.PROVIDER_NAME_MAP[providerId]
    return false unless openClawName
    
    @data.models ?= {}
    @data.models.providers ?= {}
    
    @data.models.providers[openClawName] =
      baseUrl: baseUrl
      apiKey: apiKey
      api: api
      models: []
    
    true
  
  # Set primary model
  setPrimaryModel: (providerId, modelId) ->
    openClawName = OpenClawConfig.PROVIDER_NAME_MAP[providerId]
    return false unless openClawName
    
    # Handle both string and Model instance
    if typeof modelId == 'object' and modelId?.id
      # It's a Model instance, use openClawId() if available
      modelIdStr = modelId.openClawId?() or modelId.id
    else
      modelIdStr = modelId
    
    # Format model ID for OpenClaw
    fullModelId = if modelIdStr.startsWith(openClawName)
      modelIdStr
    else
      "#{openClawName}/#{modelIdStr}"
    
    @data.agents ?= {}
    @data.agents.defaults ?= {}
    @data.agents.defaults.model ?= {}
    @data.agents.defaults.model.primary = fullModelId
    
    true
  
  # Get primary model
  getPrimaryModel: ->
    @data.agents?.defaults?.model?.primary
  
  # Set auth token
  setToken: (token) ->
    @data.gateway ?= {}
    @data.gateway.auth ?= {}
    @data.gateway.auth.mode = 'token'
    @data.gateway.auth.token = token
    
    @data.gateway.remote ?= {}
    @data.gateway.remote.token = token
    
    true
  
  # Get token
  getToken: ->
    @data.gateway?.auth?.token
  
  # Check if sync is needed (compare with external settings)
  needsSync: (providers, activeProvider, token) ->
    return true unless @exists()
    
    # Check providers
    for providerId, providerData of providers
      openClawName = OpenClawConfig.PROVIDER_NAME_MAP[providerId]
      continue unless openClawName
      
      existing = @data.models?.providers?[openClawName]
      return true unless existing
      return true if existing.apiKey != providerData.apiKey
    
    # Check active provider / primary model
    if activeProvider and providers[activeProvider]
      currentPrimary = @getPrimaryModel()
      openClawName = OpenClawConfig.PROVIDER_NAME_MAP[activeProvider]
      if openClawName
        rawModelId = providers[activeProvider].model
        # Handle both string and Model instance
        if typeof rawModelId == 'object' and rawModelId?.id
          modelId = rawModelId.openClawId?() or rawModelId.id
        else
          modelId = rawModelId
        expectedPrimary = if modelId.startsWith(openClawName)
          modelId
        else
          "#{openClawName}/#{modelId}"
        return true if currentPrimary != expectedPrimary
    
    # Check token
    if token and @getToken() != token
      return true
    
    false
  
  # Sync from CoffeeClaw settings
  syncFromSettings: (settings) ->
    return false unless settings?.providers
    
    # Check if sync is needed
    return false unless @needsSync(
      settings.providers
      settings.activeProvider
      settings.token
    )
    
    # Backup existing config
    @backup()
    
    # Sync providers
    for providerId, providerData of settings.providers
      continue unless providerData.apiKey
      
      # Determine base URL based on provider
      baseUrl = switch providerId
        when 'zhipu' then 'https://open.bigmodel.cn/api/paas/v4'
        when 'deepseek' then 'https://api.deepseek.com/v1'
        when 'openai' then 'https://api.openai.com/v1'
        when 'openrouter' then 'https://openrouter.ai/api/v1'
        else null
      
      continue unless baseUrl
      
      @setProvider(providerId, providerData.apiKey, baseUrl)
    
    # Sync active provider / primary model
    if settings.activeProvider and settings.providers[settings.activeProvider]
      providerData = settings.providers[settings.activeProvider]
      if providerData.model
        @setPrimaryModel(settings.activeProvider, providerData.model)
    
    # Sync token
    if settings.token
      @setToken(settings.token)
    
    # Save
    @save()
  
  # Backup current config
  backup: ->
    try
      return false unless @exists()
      
      timestamp = new Date().toISOString().replace(/[:.]/g, '-')
      backupFile = path.join(
        OpenClawConfig.CONFIG_DIR
        "openclaw.json.backup.#{timestamp}"
      )
      
      fs.copyFileSync(OpenClawConfig.CONFIG_FILE, backupFile)
      
      # Clean up old backups (keep last 10)
      @cleanupOldBackups()
      
      true
    catch e
      console.error 'Failed to backup OpenClaw config:', e
      false
  
  # Clean up old backups
  cleanupOldBackups: (keep = 10) ->
    try
      files = fs.readdirSync(OpenClawConfig.CONFIG_DIR)
        .filter (f) -> f.startsWith('openclaw.json.backup.')
        .sort()
      
      if files.length > keep
        filesToDelete = files.slice(0, files.length - keep)
        for file in filesToDelete
          fs.unlinkSync(path.join(OpenClawConfig.CONFIG_DIR, file))
          console.log "Cleaned up old backup: #{file}"
    catch e
      console.error 'Failed to cleanup old backups:', e
  
  # Fix model ID format in config
  # Converts "glm-4-flash" to "glm/glm-4-flash" format
  fixModelFormat: ->
    try
      primary = @getPrimaryModel()
      if primary and not primary.includes('/')
        # Model ID is missing provider prefix
        # Try to infer provider from available providers
        for providerName of @data.models?.providers
          # Check if this provider has a model matching primary
          provider = @data.models.providers[providerName]
          hasModel = provider.models?.some (m) -> m.id == primary
          if hasModel
            fixedId = "#{providerName}/#{primary}"
            @data.agents.defaults.model.primary = fixedId
            console.log "Fixed model format: #{primary} -> #{fixedId}"
            @save()
            return true
      false
    catch e
      console.error 'Failed to fix model format:', e
      false
  
  # Get file modification time
  getMtime: ->
    try
      fs.statSync(OpenClawConfig.CONFIG_FILE).mtime.getTime()
    catch e
      0
  
  # Serialization
  toJSON: ->
    @data
  
  @fromJSON: (data) ->
    config = new OpenClawConfig()
    config.data = data
    config

module.exports = { OpenClawConfig }
