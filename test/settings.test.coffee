# Test suite for Settings class

{ Settings } = require '../src/settings'
{ Model, ZhipuModel, OpenAIModel, OpenRouterModel } = require '../src/model'
{ FeishuConfig } = require '../src/feishu-config'

describe 'Settings', ->
  describe 'Creation', ->
    it 'should create with default values', ->
      settings = new Settings()
      settings.version.should.equal Settings.VERSION
      settings.activeProvider.should.equal 'zhipu'
      settings.providers.should.be.an('object').that.is.empty

    it 'should have default Feishu config', ->
      settings = new Settings()
      settings.feishu.should.be.an.instanceof FeishuConfig

  describe 'Provider Management', ->
    it 'should set provider', ->
      settings = new Settings()
      model = new ZhipuModel('GLM-4-Flash')
      settings.setProvider('zhipu', 'test-api-key', model)
      provider = settings.getProvider('zhipu')
      provider.apiKey.should.equal 'test-api-key'

    it 'should set active provider', ->
      settings = new Settings()
      settings.setProvider('openai', 'key', new OpenAIModel('gpt-4o'))
      settings.setActiveProvider('openai')
      settings.activeProvider.should.equal 'openai'

    it 'should throw error for unsupported provider', ->
      settings = new Settings()
      (-( -> settings.setProvider('unknown', 'key', new ZhipuModel('test')))).should.throw Error

    it 'should get active provider config', ->
      settings = new Settings()
      model = new ZhipuModel('GLM-4-Flash')
      settings.setProvider('zhipu', 'test-key', model)
      config = settings.getActiveProviderConfig()
      config.apiKey.should.equal 'test-key'

    it 'should get active model', ->
      settings = new Settings()
      model = new ZhipuModel('GLM-4-Flash')
      settings.setProvider('zhipu', 'test-key', model)
      activeModel = settings.getActiveModel()
      activeModel.id.should.equal 'GLM-4-Flash'

  describe 'Feishu Management', ->
    it 'should set Feishu config', ->
      settings = new Settings()
      feishu = new FeishuConfig({ enabled: true, appId: 'test-id', appSecret: 'test-secret' })
      settings.setFeishu(feishu)
      settings.feishu.enabled.should.be.true

  describe 'Validation', ->
    it 'should validate with no errors when properly configured', ->
      settings = new Settings()
      model = new ZhipuModel('GLM-4-Flash')
      settings.setProvider('zhipu', 'test-key', model)
      settings.feishu = new FeishuConfig({ enabled: false })
      settings.validate().should.be.true

    it 'should throw error for invalid active provider', ->
      settings = new Settings()
      settings.activeProvider = 'invalid-provider'
      (-( -> settings.validate())).should.throw Error

    it 'should throw error for invalid model in provider', ->
      settings = new Settings()
      settings.providers['zhipu'] = { apiKey: 'test', model: { provider: 'unknown' } }
      (-( -> settings.validate())).should.throw Error

  describe 'Serialization', ->
    it 'should serialize to JSON', ->
      settings = new Settings()
      settings.setApiKey('test-api-key')
      settings.setToken('test-token')
      model = new ZhipuModel('GLM-4-Flash')
      settings.setProvider('zhipu', 'provider-key', model)
      json = settings.toJSON()
      json.__class.should.equal 'Settings'
      json.apiKey.should.equal 'test-api-key'
      json.token.should.equal 'test-token'
      json.providers['zhipu'].apiKey.should.equal 'provider-key'

    it 'should deserialize from JSON', ->
      json = {
        __class: 'Settings'
        version: 1
        apiKey: 'test-key'
        token: 'test-token'
        activeProvider: 'zhipu'
        providers: {
          zhipu: {
            apiKey: 'zhipu-key'
            model: { __class: 'ZhipuModel', id: 'GLM-4-Flash', provider: 'zhipu' }
          }
        }
        feishu: { __class: 'FeishuConfig', enabled: false }
      }
      settings = Settings.fromJSON(json)
      settings.apiKey.should.equal 'test-key'
      settings.token.should.equal 'test-token'
      settings.activeProvider.should.equal 'zhipu'

    it 'should handle null data in fromJSON', ->
      settings = Settings.fromJSON(null)
      settings.should.be.an.instanceof Settings

  describe 'Legacy Migration', ->
    it 'should migrate from legacy format', ->
      legacyData = {
        token: 'legacy-token'
        apiKey: 'legacy-api-key'
        activeProvider: 'zhipu'
        providers: {
          zhipu: { apiKey: 'zhipu-key' }
        }
      }
      settings = Settings.fromLegacy(legacyData)
      settings.token.should.equal 'legacy-token'
      settings.apiKey.should.equal 'legacy-api-key'
      settings.providers['zhipu'].apiKey.should.equal 'zhipu-key'
