# Settings class for application configuration
# Manages all user settings including providers, tokens, and integrations

{ Model, ZhipuModel, OpenAIModel, OpenRouterModel } = require './model'
{ FeishuConfig } = require './feishu-config'

class Settings
  @VERSION = 1
  
  @getSupportedProviders: ->
    Model.getSupportedProviders()
  
  @getDefaultProvider: ->
    Model.getDefaultProvider()
  
  constructor: ->
    @version = Settings.VERSION
    @token = null
    @apiKey = null
    @activeProvider = Settings.getDefaultProvider()
    @providers = {}
    @feishu = new FeishuConfig()
    @userEmail = null
    @_lastUpdated = new Date().toISOString()
  
  # Provider management
  getProvider: (id) -> @providers[id]
  
  setProvider: (id, apiKey, model) ->
    unless id in Settings.getSupportedProviders()
      throw new Error("Unsupported provider: #{id}")
    
    @providers[id] =
      apiKey: apiKey
      model: model.toJSON()
    
    @_lastUpdated = new Date().toISOString()
    this
  
  setActiveProvider: (id) ->
    unless id in Settings.getSupportedProviders()
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
    
    unless @activeProvider in Settings.getSupportedProviders()
      errors.push("Invalid active provider: #{@activeProvider}")
    
    for id, config of @providers
      unless id in Settings.getSupportedProviders()
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
    
    settings.token = data.token if data.token
    settings.apiKey = data.apiKey if data.apiKey
    settings.activeProvider = data.activeProvider ? Settings.getDefaultProvider()
    settings.userEmail = data.userEmail if data.userEmail
    
    if data.providers
      for id, providerData of data.providers
        try
          modelId = providerData.model ? ZhipuModel.DEFAULT_MODEL
          model = switch id
            when ZhipuModel.PROVIDER_NAME then new ZhipuModel(modelId)
            when OpenAIModel.PROVIDER_NAME then new OpenAIModel(modelId)
            when OpenRouterModel.PROVIDER_NAME then new OpenRouterModel(modelId)
            else new ZhipuModel(modelId)
          
          settings.setProvider(id, providerData.apiKey, model)
        catch e
          console.error "Failed to migrate provider #{id}:", e.message
    
    if data.feishu
      settings.feishu = FeishuConfig.fromLegacy(data.feishu)
    
    settings
  
  # Serialization
  toJSON: ->
    feishuData = if @feishu?.toJSON
      @feishu.toJSON()
    else if @feishu
      @feishu
    else
      new FeishuConfig().toJSON()
    
    {
      __class: 'Settings'
      version: @version
      token: @token
      apiKey: @apiKey
      activeProvider: @activeProvider
      providers: @providers
      feishu: feishuData
      userEmail: @userEmail
    }
  
  @fromJSON: (data) ->
    settings = new Settings()
    settings.version = data.version ? Settings.VERSION
    settings.token = data.token
    settings.apiKey = data.apiKey
    settings.activeProvider = data.activeProvider ? Settings.getDefaultProvider()
    settings.providers = data.providers ? {}
    settings.userEmail = data.userEmail ? null
    
    if data.feishu
      settings.feishu = FeishuConfig.fromJSON(data.feishu)
    
    settings

module.exports = { Settings }
