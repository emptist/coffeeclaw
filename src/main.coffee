# CoffeeClaw - Main Process
# Auto-configures OpenClaw on first run

{ app, BrowserWindow, ipcMain, shell } = require 'electron'
path = require 'path'
fs = require 'fs'
http = require 'http'
https = require 'https'
{ exec, spawn } = require 'child_process'
crypto = require 'crypto'

# Import new class hierarchy
{ Model, ZhipuModel, OpenAIModel, OpenRouterModel } = require './model'
{ Bot } = require './bot'
{ Session, SessionManager } = require './session'
{ Settings } = require './settings'
{ FeishuConfig } = require './feishu-config'
{ OpenClawConfig } = require './openclaw-config'
{ License } = require './license'
{ Identity } = require './identity'
{ BackupManager } = require './backup-manager'
{ AgentModel, AgentModelManager } = require './agent-model'

# Import typed storage
{ TypedStorage } = require './core/typed-storage'
storage = TypedStorage.getInstance()

openclawDir = path.join process.env.HOME, '.openclaw'
configFile = path.join openclawDir, 'openclaw.json'
workspaceDir = path.join openclawDir, 'workspace'
identityFile = path.join workspaceDir, 'IDENTITY.md'
agentDir = path.join openclawDir, 'agents', 'main', 'agent'
agentMdFile = path.join agentDir, 'agent.md'
agentModelsFile = path.join agentDir, 'models.json'
secreteDir = path.join path.dirname(__dirname), '.secrete'
settingsFile = path.join secreteDir, 'settings.json'
sessionsFile = path.join secreteDir, 'sessions.json'
botsFile = path.join secreteDir, 'bots.json'
licenseFile = path.join secreteDir, 'license.json'
agentSessionsFile = path.join secreteDir, 'agent-sessions.json'

USD_TO_CNY = 6

LICENSE_PRICES =
  yearly_usd: 12
  yearly_cny: 12 * USD_TO_CNY
  lifetime_usd: 36
  lifetime_cny: 36 * USD_TO_CNY
  btc_address: null
  monthly_usd: 1
  monthly_cny: 1 * USD_TO_CNY

INITIAL_BALANCE_USD = 1
INITIAL_BALANCE_CNY = 1 * USD_TO_CNY
MAX_HISTORY = 100
MAX_SESSIONS = 50

isWindows = process.platform == 'win32'
isMac = process.platform == 'darwin'

generateToken = ->
  crypto.randomBytes(24).toString 'hex'

generateId = ->
  Date.now().toString(36) + Math.random().toString(36).substr(2, 9)

# Settings - using TypedStorage
loadSettings = -> storage.getSettings()
saveSettings = (settings = null) -> storage.saveSettings(settings)

backupSettings = ->
  try
    backupData =
      version: '1.0'
      backedUpAt: new Date().toISOString()
      settings: loadSettings().toJSON()
      bots: loadBots()
      sessions: loadSessions().toJSON()
      license: loadLicense().toJSON()
      identity: loadIdentity().toJSON()
    
    backup = storage.createBackup(backupData)
    console.log "Backup created: #{backup.id}"
    true
  catch e
    console.error 'Error backing up:', e
    false

restoreSettings = (backupId, options = {}) ->
  try
    backup = storage.getBackup(backupId)
    return false unless backup?.data
    
    data = backup.data
    restoreSettings = options.settings ? true
    restoreSessions = options.sessions ? true
    restoreBots = options.bots ? true
    restoreLicense = options.license ? true
    restoreIdentity = options.identity ? true
    
    if data.settings and restoreSettings
      settings = Settings.fromJSON(data.settings)
      saveSettings(settings)
    if data.sessions and restoreSessions
      sessions = SessionManager.fromJSON(data.sessions)
      saveSessions(sessions)
    if data.bots and restoreBots
      storage.saveBots(data.bots)
    if data.license and restoreLicense
      license = License.fromJSON(data.license)
      saveLicense(license)
    if data.identity and restoreIdentity
      identity = Identity.fromJSON(data.identity)
      saveIdentity(identity)
    
    console.log "Backup restored: #{backupId}"
    true
  catch e
    console.error 'Error restoring backup:', e
    false

getBackupData = (backupId) ->
  backup = storage.getBackup(backupId)
  backup?.data ? null

listSettingsBackups = ->
  storage.getBackups().map (b) ->
    id: b.id
    createdAt: b.createdAt

exportAllSettings = ->
  storage.exportAll()

importAllSettings = (data, options = {}) ->
  storage.importAll(data, options)

# License - using TypedStorage
loadLicense = -> storage.getLicense()
saveLicense = (license = null) -> storage.saveLicense(license)
getLicenseStatus = -> storage.getLicenseStatus()

# Sessions - using TypedStorage
loadSessions = -> storage.getSessions()
saveSessions = (sessions = null) -> storage.saveSessions(sessions)
getSession = (sessionId) -> storage.getSession(sessionId)
saveSession = (sessionId, session) ->
  if session.messages?.length > MAX_HISTORY
    session.messages = session.messages.slice(-MAX_HISTORY)
  storage.saveSessions()
addToSession = (sessionId, role, content) -> storage.addMessage(sessionId, role, content)
createSession = -> storage.createSession()
deleteSession = (sessionId) -> storage.deleteSession(sessionId)
listSessions = -> storage.listSessions()

# Agent Sessions - using TypedStorage
loadAgentSessions = -> storage.getAgentSessions()
saveAgentSessions = (sessions = null) -> storage.saveAgentSessions(sessions)
getAgentSession = (sessionId) -> storage.getAgentSession(sessionId)
addToAgentSession = (sessionId, role, content) -> storage.addAgentMessage(sessionId, role, content)
listAgentSessions = -> storage.listAgentSessions()
deleteAgentSession = (sessionId) -> storage.deleteAgentSession(sessionId)

BOT_TEMPLATES = [
  {
    id: 'openclaw-agent'
    name: 'OpenClaw Agent'
    description: 'Direct channel to OpenClaw Agent with full development tools'
    model: 'openclaw-agent'
    systemPrompt: 'You are the OpenClaw Agent, a powerful AI assistant with access to development tools, file system, and code analysis capabilities.'
    skills: ['*']
    isAgent: true
  }
  {
    id: 'code-helper'
    name: 'Code Helper'
    description: 'Expert assistant for Swift, CoffeeScript, and Python development'
    model: 'glm-4-flash'
    systemPrompt: 'You are an expert software developer specializing in Swift, CoffeeScript, and Python. When asked about files or code, ALWAYS use your available tools FIRST: use list_files to explore directories, read_file to read source code, and execute for shell commands. Do not give generic answers - read the actual files and provide specific insights. Help with coding tasks, debugging, code review, and best practices. Always provide clean, well-commented code examples.'
    skills: ['fs', 'code', 'git']
  }
  {
    id: 'writer'
    name: 'Creative Writer'
    description: 'Creative writing assistant for content creation'
    model: 'glm-4-flash'
    systemPrompt: 'You are a creative writing assistant. You help with blog posts, articles, stories, and other content. You have excellent grammar and style. You can adapt to different tones and audiences. Always be creative and engaging.'
    skills: ['*']
  }
  {
    id: 'translator'
    name: 'Translator'
    description: 'Multilingual translation assistant'
    model: 'glm-4-flash'
    systemPrompt: 'You are a professional translator. You translate text accurately while preserving meaning, tone, and cultural context. You support English, Chinese, and Esperanto. Always ask for clarification if the source text is ambiguous.'
    skills: ['*']
  }
]

getBotTemplates = -> BOT_TEMPLATES

# Bots - using TypedStorage
loadBots = -> storage.getBots()
saveBots = (bots = null) -> storage.saveBots(bots)
getBot = (botId) -> storage.getBot(botId)
getActiveBot = -> storage.getActiveBot()
createBot = (config) -> storage.createBot(config)
updateBot = (botId, updates) -> storage.updateBot(botId, updates)
deleteBot = (botId) -> storage.deleteBot(botId)
setActiveBot = (botId) -> storage.setActiveBot(botId)

SKILLS =
  fs:
    list_files:
      description: 'List all files and directories in a given path. Use this to explore the file system.'
      parameters:
        type: 'object'
        properties:
          path: { type: 'string', description: 'Directory path to list (default: current directory)' }
        required: []
      handler: (args) ->
        try
          targetPath = args.path or process.cwd()
          files = fs.readdirSync targetPath, { withFileTypes: true }
          results = files.map (f) ->
            type: if f.isDirectory() then 'directory' else 'file'
            name: f.name
          { success: true, files: results, path: targetPath }
        catch e
          { success: false, error: e.message }
    read_file:
      description: 'Read and return the contents of a file. Use this to read source code, config files, etc.'
      parameters:
        type: 'object'
        properties:
          path: { type: 'string', description: 'File path to read (required)' }
        required: ['path']
      handler: (args) ->
        try
          ALLOWED_BASE = process.env.HOME
          resolvedPath = path.resolve(args.path)
          unless resolvedPath.startsWith(path.resolve(ALLOWED_BASE))
            return { success: false, error: 'Path not allowed: must be within home directory' }
          realPath = fs.realpathSync args.path
          unless realPath.startsWith(path.resolve(ALLOWED_BASE))
            return { success: false, error: 'Symlink points outside allowed directory' }
          content = fs.readFileSync realPath, 'utf8'
          { success: true, content: content.substring(0, 10000) }
        catch e
          { success: false, error: e.message }
  code:
    execute:
      description: 'Execute a shell command and return the output. Use for commands like ls, git, npm, etc.'
      parameters:
        type: 'object'
        properties:
          command: { type: 'string', description: 'Shell command to execute (required)' }
          cwd: { type: 'string', description: 'Working directory (default: current directory)' }
        required: ['command']
      handler: (args) ->
        try
          ALLOWED_COMMANDS = ['ls', 'git', 'npm', 'node', 'cat', 'pwd', 'echo', 'mkdir', 'touch', 'rm', 'cp', 'mv', 'find', 'grep', 'curl', 'wget']
          cmd = args.command.trim().split(/\s+/)[0]
          unless cmd in ALLOWED_COMMANDS
            return { success: false, error: "Command '#{cmd}' not allowed. Allowed: #{ALLOWED_COMMANDS.join(', ')}" }
          PROHIBITED_REGEX = /[;&|`$()\[\]{}]/
          cmdArgs = args.command.trim().split(/\s+/)
          for arg, idx in cmdArgs
            if PROHIBITED_REGEX.test arg
              return { success: false, error: "Argument #{idx + 1} contains forbidden shell metacharacter: #{arg}" }
          result = require('child_process').execSync args.command,
            cwd: args.cwd or process.cwd()
            encoding: 'utf8'
            timeout: 30000
          { success: true, output: result.substring(0, 5000) }
        catch e
          { success: false, error: e.message, output: e.stdout or '' }
  git:
    status:
      description: 'Get git status showing modified, added, and untracked files.'
      parameters:
        type: 'object'
        properties:
          cwd: { type: 'string', description: 'Working directory (default: current directory)' }
      handler: (args) ->
        try
          result = require('child_process').execSync 'git status --short',
            cwd: args.cwd or process.cwd()
            encoding: 'utf8'
          { success: true, status: result }
        catch e
          { success: false, error: e.message }
    log:
      description: 'Get recent git commit history.'
      parameters:
        type: 'object'
        properties:
          count: { type: 'integer', description: 'Number of commits to show (default: 10)' }
          cwd: { type: 'string', description: 'Working directory' }
      handler: (args) ->
        try
          count = args.count or 10
          result = require('child_process').execSync "git log --oneline -#{count}",
            cwd: args.cwd or process.cwd()
            encoding: 'utf8'
          { success: true, log: result }
        catch e
          { success: false, error: e.message }

getSkillFunctions = (botSkills) ->
  return [] unless botSkills and botSkills[0] != '*'
  functions = []
  for skillName in botSkills
    skill = SKILLS[skillName]
    continue unless skill
    for funcName, funcDef of skill
      functions.push { name: funcName, description: funcDef.description, parameters: funcDef.parameters }
  functions

executeSkillFunction = (name, args, botSkills) ->
  for skillName in (botSkills or ['*'])
    if skillName == '*'
      for skillName2, skill of SKILLS
        if skill[name]
          return skill[name].handler args
    else
      skill = SKILLS[skillName]
      if skill?[name]
        return skill[name].handler args
  { success: false, error: "Unknown function: #{name}" }

deleteSession = (sessionId) ->
  sessions = loadSessions()
  delete sessions[sessionId]
  saveSessions sessions

listSessions = ->
  manager = loadSessions()
  # SessionManager returns array of Session instances
  if manager?.getAllSessions
    sessions = manager.getAllSessions()
  else if typeof manager == 'object'
    # Legacy format: object with sessionId keys
    sessions = []
    for key, session of manager
      sessions.push session
  else
    sessions = []
  
  # Sort by updatedAt, handling both Session instances and plain objects
  sessions.sort (a, b) ->
    aTime = a.updatedAt or a.getLastUpdated?() or 0
    bTime = b.updatedAt or b.getLastUpdated?() or 0
    bTime - aTime
  sessions

checkOpenClaw = (callback) ->
  req = http.get 'http://127.0.0.1:18789/health', (res) ->
    callback true
  req.on 'error', -> callback false
  req.setTimeout 2000, ->
    req.destroy()
    callback false

checkOpenClawPromise = ->
  new Promise (resolve) ->
    checkOpenClaw resolve

startOpenClaw = ->
  new Promise (resolve) ->
    console.log 'Starting OpenClaw gateway...'
    child = spawn 'openclaw', ['gateway', '--dev'],
      detached: true
      stdio: 'ignore'
    child.unref()
    
    attempts = 0
    maxAttempts = 30
    check = ->
      attempts++
      checkOpenClaw (running) ->
        if running
          resolve true
        else if attempts < maxAttempts
          setTimeout check, 1000
        else
          resolve false
    setTimeout check, 2000

configExists = ->
  try
    fs.existsSync configFile
  catch
    false

isConfigured = ->
  settings = loadSettings()
  settings.token and settings.apiKey

createDefaultConfig = (apiKey) ->
  console.log 'Creating OpenClaw config...'
  
  settings = loadSettings()
  token = settings.token or generateToken()
  key = apiKey or settings.apiKey or ''
  
  fs.mkdirSync openclawDir, { recursive: true } unless fs.existsSync openclawDir
  fs.mkdirSync workspaceDir, { recursive: true } unless fs.existsSync workspaceDir
  fs.mkdirSync agentDir, { recursive: true } unless fs.existsSync agentDir
  
  defaultConfig =
    meta:
      lastTouchedVersion: '2026.3.2'
      lastTouchedAt: new Date().toISOString()
    env: {}
    models:
      providers: {}
    agents:
      defaults:
        model:
          primary: 'glm/glm-4-flash'
        models:
          'glm/glm-4-flash': {}
        compaction:
          mode: 'safeguard'
    commands:
      native: 'auto'
      nativeSkills: 'auto'
      restart: true
      ownerDisplay: 'raw'
    channels:
      feishu:
        enabled: false
    gateway:
      mode: 'local'
      http:
        endpoints:
          chatCompletions:
            enabled: true
      auth:
        mode: 'token'
        token: token

  if key
    defaultConfig.env.ZHIPU_API_KEY = key
    defaultConfig.models.providers.glm =
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4'
      apiKey: key
      api: 'openai-completions'
      models: [
        { id: 'GLM-4-Flash', name: 'GLM 4 Flash' }
        { id: 'GLM-4.5-air', name: 'GLM 4.5 air' }
        { id: 'GLM-4.7', name: 'GLM 4.7' }
      ]

  fs.writeFileSync configFile, JSON.stringify(defaultConfig, null, 2)
  console.log 'Config created at:', configFile
  
  settings.token = token
  settings.apiKey = key if key
  saveSettings settings
  
  createIdentity()
  createAgentConfig key
  
  token

# Global identity instance
identityInstance = null

createIdentity = ->
  identityInstance = storage.getIdentity()
  if fs.existsSync identityFile
    console.log 'Identity already exists at:', identityFile
    return
  
  console.log 'Creating identity...'
  fs.writeFileSync identityFile, identityInstance.getContent()
  console.log 'Identity created at:', identityFile

loadIdentity = ->
  return identityInstance if identityInstance
  identityInstance = storage.getIdentity()
  identityInstance

saveIdentity = (identity = null) ->
  identityInstance = identity ? identityInstance
  storage.saveIdentity(identityInstance)
  if identityInstance
    fs.writeFileSync identityFile, identityInstance.getContent()

createAgentConfig = (apiKey) ->
  storage.createDefaultAgentModels(apiKey)
  
  agentMd = """# Agent Configuration

## Identity
You are a helpful AI assistant running on the user's local machine. You are powered by GLM-4-Flash model from Zhipu AI.

## Capabilities
- File system access (sandboxed)
- System command execution (limited)
- Answer questions and provide assistance

## Safety Rules
- Confirm destructive actions
- Respect user privacy
- Be helpful and concise

## Communication
- Respond in the same language the user uses
- Be friendly and professional
- Provide clear and accurate information
"""
  
  fs.writeFileSync agentMdFile, agentMd
  console.log 'Agent config created'

checkOpenClawInstalled = ->
  new Promise (resolve) ->
    cmd = if isWindows then 'where openclaw' else 'which openclaw'
    exec cmd, (err) ->
      resolve not err

checkNodeInstalled = ->
  new Promise (resolve) ->
    exec 'node --version', (err, stdout) ->
      resolve not err

checkNpmInstalled = ->
  new Promise (resolve) ->
    exec 'npm --version', (err, stdout) ->
      resolve not err

checkWSLInstalled = ->
  new Promise (resolve) ->
    exec 'wsl --list', (err, stdout) ->
      resolve not err

getPlatform = ->
  process.platform

installOpenClaw = ->
  new Promise (resolve, reject) ->
    console.log 'Installing OpenClaw...'
    exec 'npm install -g openclaw', (err, stdout, stderr) ->
      if err
        console.error 'Install error:', stderr
        reject err
      else
        console.log 'OpenClaw installed successfully'
        resolve true

MODELS =
  zhipu:
    name: 'Zhipu GLM'
    models: [
      { id: 'glm-4-flash', name: 'GLM-4-Flash (Free)', free: true, functionCalling: true, agentCapable: false }
      { id: 'glm-4-plus', name: 'GLM-4-Plus', agentCapable: false }
      { id: 'glm-4-air', name: 'GLM-4-Air', agentCapable: false }
    ]
    baseUrl: 'open.bigmodel.cn'
    apiPath: '/api/paas/v4/chat/completions'
  openrouter:
    name: 'OpenRouter'
    models: [
      { id: 'openrouter/auto', name: 'Auto (Free: 50 req/day)', free: true, freeLimit: '50/day', agentCapable: true }
      { id: 'google/gemini-2.0-flash-001', name: 'Gemini 2.0 Flash', free: true, freeLimit: '50/day', agentCapable: true }
      { id: 'meta-llama/llama-3.3-70b-instruct', name: 'Llama 3.3 70B', free: true, freeLimit: '50/day', agentCapable: true }
    ]
    baseUrl: 'openrouter.ai'
    apiPath: '/api/v1/chat/completions'
  openai:
    name: 'OpenAI'
    models: [
      { id: 'gpt-4o-mini', name: 'GPT-4o Mini', agentCapable: true }
      { id: 'gpt-4o', name: 'GPT-4o', agentCapable: true }
      { id: 'gpt-4-turbo', name: 'GPT-4 Turbo', agentCapable: true }
    ]
    baseUrl: 'api.openai.com'
    apiPath: '/v1/chat/completions'

callOpenClawAgent = (sessionId, message) ->
  new Promise (resolve, reject) ->
    unless /^[a-zA-Z0-9_-]+$/.test sessionId
      return reject new Error "Invalid sessionId - must match ^[a-zA-Z0-9_-]+$"

    { spawn } = require 'child_process'

    args = [
      'agent'
      '--local'
      '--session-id', sessionId
      '--message', message
      '--json'
    ]

    child = spawn 'openclaw', args, stdio: ['ignore', 'pipe', 'pipe']

    stdout = ''
    stderr = ''

    child.stdout.on 'data', (chunk) -> stdout += chunk.toString()
    child.stderr.on 'data', (chunk) -> stderr += chunk.toString()

    child.on 'error', (err) -> reject err

    child.on 'close', (code) ->
      if code is 0
        try
          jsonMatch = stdout.match /\{[\s\S]*"payloads"[\s\S]*\}/
          if jsonMatch
            result = JSON.parse jsonMatch[0]
            payloads = result?.payloads or []
            text = ''
            for p in payloads
              if p.type == 'text' or p.text
                text += p.text or p.content or ''
            if not text and result?.meta?.agentMeta
              text = 'Response received (check session for details)'
            resolve text or 'No response'
          else
            resolve stdout.trim() or 'Response received'
        catch e
          resolve stdout.trim() or 'Response received'
      else
        reject new Error "Command exited with code #{code}: #{stderr}"

callAPI = (sessionId, message, settings, bot = null) ->
  rawModel = bot?.model or settings.model or 'glm-4-flash'
  
  if rawModel == 'openclaw-agent' or bot?.isAgent
    return await callOpenClawAgent(sessionId, message)
  
  new Promise (resolve, reject) ->
    provider = settings.activeProvider or settings.provider or 'zhipu'
    
    if settings.providers and settings.providers[provider]
      providerConfig = settings.providers[provider]
      apiKey = providerConfig.apiKey
      rawModel = bot?.model or providerConfig.model or 'glm-4-flash'
    else
      apiKey = settings.apiKey
      rawModel = bot?.model or settings.model or 'glm-4-flash'
    
    # Convert to Model instance and use apiId() for correct format
    modelInstance = if typeof rawModel == 'object' and rawModel?.apiId
      rawModel
    else
      Model.create(String(rawModel), provider)
    model = modelInstance.apiId()
    
    config = MODELS[provider]
    unless config
      return reject new Error "Unknown provider: #{provider}"
    
    session = getSession sessionId
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
    
    functions = getSkillFunctions bot?.skills
    postData =
      model: model
      messages: messages
      stream: false
    
    if functions.length > 0
      postData.tools = functions.map (f) -> { type: 'function', function: f }
      postData.tool_choice = 'auto'
      postData.do_sample = false
    
    postData = JSON.stringify postData

    options =
      hostname: config.baseUrl
      port: 443
      path: config.apiPath
      method: 'POST'
      headers:
        'Content-Type': 'application/json'
        'Authorization': "Bearer #{apiKey}"
        'Content-Length': Buffer.byteLength(postData)
    
    if provider == 'openrouter'
      options.headers['HTTP-Referer'] = 'https://coffeeclaw.app'
      options.headers['X-Title'] = 'CoffeeClaw'

    req = https.request options, (res) ->
      data = ''
      res.on 'data', (chunk) -> data += chunk
      res.on 'end', ->
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
                funcResult = executeSkillFunction funcName, funcArgs, bot?.skills
                messages.push choice.message
                messages.push
                  role: 'tool'
                  content: JSON.stringify funcResult
                  tool_call_id: toolCall.id
                callAPIWithMessages sessionId, messages, settings, bot, apiKey
                  .then resolve
                  .catch reject
                return
            resolve choice.message.content
          else
            reject new Error 'Unknown response format'
        catch e
          reject e

    req.on 'error', reject
    req.setTimeout 60000, ->
      req.destroy()
      reject new Error 'Request timeout'
    req.write postData
    req.end()

callAPIWithMessages = (sessionId, messages, settings, bot, apiKey) ->
  new Promise (resolve, reject) ->
    provider = settings.activeProvider or settings.provider or 'zhipu'
    
    if settings.providers and settings.providers[provider]
      providerConfig = settings.providers[provider]
      rawModel = bot?.model or providerConfig.model or 'glm-4-flash'
    else
      rawModel = bot?.model or settings.model or 'glm-4-flash'
    
    # Convert to Model instance and use apiId() for correct format
    modelInstance = if typeof rawModel == 'object' and rawModel?.apiId
      rawModel
    else
      Model.create(String(rawModel), provider)
    model = modelInstance.apiId()
    
    config = MODELS[provider]
    
    postData =
      model: model
      messages: messages
      stream: false
      do_sample: false
    
    postData = JSON.stringify postData

    options =
      hostname: config.baseUrl
      port: 443
      path: config.apiPath
      method: 'POST'
      headers:
        'Content-Type': 'application/json'
        'Authorization': "Bearer #{apiKey}"
        'Content-Length': Buffer.byteLength(postData)
    
    if provider == 'openrouter'
      options.headers['HTTP-Referer'] = 'https://coffeeclaw.app'
      options.headers['X-Title'] = 'CoffeeClaw'

    req = https.request options, (res) ->
      data = ''
      res.on 'data', (chunk) -> data += chunk
      res.on 'end', ->
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
                funcResult = executeSkillFunction funcName, funcArgs, bot?.skills
                messages.push choice.message
                messages.push
                  role: 'tool'
                  content: JSON.stringify funcResult
                  tool_call_id: toolCall.id
                callAPIWithMessages sessionId, messages, settings, bot, apiKey
                  .then resolve
                  .catch reject
                return
            resolve choice.message.content
          else
            reject new Error 'Unknown response format'
        catch e
          reject e

    req.on 'error', reject
    req.setTimeout 60000, ->
      req.destroy()
      reject new Error 'Request timeout'
    req.write postData
    req.end()

sendToOpenClaw = (sessionId, message) ->
  settings = loadSettings()
  apiKey = settings.apiKey
  
  unless apiKey
    throw new Error 'No API key configured'
  
  bot = getActiveBot()
  isAgent = bot?.isAgent or bot?.model == 'openclaw-agent'
  
  if isAgent
    addToAgentSession sessionId, 'user', message
    response = await callAPI sessionId, message, settings, bot
    addToAgentSession sessionId, 'assistant', response
  else
    addToSession sessionId, 'user', message
    response = await callAPI sessionId, message, settings, bot
    addToSession sessionId, 'assistant', response
  response

mainWindow = null

createWindow = ->
  mainWindow = new BrowserWindow
    width: 1200
    height: 800
    minWidth: 800
    minHeight: 600
    webPreferences:
      nodeIntegration: false
      contextIsolation: true
      preload: path.join __dirname, 'preload.js'
  
  mainWindow.loadFile 'index.html'
  
  mainWindow.on 'closed', ->
    mainWindow = null

app.whenReady().then ->
  backupSettings()
  
  # Fix OpenClaw config if needed
  try
    openClawConfig = getOpenClawConfig()
    if openClawConfig.exists()
      fixed = openClawConfig.fixModelFormat()
      console.log 'OpenClaw config model format fixed' if fixed
  catch e
    console.error 'Failed to fix OpenClaw config:', e
  
  createWindow()

  app.on 'activate', ->
    if BrowserWindow.getAllWindows().length == 0
      createWindow()

app.on 'before-quit', ->
  backupSettings()

app.on 'window-all-closed', ->
  if process.platform != 'darwin'
    app.quit()

ipcMain.handle 'send-message', (event, sessionId, message) ->
  try
    result = await sendToOpenClaw sessionId, message
    return result
  catch e
    throw e.message or e

ipcMain.handle 'check-status', ->
  running = await checkOpenClawPromise()
  configured = isConfigured()
  settings = loadSettings()
  
  # Ensure OpenClaw config is in sync with CoffeeClaw settings
  # This handles cases where settings were modified or app was updated
  ensureOpenClawConfig()
  
  if not running and configured
    startOpenClaw()
    return { running: false, starting: true, configured: true, hasApiKey: !!settings.apiKey }
  
  { running, starting: false, configured, hasApiKey: !!settings.apiKey }

ipcMain.handle 'check-prerequisites', ->
  platform: getPlatform()
  isWindows: isWindows
  isMac: isMac
  nodeInstalled: await checkNodeInstalled()
  npmInstalled: await checkNpmInstalled()
  openclawInstalled: await checkOpenClawInstalled()
  wslInstalled: if isWindows then await checkWSLInstalled() else false

ipcMain.handle 'has-backup', ->
  try
    if fs.existsSync settingsFile
      return true
    files = fs.readdirSync(secreteDir).filter (f) -> f.startsWith('backup.') and f.endsWith('.json')
    return files.length > 0
  catch
    false

ipcMain.handle 'create-session', ->
  createSession()

ipcMain.handle 'get-bots', -> loadBots()
ipcMain.handle 'get-bot', (event, botId) -> getBot botId
ipcMain.handle 'get-active-bot', -> getActiveBot()
ipcMain.handle 'create-bot', (event, botConfig) -> createBot botConfig
ipcMain.handle 'update-bot', (event, botId, updates) -> updateBot botId, updates
ipcMain.handle 'delete-bot', (event, botId) -> deleteBot botId
ipcMain.handle 'set-active-bot', (event, botId) -> setActiveBot botId
ipcMain.handle 'get-bot-templates', -> getBotTemplates()

ipcMain.handle 'export-bots', ->
  try
    botsData = loadBots()
    settings = loadSettings()
    {
      success: true
      data:
        bots: botsData.bots
        activeBotId: botsData.activeBotId
        settings:
          token: settings.token
          apiKey: settings.apiKey
          provider: settings.provider
          model: settings.model
          feishu: settings.feishu
        exportedAt: new Date().toISOString()
        version: '1.0'
        instructions: 'To restore: Click Edit Bot button → Import → Select this file'
    }
  catch e
    { success: false, error: e.message }

ipcMain.handle 'import-bots', (event, data) ->
  try
    unless data.bots and Array.isArray data.bots
      return { success: false, error: 'Invalid data: bots array required' }
    
    botsData = loadBots()
    imported = 0
    
    for bot in data.bots
      if bot.id and bot.name
        existing = botsData.bots.find (b) -> b.id == bot.id
        if existing
          Object.assign existing, bot
        else
          botsData.bots.push bot
        imported++
    
    saveBots botsData
    
    if data.settings
      settings = loadSettings()
      if data.settings.token
        settings.token = data.settings.token
      if data.settings.apiKey
        settings.apiKey = data.settings.apiKey
      if data.settings.provider
        settings.provider = data.settings.provider
      if data.settings.model
        settings.model = data.settings.model
      if data.settings.feishu
        settings.feishu = data.settings.feishu
      saveSettings settings
    
    { success: true, imported: imported, total: botsData.bots.length }
  catch e
    { success: false, error: e.message }

ipcMain.handle 'backup-settings', -> backupSettings()
ipcMain.handle 'list-backups', -> listSettingsBackups()
ipcMain.handle 'restore-backup', (event, backupName, options) -> restoreSettings backupName, options
ipcMain.handle 'get-backup-data', (event, backupName) -> getBackupData backupName
ipcMain.handle 'export-all-settings', -> exportAllSettings()
ipcMain.handle 'import-all-settings', (event, data, options) -> importAllSettings data, options

ipcMain.handle 'open-external', (event, url) ->
  shell.openExternal url

ipcMain.handle 'get-feishu-status', ->
  settings = loadSettings()
  existing = detectExistingFeishuConfig()
  {
    enabled: settings.feishu?.enabled or false
    configured: existing?.enabled or false
    appId: settings.feishu?.appId or null
  }

ipcMain.handle 'sync-feishu-to-openclaw', -> syncFeishuConfigToOpenClaw()

ipcMain.handle 'approve-feishu-pairing', (event, code) ->
  new Promise (resolve, reject) ->
    CODE_REGEX = /^[a-zA-Z0-9_-]{10,64}$/
    
    unless CODE_REGEX.test(code)
      return resolve { success: false, error: 'Invalid pairing code format' }
    
    { spawn } = require 'child_process'
    
    child = spawn 'openclaw', ['pairing', 'approve', 'feishu', code]
    
    stdout = ''
    stderr = ''
    
    child.stdout.on 'data', (chunk) -> stdout += chunk.toString()
    child.stderr.on 'data', (chunk) -> stderr += chunk.toString()
    
    child.on 'error', (err) ->
      console.error 'Error approving pairing:', err
      resolve { success: false, error: err.message }
    
    child.on 'close', (code) ->
      if code is 0
        console.log 'Pairing approved:', stdout
        resolve { success: true, output: stdout }
      else
        console.error 'Pairing failed:', stderr
        resolve { success: false, error: "Exit code: #{code}" }

ipcMain.handle 'get-session', (event, sessionId) ->
  getSession sessionId

ipcMain.handle 'list-sessions', ->
  listSessions()

ipcMain.handle 'delete-session', (event, sessionId) ->
  deleteSession sessionId
  true

ipcMain.handle 'get-agent-session', (event, sessionId) ->
  getAgentSession sessionId

ipcMain.handle 'list-agent-sessions', ->
  listAgentSessions()

ipcMain.handle 'get-history', ->
  listSessions()

ipcMain.handle 'clear-history', ->
  manager = loadSessions()
  if manager?.clearAllSessions
    manager.clearAllSessions()
    saveSessions(manager)
  true

ipcMain.handle 'run-setup', (event, apiKey) ->
  result =
    installing: false
    configuring: false
    starting: false
  
  installed = await checkOpenClawInstalled()
  if not installed
    result.installing = true
    try
      await installOpenClaw()
    catch e
      throw new Error 'Failed to install OpenClaw: ' + e.message
  
  result.configuring = true
  token = createDefaultConfig apiKey
  
  result.starting = true
  started = await startOpenClaw()
  if not started
    throw new Error 'Failed to start OpenClaw gateway'
  
  result

ipcMain.handle 'get-settings', ->
  loadSettings()

# Mapping from CoffeeClaw provider names to OpenClaw provider names
# CoffeeClaw uses: zhipu, openrouter, openai, deepseek
# OpenClaw uses: glm, openrouter, openai, deepseek (same except zhipu→glm)
PROVIDER_NAME_MAP =
  zhipu: 'glm'
  openrouter: 'openrouter'
  openai: 'openai'
  deepseek: 'deepseek'

# Get the OpenClaw-compatible provider config from MODELS
getOpenClawProviderConfig = (providerId, apiKey) ->
  modelConfig = MODELS[providerId]
  return null unless modelConfig
  
  # Build the provider config that OpenClaw expects
  providerConfig =
    baseUrl: "https://#{modelConfig.baseUrl}#{modelConfig.apiPath}".replace('/chat/completions', '')
    apiKey: apiKey
    api: 'openai-completions'
    models: modelConfig.models.map (m) ->
      id: m.id
      name: m.name
  
  # Special handling for zhipu (glm) - use full API path
  if providerId is 'zhipu'
    providerConfig.baseUrl = "https://open.bigmodel.cn/api/paas/v4"
  
  providerConfig

# Backup OpenClaw config before modifying
# Creates a timestamped backup in the same directory
# Global backup manager instance
backupManagerInstance = null

getBackupManager = ->
  unless backupManagerInstance
    backupManagerInstance = new BackupManager()
  backupManagerInstance

backupOpenClawConfig = ->
  return unless configExists()
  
  try
    manager = getBackupManager()
    # Read OpenClaw config and create backup
    configData = JSON.parse(fs.readFileSync(configFile, 'utf8'))
    result = manager.createBackup(configData)
    
    if result.success
      console.log "Backed up OpenClaw config to: #{result.filepath}"
    else
      console.error 'Failed to create backup:', result.error
  catch e
    console.error 'Failed to backup OpenClaw config:', e

# Sync providers from CoffeeClaw settings to OpenClaw's config file
# This ensures the OpenClaw agent uses the same API keys as the CoffeeClaw UI
# Returns true if sync was performed, false otherwise
# Global OpenClaw config instance
openClawConfigInstance = null

getOpenClawConfig = ->
  unless openClawConfigInstance
    openClawConfigInstance = new OpenClawConfig()
  openClawConfigInstance

syncProvidersToOpenClaw = (providers, activeProvider, token) ->
  return false unless configExists()
  return false unless providers
  
  try
    config = getOpenClawConfig()
    
    # Check if sync is needed
    unless config.needsSync(providers, activeProvider, token)
      return false
    
    # Backup before writing
    backupOpenClawConfig()
    
    # Use OpenClawConfig class to sync
    # Create settings-like object for syncFromSettings
    settings =
      providers: providers
      activeProvider: activeProvider
      token: token
    
    config.syncFromSettings(settings)
    console.log 'Providers synced to OpenClaw config via OpenClawConfig class'
    return true
  catch e
    console.error 'Failed to sync providers to OpenClaw:', e
    return false

# Ensure OpenClaw config is in sync with CoffeeClaw settings
# Only syncs if CoffeeClaw settings are newer than OpenClaw config
# Called at startup to handle cases where settings were modified outside the app
ensureOpenClawConfig = ->
  settings = loadSettings()
  return unless settings.providers
  
  return unless configExists()
  return unless fs.existsSync(settingsFile)
  
  try
    openclawConfigMtime = fs.statSync(configFile).mtime.getTime()
    settingsMtime = fs.statSync(settingsFile).mtime.getTime()
    
    if settingsMtime > openclawConfigMtime
      console.log 'CoffeeClaw settings are newer than OpenClaw config, syncing...'
      syncProvidersToOpenClaw(settings.providers, settings.activeProvider, settings.token)
  catch e
    console.error 'Failed to ensure OpenClaw config:', e

ipcMain.handle 'save-settings', (event, newSettings) ->
  settings = loadSettings()
  for key, value of newSettings
    settings[key] = value
  saveSettings settings
  
  # When providers are saved in CoffeeClaw settings, also sync them to OpenClaw's config
  # This ensures the OpenClaw agent uses the same API keys configured in the UI
  if newSettings.providers
    activeProvider = newSettings.activeProvider or settings.activeProvider
    syncProvidersToOpenClaw(newSettings.providers, activeProvider, settings.token)
  
  true

ipcMain.handle 'get-license', ->
  getLicenseStatus()

ipcMain.handle 'get-license-prices', ->
  LICENSE_PRICES

ipcMain.handle 'activate-license', (event, plan, paymentInfo) ->
  license = loadLicense()
  
  license.paid = true
  license.plan = plan
  license.activatedAt = new Date().toISOString()
  
  if plan == 'lifetime'
    license.showIndicator = false
  else if plan == 'yearly'
    license.balance = (license.balance or 0) + 12
  else if plan == 'monthly'
    license.balance = (license.balance or 0) + 1
  
  license.paymentInfo = paymentInfo
  saveLicense license
  getLicenseStatus()

ipcMain.handle 'add-payment', (event, paymentData) ->
  try
    result = storage.addPayment(paymentData)
    result

ipcMain.handle 'get-models', ->
  MODELS

detectExistingFeishuConfig = ->
  try
    if fs.existsSync configFile
      config = JSON.parse fs.readFileSync configFile, 'utf8'
      if config.channels?.feishu?.enabled
        feishuChannel = config.channels.feishu
        if feishuChannel.appId
          return {
            enabled: true
            appId: feishuChannel.appId
            appSecret: feishuChannel.appSecret
            botName: feishuChannel.botName or 'CoffeeClaw'
            detected: true
          }
        else if feishuChannel.accounts?.main
          return {
            enabled: true
            appId: feishuChannel.accounts.main.appId
            appSecret: feishuChannel.accounts.main.appSecret
            botName: feishuChannel.accounts.main.botName or 'CoffeeClaw'
            detected: true
          }
  catch e
    console.error 'Error detecting Feishu config:', e
  null

syncFeishuConfigToSettings = ->
  existing = detectExistingFeishuConfig()
  if existing
    settings = loadSettings()
    if not settings.feishu?.appId
      settings.feishu = existing
      saveSettings settings
      console.log 'Synced existing Feishu config to settings'
    return existing
  null

syncFeishuConfigToOpenClaw = ->
  settings = loadSettings()
  if not settings.feishu?.appId or not settings.feishu?.enabled
    return false
  
  existing = detectExistingFeishuConfig()
  if existing?.enabled
    return true
  
  try
    config = {}
    if fs.existsSync configFile
      config = JSON.parse fs.readFileSync configFile, 'utf8'
    
    if config.channels?.feishu?.enabled and config.channels?.feishu?.appId
      return true
    
    config.channels ?= {}
    config.channels.feishu =
      enabled: true
      appId: settings.feishu.appId
      appSecret: settings.feishu.appSecret
      domain: 'feishu'
      dmPolicy: settings.feishu.dmPolicy or 'pairing'
      groupPolicy: settings.feishu.groupPolicy or 'open'
    
    config.plugins ?= {}
    config.plugins.entries ?= {}
    config.plugins.entries.feishu = { enabled: true }
    
    if settings.apiKey
      config.models ?= {}
      config.models.providers ?= {}
      config.models.providers.glm =
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4'
        apiKey: settings.apiKey
        api: 'openai-completions'
        models: [
          { id: 'GLM-4-Flash', name: 'GLM 4 Flash' }
          { id: 'GLM-4.5-air', name: 'GLM 4.5 Air' }
          { id: 'GLM-4.7', name: 'GLM 4.7' }
        ]
    
    fs.writeFileSync configFile, JSON.stringify(config, null, 2)
    console.log 'Synced Feishu config to OpenClaw'
    return true
  catch e
    console.error 'Error syncing Feishu to OpenClaw:', e
    return false

configureFeishu = (appId, appSecret, botName, enabled = true) ->
  settings = loadSettings()
  settings.feishu =
    appId: appId
    appSecret: appSecret
    botName: botName or 'CoffeeClaw'
    enabled: enabled
  saveSettings settings
  
  if configExists()
    config = JSON.parse fs.readFileSync configFile, 'utf8'
    config.plugins ?= {}
    config.plugins.feishu = { enabled: enabled }
    config.channels ?= {}
    config.channels.feishu =
      enabled: enabled
      dmPolicy: 'pairing'
      accounts:
        main:
          appId: appId
          appSecret: appSecret
          botName: botName or 'CoffeeClaw'
    
    if settings.apiKey
      config.models ?= {}
      config.models.providers ?= {}
      config.models.providers.glm =
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4'
        apiKey: settings.apiKey
        api: 'openai-completions'
        models: [
          { id: 'GLM-4-Flash', name: 'GLM 4 Flash' }
          { id: 'GLM-4.5-air', name: 'GLM 4.5 Air' }
          { id: 'GLM-4.7', name: 'GLM 4.7' }
        ]
    
    fs.writeFileSync configFile, JSON.stringify(config, null, 2)
  
  { success: true }

ipcMain.handle 'call-openclaw-agent', (event, sessionId, message) ->
  try
    result = await callOpenClawAgent sessionId, message
    return result
  catch e
    throw e.message or e

ipcMain.handle 'run-local-command', (event, command, cwd) ->
  new Promise (resolve, reject) ->
    exec command, { cwd: cwd or process.cwd(), maxBuffer: 1024 * 1024 }, (err, stdout, stderr) ->
      if err
        resolve { success: false, error: err.message, stdout: stdout, stderr: stderr }
      else
        resolve { success: true, stdout: stdout, stderr: stderr }
