# Test suite for FeishuConfig class

{ FeishuConfig } = require '../src/feishu-config'

describe 'FeishuConfig', ->
  describe 'Creation', ->
    it 'should create with default values', ->
      config = new FeishuConfig()
      config.enabled.should.be.false
      config.appId.should.equal ''
      config.appSecret.should.equal ''
      config.botName.should.equal FeishuConfig.DEFAULT_BOT_NAME
      config.dmPolicy.should.equal FeishuConfig.DEFAULT_DM_POLICY
      config.groupPolicy.should.equal FeishuConfig.DEFAULT_GROUP_POLICY

    it 'should create with custom options', ->
      config = new FeishuConfig({
        enabled: true
        appId: 'test-app-id'
        appSecret: 'test-secret'
        botName: 'TestBot'
        dmPolicy: 'pairing'
        groupPolicy: 'open'
      })
      config.enabled.should.be.true
      config.appId.should.equal 'test-app-id'
      config.appSecret.should.equal 'test-secret'
      config.botName.should.equal 'TestBot'
      config.dmPolicy.should.equal 'pairing'
      config.groupPolicy.should.equal 'open'

  describe 'Validation', ->
    it 'should be invalid when disabled with no app details', ->
      config = new FeishuConfig({ enabled: false })
      config.isValid().should.be.false

    it 'should be valid when enabled with app details', ->
      config = new FeishuConfig({
        enabled: true
        appId: 'test-id'
        appSecret: 'test-secret'
      })
      config.isValid().should.be.true

    it 'should validate with no errors for valid config', ->
      config = new FeishuConfig({ enabled: false })
      config.validate().should.be.true

    it 'should throw error when enabled but no appId', ->
      config = new FeishuConfig({ enabled: true, appSecret: 'secret' })
      (-( -> config.validate())).should.throw Error

    it 'should throw error when enabled but no appSecret', ->
      config = new FeishuConfig({ enabled: true, appId: 'app-id' })
      (-( -> config.validate())).should.throw Error

    it 'should throw error for invalid DM policy', ->
      config = new FeishuConfig({ dmPolicy: 'invalid' })
      (-( -> config.validate())).should.throw Error

    it 'should throw error for invalid group policy', ->
      config = new FeishuConfig({ groupPolicy: 'invalid' })
      (-( -> config.validate())).should.throw Error

  describe 'Policy Checks', ->
    it 'should not respond to DM when disabled', ->
      config = new FeishuConfig({ enabled: false })
      config.canRespondToDM().should.be.false

    it 'should not respond to DM when policy is disabled', ->
      config = new FeishuConfig({ enabled: true, dmPolicy: 'disabled' })
      config.canRespondToDM().should.be.false

    it 'should respond to DM when enabled and policy allows', ->
      config = new FeishuConfig({ enabled: true, dmPolicy: 'open' })
      config.canRespondToDM().should.be.true

    it 'should not respond to group when disabled', ->
      config = new FeishuConfig({ enabled: false })
      config.canRespondToGroup().should.be.false

    it 'should not respond to group when policy is disabled', ->
      config = new FeishuConfig({ enabled: true, groupPolicy: 'disabled' })
      config.canRespondToGroup().should.be.false

    it 'should respond to group when enabled and policy allows', ->
      config = new FeishuConfig({ enabled: true, groupPolicy: 'open' })
      config.canRespondToGroup().should.be.true

    it 'should need pairing for DM when policy is pairing', ->
      config = new FeishuConfig({ dmPolicy: 'pairing' })
      config.needsPairingForDM().should.be.true

    it 'should need pairing for group when policy is pairing', ->
      config = new FeishuConfig({ groupPolicy: 'pairing' })
      config.needsPairingForGroup().should.be.true

  describe 'Update', ->
    it 'should update enabled', ->
      config = new FeishuConfig()
      config.update({ enabled: true })
      config.enabled.should.be.true

    it 'should update appId', ->
      config = new FeishuConfig()
      config.update({ appId: 'new-id' })
      config.appId.should.equal 'new-id'

    it 'should update appSecret', ->
      config = new FeishuConfig()
      config.update({ appSecret: 'new-secret' })
      config.appSecret.should.equal 'new-secret'

    it 'should update dmPolicy', ->
      config = new FeishuConfig()
      config.update({ dmPolicy: 'pairing' })
      config.dmPolicy.should.equal 'pairing'

    it 'should throw error for invalid policy update', ->
      config = new FeishuConfig()
      (-( -> config.update({ dmPolicy: 'invalid' }))).should.throw Error

  describe 'Connection Tracking', ->
    it 'should mark connected', ->
      config = new FeishuConfig()
      config.markConnected()
      status = config.getConnectionStatus()
      status.status.should.equal 'connected'
      status.lastConnectedAt.should.not.be.null

    it 'should mark disconnected', ->
      config = new FeishuConfig()
      config.markConnected()
      config.markDisconnected()
      status = config.getConnectionStatus()
      status.status.should.equal 'disconnected'

  describe 'Serialization', ->
    it 'should serialize to JSON', ->
      config = new FeishuConfig({
        enabled: true
        appId: 'test-id'
        appSecret: 'test-secret'
        botName: 'TestBot'
        dmPolicy: 'pairing'
        groupPolicy: 'open'
      })
      json = config.toJSON()
      json.__class.should.equal 'FeishuConfig'
      json.enabled.should.be.true
      json.appId.should.equal 'test-id'
      json.botName.should.equal 'TestBot'
      json.dmPolicy.should.equal 'pairing'

    it 'should deserialize from JSON', ->
      json = {
        __class: 'FeishuConfig'
        enabled: true
        appId: 'test-id'
        appSecret: 'test-secret'
        botName: 'TestBot'
        dmPolicy: 'pairing'
        groupPolicy: 'open'
      }
      config = FeishuConfig.fromJSON(json)
      config.enabled.should.be.true
      config.appId.should.equal 'test-id'
      config.botName.should.equal 'TestBot'
      config.dmPolicy.should.equal 'pairing'

  describe 'Legacy Migration', ->
    it 'should migrate from legacy format', ->
      legacyData = {
        enabled: true
        appId: 'legacy-id'
        appSecret: 'legacy-secret'
        botName: 'LegacyBot'
      }
      config = FeishuConfig.fromLegacy(legacyData)
      config.enabled.should.be.true
      config.appId.should.equal 'legacy-id'
      config.botName.should.equal 'LegacyBot'
      config.dmPolicy.should.equal FeishuConfig.DEFAULT_DM_POLICY
