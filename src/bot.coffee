# Bot class for managing AI assistants
# Each bot has a specific model and configuration

{ Model, ZhipuModel } = require './model'

class Bot
  # Class properties
  @DEFAULT_SKILLS = ['*']
  @MAX_NAME_LENGTH = 50
  @MAX_DESCRIPTION_LENGTH = 500
  
  constructor: (@id, @name, @description, @model, @systemPrompt, @skills) ->
    # Instance properties
    @enabled = true
    @createdAt = new Date().toISOString()
    @updatedAt = @createdAt
    
    # Validation
    Bot.validateName(@name)
    Bot.validateDescription(@description) if @description
  
  # Class methods
  @validateName: (name) ->
    if !name or name.length == 0
      throw new Error("Bot name cannot be empty")
    if name.length > Bot.MAX_NAME_LENGTH
      throw new Error("Bot name too long (max #{Bot.MAX_NAME_LENGTH} characters)")
    true
  
  @validateDescription: (description) ->
    if description?.length > Bot.MAX_DESCRIPTION_LENGTH
      throw new Error("Description too long (max #{Bot.MAX_DESCRIPTION_LENGTH} characters)")
    true
  
  @createDefaultBot: ->
    new Bot(
      'default'
      'Assistant'
      'A helpful AI assistant'
      new ZhipuModel(ZhipuModel.DEFAULT_MODEL)
      'You are a helpful assistant.'
      Bot.DEFAULT_SKILLS
    )
  
  # Instance methods
  isAgent: -> @model?.rawId() == 'openclaw-agent'
  
  getDisplayName: -> "#{@name} (#{@model.fullId()})"
  
  update: (changes) ->
    for key, value of changes
      switch key
        when 'name'
          Bot.validateName(value)
          @[key] = value
        when 'description'
          Bot.validateDescription(value)
          @[key] = value
        when 'model'
          if typeof value == 'string'
            @[key] = Model.create(value, @model?.provider ? ZhipuModel.PROVIDER_NAME)
          else if value?.toJSON
            @[key] = value
          else if value?.id
            @[key] = Model.fromJSON(value)
        when 'systemPrompt', 'skills', 'enabled'
          @[key] = value
    
    @updatedAt = new Date().toISOString()
    this
  
  # Serialization
  toJSON: ->
    {
      __class: 'Bot'
      id: @id
      name: @name
      description: @description
      model: @model.toJSON()
      systemPrompt: @systemPrompt
      skills: @skills
      enabled: @enabled
      createdAt: @createdAt
      updatedAt: @updatedAt
    }
  
  @fromJSON: (data) ->
    model = Model.fromJSON(data.model)
    bot = new Bot(
      data.id
      data.name
      data.description
      model
      data.systemPrompt
      data.skills
    )
    bot.enabled = data.enabled
    bot.createdAt = data.createdAt
    bot.updatedAt = data.updatedAt
    bot

module.exports = { Bot }
