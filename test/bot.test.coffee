# Test suite for Bot class

{ Bot } = require '../src/bot'
{ Model, ZhipuModel, OpenAIModel } = require '../src/model'

describe 'Bot', ->
  describe 'Creation', ->
    it 'should create a bot with required parameters', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Test Bot', 'A test bot', model, 'You are helpful.', ['skill1'])
      bot.id.should.equal 'bot-1'
      bot.name.should.equal 'Test Bot'
      bot.description.should.equal 'A test bot'
      bot.model.id.should.equal 'GLM-4-Flash'
      bot.systemPrompt.should.equal 'You are helpful.'
      bot.skills.should.deep.equal ['skill1']
      bot.enabled.should.be.true

    it 'should create default bot', ->
      bot = Bot.createDefaultBot()
      bot.id.should.equal 'default'
      bot.name.should.equal 'Assistant'
      bot.model.id.should.equal 'GLM-4-Flash'

  describe 'Validation', ->
    it 'should validate name - throw for empty name', ->
      (-( -> Bot.validateName(''))).should.throw Error
      (-( -> Bot.validateName(null))).should.throw Error
      (-( -> Bot.validateName(undefined))).should.throw Error

    it 'should validate name - throw for name too long', ->
      longName = 'a'.repeat(Bot.MAX_NAME_LENGTH + 1)
      (-( -> Bot.validateName(longName))).should.throw Error

    it 'should validate name - accept valid name', ->
      Bot.validateName('Valid Bot').should.be.true

    it 'should validate description - throw for description too long', ->
      longDesc = 'a'.repeat(Bot.MAX_DESCRIPTION_LENGTH + 1)
      (-( -> Bot.validateDescription(longDesc))).should.throw Error

    it 'should validate description - accept valid description', ->
      Bot.validateDescription('Valid description').should.be.true

  describe 'Instance Methods', ->
    it 'should check if agent', ->
      model = new ZhipuModel('openclaw-agent')
      bot = new Bot('agent-1', 'Agent', 'An agent', model, 'You are an agent.', [])
      bot.isAgent().should.be.true

    it 'should not be agent for non-agent model', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Bot', 'A bot', model, 'You are a bot.', [])
      bot.isAgent().should.be.false

    it 'should get display name with model info', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'TestBot', 'A bot', model, 'You are helpful.', [])
      bot.getDisplayName().should.equal 'TestBot (zhipu/GLM-4-Flash)'

  describe 'Update', ->
    it 'should update name', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Old Name', 'A bot', model, 'You are helpful.', [])
      bot.update({ name: 'New Name' })
      bot.name.should.equal 'New Name'

    it 'should update description', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Bot', 'Old desc', model, 'You are helpful.', [])
      bot.update({ description: 'New description' })
      bot.description.should.equal 'New description'

    it 'should update model from string', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Bot', 'A bot', model, 'You are helpful.', [])
      bot.update({ model: 'gpt-4o' })
      bot.model.id.should.equal 'gpt-4o'
      bot.model.provider.should.equal 'zhipu'

    it 'should update model from Model instance', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Bot', 'A bot', model, 'You are helpful.', [])
      newModel = new OpenAIModel('gpt-4o')
      bot.update({ model: newModel })
      bot.model.id.should.equal 'gpt-4o'
      bot.model.provider.should.equal 'openai'

    it 'should update systemPrompt', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Bot', 'A bot', model, 'Old prompt', [])
      bot.update({ systemPrompt: 'New prompt' })
      bot.systemPrompt.should.equal 'New prompt'

    it 'should update skills', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Bot', 'A bot', model, 'You are helpful.', ['skill1'])
      bot.update({ skills: ['skill1', 'skill2'] })
      bot.skills.should.deep.equal ['skill1', 'skill2']

    it 'should update enabled', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Bot', 'A bot', model, 'You are helpful.', [])
      bot.update({ enabled: false })
      bot.enabled.should.be.false

  describe 'Serialization', ->
    it 'should serialize to JSON', ->
      model = new ZhipuModel('GLM-4-Flash')
      bot = new Bot('bot-1', 'Test Bot', 'A test bot', model, 'You are helpful.', ['skill1'])
      bot.enabled = false
      json = bot.toJSON()
      json.__class.should.equal 'Bot'
      json.id.should.equal 'bot-1'
      json.name.should.equal 'Test Bot'
      json.enabled.should.be.false
      json.model.id.should.equal 'GLM-4-Flash'
      json.skills.should.deep.equal ['skill1']

    it 'should deserialize from JSON', ->
      json = {
        __class: 'Bot'
        id: 'bot-1'
        name: 'Test Bot'
        description: 'A test bot'
        model: { __class: 'ZhipuModel', id: 'GLM-4-Flash', provider: 'zhipu' }
        systemPrompt: 'You are helpful.'
        skills: ['skill1']
        enabled: false
        createdAt: '2024-01-01T00:00:00.000Z'
        updatedAt: '2024-01-01T00:00:00.000Z'
      }
      bot = Bot.fromJSON(json)
      bot.id.should.equal 'bot-1'
      bot.name.should.equal 'Test Bot'
      bot.enabled.should.be.false
      bot.model.id.should.equal 'GLM-4-Flash'
      bot.skills.should.deep.equal ['skill1']
