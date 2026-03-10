# Identity class for managing OpenClaw agent identity
# Note: This is a simple text/markdown identity for OpenClaw, not hardware fingerprinting

class Identity
  # Default identity content
  @DEFAULT_CONTENT = """# IDENTITY.md - Who Am I?

- **Name:** CoffeeClaw
- **Creature:** AI Assistant
- **Vibe:** helpful and friendly
- **Emoji:** ☕

I am a desktop AI assistant powered by OpenClaw and Zhipu GLM models.
I can help you with various tasks and answer your questions.
"""
  
  constructor: (@content = null) ->
    @content ?= Identity.DEFAULT_CONTENT
    @createdAt = new Date().toISOString()
  
  # Get identity content
  getContent: -> @content
  
  # Update identity content
  setContent: (content) ->
    @content = content
    this
  
  # Check if identity is default
  isDefault: -> @content == Identity.DEFAULT_CONTENT
  
  # Serialization - for storage
  toJSON: ->
    {
      __class: 'Identity'
      content: @content
      createdAt: @createdAt
    }
  
  # Deserialize from JSON
  @fromJSON: (data) ->
    identity = new Identity(data.content)
    identity.createdAt = data.createdAt ? new Date().toISOString()
    identity
  
  # Create from plain text (legacy format)
  @fromString: (content) ->
    new Identity(content)
  
  # Get default identity
  @getDefault: ->
    new Identity()

module.exports = { Identity }
