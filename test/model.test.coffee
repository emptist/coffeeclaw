# Test suite for Model classes

{ Model, ZhipuModel, OpenAIModel, OpenRouterModel } = require '../src/model'

describe 'Model', ->
  describe 'ZhipuModel', ->
    it 'should create a ZhipuModel instance', ->
      model = new ZhipuModel('GLM-4-Flash')
      model.id.should.equal 'GLM-4-Flash'
      model.provider.should.equal 'zhipu'

    it 'should return correct apiId', ->
      model = new ZhipuModel('GLM-4-Flash')
      model.apiId().should.equal 'GLM-4-Flash'

    it 'should return correct openClawId', ->
      model = new ZhipuModel('GLM-4-Flash')
      model.openClawId().should.equal 'glm/GLM-4-Flash'

    it 'should serialize to JSON correctly', ->
      model = new ZhipuModel('GLM-4-Flash')
      json = model.toJSON()
      json.__class.should.equal 'ZhipuModel'
      json.id.should.equal 'GLM-4-Flash'
      json.provider.should.equal 'zhipu'

    it 'should deserialize from JSON correctly', ->
      json = { __class: 'ZhipuModel', id: 'GLM-4-Flash', provider: 'zhipu' }
      model = ZhipuModel.fromJSON(json)
      model.id.should.equal 'GLM-4-Flash'
      model.provider.should.equal 'zhipu'

  describe 'OpenAIModel', ->
    it 'should create an OpenAIModel instance', ->
      model = new OpenAIModel('gpt-4o')
      model.id.should.equal 'gpt-4o'
      model.provider.should.equal 'openai'

    it 'should return correct apiId', ->
      model = new OpenAIModel('gpt-4o')
      model.apiId().should.equal 'gpt-4o'

    it 'should return correct openClawId', ->
      model = new OpenAIModel('gpt-4o')
      model.openClawId().should.equal 'openai/gpt-4o'

  describe 'OpenRouterModel', ->
    it 'should create an OpenRouterModel instance', ->
      model = new OpenRouterModel('google/gemini-pro')
      model.id.should.equal 'google/gemini-pro'
      model.provider.should.equal 'openrouter'

    it 'should return correct apiId with provider prefix', ->
      model = new OpenRouterModel('google/gemini-pro')
      model.apiId().should.equal 'openrouter/google/gemini-pro'

    it 'should return correct openClawId', ->
      model = new OpenRouterModel('google/gemini-pro')
      model.openClawId().should.equal 'openrouter/google/gemini-pro'

  describe 'Model Factory', ->
    it 'should create ZhipuModel from string', ->
      model = Model.create('GLM-4-Flash', 'zhipu')
      model.constructor.name.should.equal 'ZhipuModel'

    it 'should create OpenAIModel from string', ->
      model = Model.create('gpt-4o', 'openai')
      model.constructor.name.should.equal 'OpenAIModel'

    it 'should create OpenRouterModel from string', ->
      model = Model.create('google/gemini-pro', 'openrouter')
      model.constructor.name.should.equal 'OpenRouterModel'

    it 'should handle model IDs with slashes', ->
      model = Model.create('openrouter/google/gemini-pro', 'openrouter')
      model.id.should.equal 'gemini-pro'

    it 'should throw error for unknown provider', ->
      (-( -> Model.create('test', 'unknown'))).should.throw Error

  describe 'Model Registry', ->
    it 'should register all providers', ->
      providers = Model.getSupportedProviders()
      providers.should.include 'zhipu'
      providers.should.include 'openai'
      providers.should.include 'openrouter'

    it 'should get provider class by name', ->
      providerClass = Model.getProviderClass('zhipu')
      providerClass.name.should.equal 'ZhipuModel'
