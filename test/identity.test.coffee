# Test suite for Identity class

{ Identity } = require '../src/identity'

describe 'Identity', ->
  describe 'Creation', ->
    it 'should create with default content', ->
      identity = new Identity()
      identity.content.should.equal Identity.DEFAULT_CONTENT

    it 'should create with custom content', ->
      customContent = '# Custom Identity'
      identity = new Identity(customContent)
      identity.content.should.equal customContent

    it 'should create default identity', ->
      identity = Identity.getDefault()
      identity.content.should.equal Identity.DEFAULT_CONTENT

  describe 'Content Management', ->
    it 'should get content', ->
      identity = new Identity('Test content')
      identity.getContent().should.equal 'Test content'

    it 'should set content', ->
      identity = new Identity()
      identity.setContent('New content')
      identity.content.should.equal 'New content'

  describe 'Default Check', ->
    it 'should detect default identity', ->
      identity = new Identity()
      identity.isDefault().should.be.true

    it 'should detect non-default identity', ->
      identity = new Identity('Custom content')
      identity.isDefault().should.be.false

  describe 'Serialization', ->
    it 'should serialize to JSON', ->
      identity = new Identity('Test content')
      json = identity.toJSON()
      json.__class.should.equal 'Identity'
      json.content.should.equal 'Test content'
      json.createdAt.should.not.be.null

    it 'should deserialize from JSON', ->
      json = {
        __class: 'Identity'
        content: 'Test content'
        createdAt: '2024-01-01T00:00:00.000Z'
      }
      identity = Identity.fromJSON(json)
      identity.content.should.equal 'Test content'
      identity.createdAt.should.equal '2024-01-01T00:00:00.000Z'

    it 'should handle null data in fromJSON', ->
      identity = Identity.fromJSON(null)
      identity.content.should.equal Identity.DEFAULT_CONTENT

    it 'should handle partial JSON data', ->
      json = { content: 'Partial content' }
      identity = Identity.fromJSON(json)
      identity.content.should.equal 'Partial content'

  describe 'Legacy Format', ->
    it 'should create from plain string', ->
      identity = Identity.fromString('Plain text identity')
      identity.content.should.equal 'Plain text identity'
