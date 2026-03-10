# Settings class for application configuration
# Manages all user settings including providers, tokens, and integrations

{ Model, ZhipuModel, OpenAIModel, OpenRouterModel } = require './model'
{ FeishuConfig } = require './feishu-config'

class Settings
  # Class properties
  @DEFAULT_PROVIDER = 'zhipu'
  @SUPPORTED_PROVIDERS = ['zhipu', 'openai', 'openrouter']
  @VERSION = 1
  
  constructor: ->
    # Instance properties
    @version = Settings.VERSION
    @token = null
    @apiKey = null
    @activeProvider = Settings.DEFAULT_PROVIDER
    @providers = {}
    @feishu = new FeishuConfig()
    @_lastUpdated = new Date().toISOString()
  
  # Provider management
  getProvider: (id) -> @providers[id]
  
  setProvider: (id, apiKey, model) ->
    unless id in Settings.SUPPORTED_PROVIDERS
      throw new Error("Unsupported provider: #{id}")
    
    @providers[id] =
      apiKey: apiKey
      model: model.toJSON()
    
    @_lastUpdated = new Date().toISOString()
    this
  
  setActiveProvider: (id) ->
    unless id in Settings.SUPPORTED_PROVIDERS
      throw new Error("Unsupported provider: #{id}")
    
    @activeProvider = id
    @_lastUpdated = new Date().toISOString()
    this
  
  getActiveProviderConfig: ->
    @providers[@activeProvider]
  
  getActiveModel: ->
    config = @getActiveProviderConfig()
    return null unless config?.model
    Model.fromJSON(config.model)
  
  # Token management
  setToken: (token) ->
    @token = token
    @_lastUpdated = new Date().toISOString()
    this
  
  setApiKey: (apiKey) ->
    @apiKey = apiKey
    @_lastUpdated = new Date().toISOString()
    this
  
  # Feishu management
  setFeishu: (config) ->
    if config instanceof FeishuConfig
      @feishu = config
    else
      @feishu = FeishuConfig.fromJSON(config)
    
    @_lastUpdated = new Date().toISOString()
    this
  
  # Validation
  validate: ->
    errors = []
    
    unless @activeProvider in Settings.SUPPORTED_PROVIDERS
      errors.push("Invalid active provider: #{@activeProvider}")
    
    # Validate each provider config
    for id, config of @providers
      unless id in Settings.SUPPORTED_PROVIDERS
        errors.push("Unknown provider in config: #{id}")
      
      if config.model
        try
          model = Model.fromJSON(config.model)
        catch e
          errors.push("Invalid model for #{id}: #{e.message}")
    
    # Validate Feishu config
    try
      @feishu.validate()
    catch e
      errors.push("Feishu config error: #{e.message}")
    
    if errors.length > 0
      throw new Error(errors.join(', '))
    
    true
  
  # Migration from legacy format
  @fromLegacy: (data) ->
    settings = new Settings()
    
    # Copy basic fields
    settings.token = data.token if data.token
    settings.apiKey = data.apiKey if data.apiKey
    settings.activeProvider = data.activeProvider ? Settings.DEFAULT_PROVIDER
    
    # Migrate providers
    if data.providers
      for id, providerData of data.providers
        try
          # Try to determine model from legacy data
          modelId = providerData.model ? 'glm-4-flash'
          model = switch id
            when 'zhipu' then new ZhipuModel(modelId)
            when 'openai' then new OpenAIModel(modelId)
            when 'openrouter' then new OpenRouterModel(modelId)
            else new ZhipuModel(modelId)
          
          settings.setProvider(id, providerData.apiKey, model)
        catch e
          console.error "Failed to migrate provider #{id}:", e.message
    
    # Migrate Feishu config
    if data.feishu
      settings.feishu = FeishuConfig.fromLegacy(data.feishu)
    
    settings
  
  # Serialization
  toJSON: ->
    {
      __class: 'Settings'
      version: @version
      token: @token
      apiKey: @apiKey
      activeProvider: @activeProvider
      providers: @providers
      feishu: @feishu.toJSON()
      # Note: _lastUpdated is not saved
    }
  
  @fromJSON: (data) ->
    settings = new Settings()
    settings.version = data.version ? Settings.VERSION
    settings.token = data.token
    settings.apiKey = data.apiKey
    settings.activeProvider = data.activeProvider ? Settings.DEFAULT_PROVIDER
    settings.providers = data.providers ? {}
    
    if data.feishu
      settings.feishu = FeishuConfig.fromJSON(data.feishu)
    
    settings

module.exports = { Settings }
