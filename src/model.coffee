# Model class hierarchy for different AI providers
# Each subclass defines its own provider-specific behavior

class Model
  # Class properties - defined in subclasses
  @PROVIDER_NAME: null
  @OPENCLAW_NAME: null
  @DEFAULT_API_PATH: null
  
  # Registry of provider classes
  @_providers: {}
  
  @registerProvider: (providerClass) ->
    @_providers[providerClass.PROVIDER_NAME] = providerClass
  
  @getSupportedProviders: ->
    Object.keys(@_providers)
  
  @getDefaultProvider: ->
    'zhipu'
  
  @getProviderClass: (name) ->
    @_providers[name]
  
  constructor: (@id) ->
    @provider = @constructor.PROVIDER_NAME
  
  # Instance properties
  rawId: -> @id
  fullId: -> "#{@provider}/#{@id}"
  
  # To be implemented by subclasses
  apiId: -> throw new Error("Subclass must implement apiId()")
  openClawId: -> throw new Error("Subclass must implement openClawId()")
  
  # Serialization - only instance properties
  toJSON: ->
    {
      __class: @constructor.name
      id: @id
      provider: @provider
    }
  
  # Factory method to create correct subclass from JSON
  @fromJSON: (data) ->
    switch data.provider
      when ZhipuModel.PROVIDER_NAME then ZhipuModel.fromJSON(data)
      when OpenAIModel.PROVIDER_NAME then OpenAIModel.fromJSON(data)
      when OpenRouterModel.PROVIDER_NAME then OpenRouterModel.fromJSON(data)
      else throw new Error("Unknown provider: #{data.provider}")
  
  # Factory method to create model instance from model ID and provider
  @create: (modelId, provider) ->
    # Strip provider prefix if present
    cleanId = modelId
    if modelId.includes('/')
      parts = modelId.split('/')
      cleanId = parts[parts.length - 1]
    
    switch provider
      when ZhipuModel.PROVIDER_NAME then new ZhipuModel(cleanId)
      when OpenAIModel.PROVIDER_NAME then new OpenAIModel(cleanId)
      when OpenRouterModel.PROVIDER_NAME then new OpenRouterModel(cleanId)
      else throw new Error("Unknown provider: #{provider}")

# Zhipu AI (智谱AI)
class ZhipuModel extends Model
  @PROVIDER_NAME: 'zhipu'
  @OPENCLAW_NAME: 'glm'
  @DEFAULT_API_PATH: '/api/paas/v4/chat/completions'
  @DEFAULT_MODEL: 'GLM-4-Flash'
  
  constructor: (id) ->
    super(id)
    @apiPath = @constructor.DEFAULT_API_PATH
  
  # Zhipu API uses model ID without prefix
  apiId: -> @id
  
  # OpenClaw uses glm/ prefix
  openClawId: -> "#{@constructor.OPENCLAW_NAME}/#{@id}"
  
  toJSON: ->
    {
      __class: 'ZhipuModel'
      id: @id
      provider: @provider
      apiPath: @apiPath
    }
  
  @fromJSON: (data) ->
    model = new ZhipuModel(data.id)
    model.apiPath = data.apiPath if data.apiPath
    model

# OpenAI
class OpenAIModel extends Model
  @PROVIDER_NAME: 'openai'
  @OPENCLAW_NAME: 'openai'
  @DEFAULT_API_PATH: '/v1/chat/completions'
  @DEFAULT_MODEL: 'gpt-4o'
  
  constructor: (id) ->
    super(id)
    @apiPath = @constructor.DEFAULT_API_PATH
    @organization = null
  
  apiId: -> @id
  openClawId: -> "#{@constructor.OPENCLAW_NAME}/#{@id}"
  
  toJSON: ->
    {
      __class: 'OpenAIModel'
      id: @id
      provider: @provider
      apiPath: @apiPath
      organization: @organization
    }
  
  @fromJSON: (data) ->
    model = new OpenAIModel(data.id)
    model.apiPath = data.apiPath if data.apiPath
    model.organization = data.organization if data.organization
    model

# OpenRouter
class OpenRouterModel extends Model
  @PROVIDER_NAME: 'openrouter'
  @OPENCLAW_NAME: 'openrouter'
  @DEFAULT_API_PATH: '/api/v1/chat/completions'
  @DEFAULT_MODEL: 'auto'
  
  constructor: (id) ->
    super(id)
    @apiPath = @constructor.DEFAULT_API_PATH
    @siteUrl = null
    @siteName = null
  
  # OpenRouter API requires full path with provider prefix
  apiId: -> "#{@provider}/#{@id}"
  openClawId: -> "#{@constructor.OPENCLAW_NAME}/#{@id}"
  
  toJSON: ->
    {
      __class: 'OpenRouterModel'
      id: @id
      provider: @provider
      apiPath: @apiPath
      siteUrl: @siteUrl
      siteName: @siteName
    }
  
  @fromJSON: (data) ->
    model = new OpenRouterModel(data.id)
    model.apiPath = data.apiPath if data.apiPath
    model.siteUrl = data.siteUrl if data.siteUrl
    model.siteName = data.siteName if data.siteName
    model

# Export classes
Model.registerProvider(ZhipuModel)
Model.registerProvider(OpenAIModel)
Model.registerProvider(OpenRouterModel)

module.exports = {
  Model
  ZhipuModel
  OpenAIModel
  OpenRouterModel
}
