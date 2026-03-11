# API Client - Handles all AI provider API calls
# Encapsulates HTTP requests, model formatting, and response parsing

https = require 'https'
http = require 'http'

{ Model, ZhipuModel, OpenRouterModel } = require './model'

class APIClient
  @instance = null
  
  @getInstance: (options) ->
    @instance ?= new APIClient(options)
  
  constructor: (options = {}) ->
    @MODELS = options.models or {}
    @storage = options.storage
    @skills = options.skills or {}
  
  call: (sessionId, message, settings, bot = null) ->
    rawModel = bot?.model or settings.model or ZhipuModel.DEFAULT_MODEL
    
    if rawModel == 'modelclaw-agent' or bot?.isAgent
      throw new Error 'Use OpenClawManager.callAgent for agent calls'
    
    provider = settings.activeProvider or settings.provider or ZhipuModel.PROVIDER_NAME
    
    if settings.providers and settings.providers[provider]
      providerConfig = settings.providers[provider]
      apiKey = providerConfig.apiKey
      rawModel = bot?.model or providerConfig.model or ZhipuModel.DEFAULT_MODEL
    else
      apiKey = settings.apiKey
      rawModel = bot?.model or settings.model or ZhipuModel.DEFAULT_MODEL
    
    modelInstance = if typeof rawModel == 'object' and rawModel?.apiId
      rawModel
    else
      Model.create(String(rawModel), provider)
    model = modelInstance.apiId()
    
    config = @MODELS[provider]
    unless config
      throw new Error "Unknown provider: #{provider}"
    
    session = @storage.getSession(sessionId)
    systemPrompt = bot?.systemPrompt or 'You are CoffeeClaw, a helpful AI assistant. Respond in the same language the user uses. Be friendly and helpful.'
    
    messages = [
      { role: 'system', content: systemPrompt }
    ]
    
    if session.messages
      for msg in session.messages
        messages.push
          role: msg.role
          content: msg.content
    
    messages.push
      role: 'user'
      content: message
    
    functions = @getSkillFunctions(bot?.skills)
    
    postData =
      model: model
      messages: messages
      stream: false
    
    if functions.length > 0
      postData.tools = functions.map (f) -> { type: 'function', function: f }
      postData.tool_choice = 'auto'
      postData.do_sample = false
    
    await @makeRequest(config, postData, apiKey, provider, sessionId, messages, settings, bot)
  
  makeRequest: (config, postData, apiKey, provider, sessionId, messages, settings, bot) ->
    new Promise (resolve, reject) =>
      postDataStr = JSON.stringify postData
      
      options =
        hostname: config.baseUrl
        port: 443
        path: config.apiPath
        method: 'POST'
        headers:
          'Content-Type': 'application/json'
          'Authorization': "Bearer #{apiKey}"
          'Content-Length': Buffer.byteLength(postDataStr)
      
      if provider == OpenRouterModel.PROVIDER_NAME
        options.headers['HTTP-Referer'] = 'https://coffeeclaw.app'
        options.headers['X-Title'] = 'CoffeeClaw'

      req = https.request options, (res) =>
        data = ''
        res.on 'data', (chunk) -> data += chunk
        res.on 'end', =>
          try
            result = JSON.parse data
            if result.error
              reject new Error result.error.message or 'API error'
            else if result.choices and result.choices[0]
              choice = result.choices[0]
              if choice.message?.tool_calls
                toolCall = choice.message.tool_calls[0]
                if toolCall?.type == 'function'
                  funcName = toolCall.function.name
                  funcArgs = JSON.parse toolCall.function.arguments
                  funcResult = @executeSkillFunction(funcName, funcArgs, bot?.skills)
                  messages.push choice.message
                  messages.push
                    role: 'tool'
                    content: JSON.stringify funcResult
                    tool_call_id: toolCall.id
                  @callWithMessages(sessionId, messages, settings, bot, apiKey)
                    .then resolve
                    .catch reject
                  return
              resolve choice.message.content
            else
              reject new Error 'Unknown response format'
          catch e
            reject e
      
      req.on 'error', reject
      req.write postDataStr
      req.end()
  
  callWithMessages: (sessionId, messages, settings, bot, apiKey) ->
    provider = settings.activeProvider or settings.provider or ZhipuModel.PROVIDER_NAME
    
    if settings.providers and settings.providers[provider]
      providerConfig = settings.providers[provider]
      apiKey = providerConfig.apiKey
    
    rawModel = bot?.model or settings.model or ZhipuModel.DEFAULT_MODEL
    modelInstance = if typeof rawModel == 'object' and rawModel?.apiId
      rawModel
    else
      Model.create(String(rawModel), provider)
    model = modelInstance.apiId()
    
    config = @MODELS[provider]
    
    postData =
      model: model
      messages: messages
      stream: false
    
    functions = @getSkillFunctions(bot?.skills)
    if functions.length > 0
      postData.tools = functions.map (f) -> { type: 'function', function: f }
      postData.tool_choice = 'auto'
      postData.do_sample = false
    
    @makeRequest(config, postData, apiKey, provider, sessionId, messages, settings, bot)
  
  getSkillFunctions: (botSkills) ->
    return [] unless botSkills and botSkills.length > 0
    
    allSkills = botSkills.includes('*')
    
    functions = []
    for name, skill of @skills
      if allSkills or botSkills.includes(name)
        functions.push
          name: name
          description: skill.description
          parameters: skill.parameters
    
    functions
  
  executeSkillFunction: (name, args, botSkills) ->
    skill = @skills[name]
    unless skill
      return { error: "Unknown skill: #{name}" }
    
    allSkills = botSkills?.includes('*')
    unless allSkills or botSkills?.includes(name)
      return { error: "Skill #{name} not enabled for this bot" }
    
    try
      skill.handler(args)
    catch e
      { error: e.message }

module.exports = { APIClient }
