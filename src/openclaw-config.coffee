# OpenClaw configuration class
# Manages OpenClaw agent configuration file (~/.openclaw/openclaw.json)

fs = require 'fs'
path = require 'path'

{ Model, ZhipuModel, OpenRouterModel, OpenAIModel } = require './model'

class OpenClawConfig
  # Class properties
  @CONFIG_DIR: path.join process.env.HOME, '.openclaw'
  @CONFIG_FILE: path.join process.env.HOME, '.openclaw', 'openclaw.json'
  
  @getProviderNameMap: ->
    map = {}
    map[ZhipuModel.PROVIDER_NAME] = ZhipuModel.OPENCLAW_NAME
    map[OpenRouterModel.PROVIDER_NAME] = OpenRouterModel.OPENCLAW_NAME
    map[OpenAIModel.PROVIDER_NAME] = OpenAIModel.OPENCLAW_NAME
    map
  
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
    openClawName = OpenClawConfig.getProviderNameMap()[providerId]
    return null unless openClawName
    
    @data.models?.providers?[openClawName]
  
  # Set provider config
  setProvider: (providerId, apiKey, baseUrl, api = 'openai-completions') ->
    openClawName = OpenClawConfig.getProviderNameMap()[providerId]
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
    openClawName = OpenClawConfig.getProviderNameMap()[providerId]
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
  
  # Check if a provider is configured with API key
  hasProvider: (providerId) ->
    openClawName = @getOpenClawName(providerId)
    @data.models?.providers?[openClawName]?.apiKey?
  
  # Get OpenClaw name for a provider
  getOpenClawName: (providerId) ->
    switch providerId
      when ZhipuModel.PROVIDER_NAME then ZhipuModel.OPENCLAW_NAME
      when OpenRouterModel.PROVIDER_NAME then OpenRouterModel.OPENCLAW_NAME
      when OpenAIModel.PROVIDER_NAME then OpenAIModel.OPENCLAW_NAME
      else OpenClawConfig.getProviderNameMap()[providerId] or providerId
  
  # Determine primary model based on available providers
  # Always selects a model with function calling capability for agent execution
  determinePrimaryModel: ->
    if @hasProvider(OpenRouterModel.PROVIDER_NAME)
      "#{OpenRouterModel.OPENCLAW_NAME}/#{OpenRouterModel.DEFAULT_MODEL}"
    else if @hasProvider(OpenAIModel.PROVIDER_NAME)
      "#{OpenAIModel.OPENCLAW_NAME}/#{OpenAIModel.DEFAULT_MODEL}"
    else
      "#{ZhipuModel.OPENCLAW_NAME}/#{ZhipuModel.DEFAULT_MODEL}"
  
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
    
    nameMap = OpenClawConfig.getProviderNameMap()
    
    # Check providers
    for providerId, providerData of providers
      openClawName = nameMap[providerId]
      continue unless openClawName
      
      existing = @data.models?.providers?[openClawName]
      return true unless existing
      return true if existing.apiKey != providerData.apiKey
    
    # Check active provider / primary model
    if activeProvider and providers[activeProvider]
      currentPrimary = @getPrimaryModel()
      openClawName = nameMap[activeProvider]
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
    
    currentPrimary = @getPrimaryModel()
    newPrimary = @determinePrimaryModel()
    
    if currentPrimary == newPrimary
      return false
    
    @backup()
    
    for providerId, providerData of settings.providers
      continue unless providerData.apiKey
      
      baseUrl = switch providerId
        when ZhipuModel.PROVIDER_NAME then 'https://open.bigmodel.cn/api/paas/v4'
        when OpenAIModel.PROVIDER_NAME then 'https://api.openai.com/v1'
        when OpenRouterModel.PROVIDER_NAME then 'https://openrouter.ai/api/v1'
        else null
      
      continue unless baseUrl
      
      @setProvider(providerId, providerData.apiKey, baseUrl)
    
    @data.agents ?= {}
    @data.agents.defaults ?= {}
    @data.agents.defaults.model ?= {}
    @data.agents.defaults.model.primary = newPrimary
    
    if settings.token
      @setToken(settings.token)
    
    @save()
  
  syncToSettings: (settings) ->
    return null unless @exists()
    
    providers = {}
    activeProvider = null
    
    providerNameMap = {}
    providerNameMap[ZhipuModel.OPENCLAW_NAME] = ZhipuModel.PROVIDER_NAME
    providerNameMap[OpenRouterModel.OPENCLAW_NAME] = OpenRouterModel.PROVIDER_NAME
    providerNameMap[OpenAIModel.OPENCLAW_NAME] = OpenAIModel.PROVIDER_NAME
    
    for openClawName, providerData of @data.models?.providers or {}
      providerId = providerNameMap[openClawName]
      continue unless providerId
      
      providers[providerId] =
        apiKey: providerData.apiKey
        model: providerData.models?[0]?.id or ZhipuModel.DEFAULT_MODEL
    
    primaryModel = @getPrimaryModel()
    if primaryModel
      parts = primaryModel.split('/')
      if parts.length == 2
        openClawName = parts[0]
        activeProvider = providerNameMap[openClawName]
    
    token = @getToken()
    
    {
      providers: providers
      activeProvider: activeProvider or settings?.activeProvider
      token: token or settings?.token
    }
  
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
  
  # Backup current config
  # Creates a timestamped backup in the same directory
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
  
  # Sync providers from CoffeeClaw settings to OpenClaw's config file
  # This ensures OpenClaw agent uses the same API keys as CoffeeClaw UI
  # Returns true if sync was performed, false otherwise
  syncFromSettings: (settings) ->
    return false unless settings?.providers
    
    currentPrimary = @getPrimaryModel()
    newPrimary = @determinePrimaryModel()
    
    if currentPrimary == newPrimary
      return false
    
    @backup()
    
    for providerId, providerData of settings.providers
      continue unless providerData.apiKey
      
      baseUrl = switch providerId
        when ZhipuModel.PROVIDER_NAME then 'https://open.bigmodel.cn/api/paas/v4'
        when OpenAIModel.PROVIDER_NAME then 'https://api.openai.com/v1'
        when OpenRouterModel.PROVIDER_NAME then 'https://openrouter.ai/api/v1'
        else null
      
      continue unless baseUrl
      
      @setProvider(providerId, providerData.apiKey, baseUrl)
    
    @data.agents ?= {}
    @data.agents.defaults ?= {}
    @data.agents.defaults.model ?= {}
    @data.agents.defaults.model.primary = newPrimary
    
    if settings.token
      @setToken(settings.token)
    
    @save()

module.exports = { OpenClawConfig }
