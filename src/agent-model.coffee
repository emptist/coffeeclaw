# Agent Model class for managing AI agent configurations
# Each agent has specific capabilities and model settings

{ Model } = require './model'

class AgentModel
  # Class properties
  @DEFAULT_MAX_TOKENS = 4096
  @DEFAULT_TEMPERATURE = 0.7
  @SUPPORTED_CAPABILITIES = ['chat', 'code', 'search', 'image', 'voice']
  
  constructor: (@id, @name, @description, @model) ->
    # Instance properties
    @capabilities = []
    @systemPrompt = 'You are a helpful AI assistant.'
    @maxTokens = AgentModel.DEFAULT_MAX_TOKENS
    @temperature = AgentModel.DEFAULT_TEMPERATURE
    @tools = []
    @enabled = true
    @createdAt = new Date().toISOString()
    @updatedAt = @createdAt
  
  # Add capability
  addCapability: (capability) ->
    if capability in AgentModel.SUPPORTED_CAPABILITIES
      @capabilities.push(capability) unless capability in @capabilities
    @updatedAt = new Date().toISOString()
    this
  
  # Remove capability
  removeCapability: (capability) ->
    @capabilities = @capabilities.filter (c) -> c != capability
    @updatedAt = new Date().toISOString()
    this
  
  # Check if has capability
  hasCapability: (capability) ->
    @capabilities.includes(capability) or @capabilities.includes('*')
  
  # Add tool
  addTool: (tool) ->
    @tools.push(tool)
    @updatedAt = new Date().toISOString()
    this
  
  # Remove tool
  removeTool: (toolName) ->
    @tools = @tools.filter (t) -> t.name != toolName
    @updatedAt = new Date().toISOString()
    this
  
  # Update settings
  update: (settings) ->
    for key, value of settings
      switch key
        when 'systemPrompt', 'maxTokens', 'temperature', 'enabled'
          @[key] = value
        when 'capabilities'
          @capabilities = value.filter (c) => c in AgentModel.SUPPORTED_CAPABILITIES or c == '*'
        when 'tools'
          @tools = value
    
    @updatedAt = new Date().toISOString()
    this
  
  # Get configuration for API
  getApiConfig: ->
    {
      model: @model.apiId()
      max_tokens: @maxTokens
      temperature: @temperature
      system_prompt: @systemPrompt
    }
  
  # Check if agent can handle a task
  canHandle: (taskType) ->
    return false unless @enabled
    @hasCapability(taskType)
  
  # Serialization
  toJSON: ->
    {
      __class: 'AgentModel'
      id: @id
      name: @name
      description: @description
      model: @model.toJSON()
      capabilities: @capabilities
      systemPrompt: @systemPrompt
      maxTokens: @maxTokens
      temperature: @temperature
      tools: @tools
      enabled: @enabled
      createdAt: @createdAt
      updatedAt: @updatedAt
    }
  
  @fromJSON: (data) ->
    model = Model.fromJSON(data.model)
    agent = new AgentModel(data.id, data.name, data.description, model)
    agent.capabilities = data.capabilities ? []
    agent.systemPrompt = data.systemPrompt ? 'You are a helpful AI assistant.'
    agent.maxTokens = data.maxTokens ? AgentModel.DEFAULT_MAX_TOKENS
    agent.temperature = data.temperature ? AgentModel.DEFAULT_TEMPERATURE
    agent.tools = data.tools ? []
    agent.enabled = data.enabled ? true
    agent.createdAt = data.createdAt
    agent.updatedAt = data.updatedAt
    agent
  
  # Create from legacy format
  @fromLegacy: (data) ->
    { ZhipuModel } = require './model'
    
    # Determine model from legacy data
    modelId = data.model ? ZhipuModel.DEFAULT_MODEL
    model = new ZhipuModel(modelId)
    
    agent = new AgentModel(data.id, data.name, data.description, model)
    agent.capabilities = data.capabilities ? ['chat']
    agent.systemPrompt = data.systemPrompt ? data.prompt ? 'You are a helpful AI assistant.'
    agent.enabled = data.enabled ? true
    agent

# Agent Model Manager
class AgentModelManager
  constructor: ->
    @agents = new Map()
    @defaultAgentId = null
  
  # Add an agent
  addAgent: (agent) ->
    @agents.set(agent.id, agent)
    @defaultAgentId = agent.id unless @defaultAgentId
    this
  
  # Get an agent
  getAgent: (id) -> @agents.get(id)
  
  # Get default agent
  getDefaultAgent: ->
    return null unless @defaultAgentId
    @agents.get(@defaultAgentId)
  
  # Set default agent
  setDefaultAgent: (id) ->
    return false unless @agents.has(id)
    @defaultAgentId = id
    true
  
  # Remove an agent
  removeAgent: (id) ->
    return false if id == @defaultAgentId
    @agents.delete(id)
    true
  
  # Get all agents
  getAllAgents: -> Array.from(@agents.values())
  
  # Get enabled agents
  getEnabledAgents: ->
    @getAllAgents().filter (a) -> a.enabled
  
  # Find agent by capability
  findByCapability: (capability) ->
    @getAllAgents().filter (a) -> a.hasCapability(capability) and a.enabled
  
  # Serialization
  toJSON: ->
    {
      __class: 'AgentModelManager'
      agents: @getAllAgents().map (a) -> a.toJSON()
      defaultAgentId: @defaultAgentId
    }
  
  @fromJSON: (data) ->
    manager = new AgentModelManager()
    if data.agents
      for agentData in data.agents
        agent = AgentModel.fromJSON(agentData)
        manager.addAgent(agent)
    manager.defaultAgentId = data.defaultAgentId
    manager

module.exports = { AgentModel, AgentModelManager }
