# CoffeeClaw - Main Process
# Auto-configures OpenClaw on first run

{ app, BrowserWindow, ipcMain, shell } = require 'electron'
path = require 'path'
fs = require 'fs'
http = require 'http'
https = require 'https'
{ exec, spawn } = require 'child_process'
crypto = require 'crypto'

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

loadSettings = ->
  try
    if fs.existsSync settingsFile
      data = fs.readFileSync settingsFile, 'utf8'
      settings = JSON.parse data
      if settings.token and settings.apiKey
        return settings
  catch e
    console.error 'Error loading settings:', e
  {}

saveSettings = (settings) ->
  try
    fs.mkdirSync secreteDir, { recursive: true }
    fs.writeFileSync settingsFile, JSON.stringify(settings, null, 2)
  catch e
    console.error 'Error saving settings:', e

backupSettings = ->
  try
    timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    backupFile = path.join secreteDir, "backup.#{timestamp}.json"
    
    backupData =
      version: '1.0'
      backedUpAt: new Date().toISOString()
      settings: if fs.existsSync(settingsFile) then JSON.parse(fs.readFileSync settingsFile, 'utf8') else {}
      sessions: if fs.existsSync(sessionsFile) then JSON.parse(fs.readFileSync sessionsFile, 'utf8') else { sessions: [] }
      bots: loadBots()
      license: loadLicense()
    
    fs.writeFileSync backupFile, JSON.stringify(backupData, null, 2)
    
    backups = fs.readdirSync(secreteDir)
      .filter (f) -> f.startsWith('backup.') and f.endsWith('.json') and f isnt 'bots.json'
      .sort()
      .reverse()
    
    for backup, i in backups when i >= 5
      fs.unlinkSync path.join(secreteDir, backup)
    
    console.log "Full backup created: #{backupFile}"
    true
  catch e
    console.error 'Error backing up:', e
    false

restoreSettings = (backupName, options = {}) ->
  try
    backupPath = path.join secreteDir, backupName
    if fs.existsSync backupPath
      data = JSON.parse fs.readFileSync backupPath, 'utf8'
      
      restoreSettings = if options.settings? then options.settings else true
      restoreSessions = if options.sessions? then options.sessions else true
      restoreBots = if options.bots? then options.bots else true
      restoreLicense = if options.license? then options.license else true
      
      if data.settings and restoreSettings
        fs.writeFileSync settingsFile, JSON.stringify(data.settings, null, 2)
      if data.sessions and restoreSessions
        fs.writeFileSync sessionsFile, JSON.stringify(data.sessions, null, 2)
      if data.bots and restoreBots
        fs.writeFileSync botsFile, JSON.stringify(data.bots, null, 2)
      if data.license and restoreLicense
        fs.writeFileSync licenseFile, JSON.stringify(data.license, null, 2)
      
      console.log "Backup restored from: #{backupName}"
      return true
    false
  catch e
    console.error 'Error restoring backup:', e
    false

getBackupData = (backupName) ->
  try
    backupPath = path.join secreteDir, backupName
    if fs.existsSync backupPath
      JSON.parse fs.readFileSync backupPath, 'utf8'
    else
      null
  catch e
    console.error 'Error reading backup:', e
    null

listSettingsBackups = ->
  try
    fs.readdirSync(secreteDir)
      .filter (f) -> f.startsWith('backup.') and f.endsWith('.json') and f isnt 'bots.json'
      .sort()
      .reverse()
  catch
    []

exportAllSettings = ->
  try
    settings = loadSettings()
    sessions = if fs.existsSync sessionsFile then JSON.parse(fs.readFileSync sessionsFile, 'utf8') else { sessions: [] }
    bots = loadBots()
    license = loadLicense()
    
    exportData =
      version: '1.0'
      exportedAt: new Date().toISOString()
      settings: settings
      sessions: sessions
      bots: bots
      license: license
    
    exportData
  catch e
    console.error 'Error exporting settings:', e
    null

importAllSettings = (data, options = {}) ->
  try
    importSettings = if options.settings? then options.settings else true
    importSessions = if options.sessions? then options.sessions else true
    importBots = if options.bots? then options.bots else true
    importLicense = if options.license? then options.license else true
    
    if data.settings and importSettings
      saveSettings data.settings
    if data.sessions and importSessions
      fs.writeFileSync sessionsFile, JSON.stringify(data.sessions, null, 2)
    if data.bots and importBots
      fs.writeFileSync botsFile, JSON.stringify(data.bots, null, 2)
    if data.license and importLicense
      saveLicense data.license
    true
  catch e
    console.error 'Error importing settings:', e
    false

loadLicense = ->
  try
    if fs.existsSync licenseFile
      data = fs.readFileSync licenseFile, 'utf8'
      return JSON.parse data
  catch e
    console.error 'Error loading license:', e
  null

saveLicense = (license) ->
  try
    fs.mkdirSync secreteDir, { recursive: true }
    fs.writeFileSync licenseFile, JSON.stringify(license, null, 2)
  catch e
    console.error 'Error saving license:', e

initLicense = ->
  license = loadLicense()
  if license
    return license
  
  newLicense =
    deviceId: generateId()
    createdAt: new Date().toISOString()
    balance: INITIAL_BALANCE_USD
    currency: 'usd'
    paid: false
    plan: null
    lastDeduction: null
  
  saveLicense newLicense
  newLicense

getLicenseStatus = ->
  license = loadLicense()
  unless license
    license = initLicense()
  
  if license.paid and license.plan == 'lifetime'
    return
      status: 'lifetime'
      balance: 0
      paid: true
      plan: 'lifetime'
      showIndicator: false
  
  unless license.balance?
    license.balance = INITIAL_BALANCE_USD
    saveLicense(license)
  
  currentBalance = license.balance
  
  now = new Date()
  createdAt = new Date(license.createdAt)
  
  monthsSinceCreation = (now.getFullYear() - createdAt.getFullYear()) * 12 + (now.getMonth() - createdAt.getMonth())
  
  if license.lastDeduction
    lastDeduction = new Date(license.lastDeduction)
    monthsSinceLastDeduction = (now.getFullYear() - lastDeduction.getFullYear()) * 12 + (now.getMonth() - lastDeduction.getMonth())
  else
    monthsSinceLastDeduction = monthsSinceCreation
  
  if monthsSinceLastDeduction >= 1
    deduction = Math.floor(monthsSinceLastDeduction)
    currentBalance = license.balance - deduction
    
    if currentBalance != license.balance
      license.balance = currentBalance
      license.lastDeduction = now.toISOString()
      saveLicense(license)
  
  return
    status: if currentBalance > 0 then 'active' else 'overdue'
    balance: currentBalance
    paid: license.paid
    plan: license.plan
    showIndicator: true
    currency: license.currency or 'usd'

loadSessions = ->
  try
    if fs.existsSync sessionsFile
      data = fs.readFileSync sessionsFile, 'utf8'
      return JSON.parse data
  catch e
    console.error 'Error loading sessions:', e
  {}

saveSessions = (sessions) ->
  try
    fs.mkdirSync secreteDir, { recursive: true }
    fs.writeFileSync sessionsFile, JSON.stringify(sessions, null, 2)
  catch e
    console.error 'Error saving sessions:', e

getSession = (sessionId) ->
  sessions = loadSessions()
  sessions[sessionId] or { id: sessionId, messages: [], createdAt: Date.now() }

saveSession = (sessionId, session) ->
  sessions = loadSessions()
  session.messages = session.messages.slice -MAX_HISTORY
  sessions[sessionId] = session
  sessionIds = Object.keys(sessions)
  if sessionIds.length > MAX_SESSIONS
    oldest = sessionIds.sort((a, b) -> sessions[a].createdAt - sessions[b].createdAt)[0]
    delete sessions[oldest]
  saveSessions sessions

addToSession = (sessionId, role, content) ->
  session = getSession sessionId
  unless session.messages
    session.messages = []
  session.messages.push
    role: role
    content: content
    timestamp: Date.now()
  if not session.title and role == 'user'
    session.title = content.substring(0, 50)
  unless session.createdAt
    session.createdAt = Date.now()
  session.updatedAt = Date.now()
  saveSession sessionId, session
  session

createSession = ->
  sessionId = generateId()
  session =
    id: sessionId
    title: ''
    messages: []
    createdAt: Date.now()
    updatedAt: Date.now()
  saveSession sessionId, session
  session

loadAgentSessions = ->
  try
    if fs.existsSync agentSessionsFile
      data = fs.readFileSync agentSessionsFile, 'utf8'
      return JSON.parse data
  catch e
    console.error 'Error loading agent sessions:', e
  {}

saveAgentSessions = (sessions) ->
  try
    fs.mkdirSync secreteDir, { recursive: true }
    fs.writeFileSync agentSessionsFile, JSON.stringify(sessions, null, 2)
  catch e
    console.error 'Error saving agent sessions:', e

getAgentSession = (sessionId) ->
  sessions = loadAgentSessions()
  sessions[sessionId] or { id: sessionId, messages: [], openclawSessionId: sessionId, createdAt: Date.now() }

addToAgentSession = (sessionId, role, content) ->
  sessions = loadAgentSessions()
  session = sessions[sessionId] or { id: sessionId, messages: [], openclawSessionId: sessionId }
  session.messages.push
    role: role
    content: content
    timestamp: Date.now()
    source: 'openclaw-agent'
  if not session.title and role == 'user'
    session.title = content.substring(0, 50)
  unless session.createdAt
    session.createdAt = Date.now()
  session.updatedAt = Date.now()
  sessions[sessionId] = session
  saveAgentSessions sessions
  session

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

loadBots = ->
  try
    if fs.existsSync botsFile
      data = fs.readFileSync botsFile, 'utf8'
      return JSON.parse data
  catch e
    console.error 'Error loading bots:', e
  {
    bots: [
      id: 'default'
      name: 'General Assistant'
      description: 'A helpful general-purpose assistant'
      model: 'glm-4-flash'
      systemPrompt: 'You are a helpful assistant. Be concise and helpful.'
      skills: ['*']
      enabled: true
      createdAt: new Date().toISOString()
    ]
    activeBotId: 'default'
  }

saveBots = (botsData) ->
  try
    fs.mkdirSync secreteDir, { recursive: true }
    fs.writeFileSync botsFile, JSON.stringify(botsData, null, 2)
  catch e
    console.error 'Error saving bots:', e

getBot = (botId) ->
  botsData = loadBots()
  botsData.bots.find (b) -> b.id == botId

getActiveBot = ->
  botsData = loadBots()
  activeBot = botsData.bots.find (b) -> b.id == botsData.activeBotId
  activeBot or botsData.bots[0]

createBot = (botConfig) ->
  unless botConfig.name?.trim()
    return error: 'Bot name is required'
  botsData = loadBots()
  newBot =
    id: generateId()
    name: botConfig.name.trim()
    description: botConfig.description?.trim() or ''
    model: botConfig.model or 'glm-4-flash'
    systemPrompt: botConfig.systemPrompt or 'You are a helpful assistant.'
    skills: botConfig.skills or ['*']
    enabled: true
    createdAt: new Date().toISOString()
  if botConfig.isAgent
    newBot.isAgent = true
  botsData.bots.push newBot
  saveBots botsData
  newBot

updateBot = (botId, updates) ->
  botsData = loadBots()
  botIndex = botsData.bots.findIndex (b) -> b.id == botId
  if botIndex >= 0
    botsData.bots[botIndex] = { ...botsData.bots[botIndex], ...updates, updatedAt: new Date().toISOString() }
    saveBots botsData
    return botsData.bots[botIndex]
  null

deleteBot = (botId) ->
  botsData = loadBots()
  if botsData.bots.length <= 1
    return { success: false, error: 'Cannot delete the last bot' }
  botsData.bots = botsData.bots.filter (b) -> b.id != botId
  if botsData.activeBotId == botId
    botsData.activeBotId = botsData.bots[0]?.id
  saveBots botsData
  { success: true }

setActiveBot = (botId) ->
  botsData = loadBots()
  bot = botsData.bots.find (b) -> b.id == botId
  if bot
    botsData.activeBotId = botId
    saveBots botsData
    return bot
  null

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
          content = fs.readFileSync args.path, 'utf8'
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
  sessions = loadSessions()
  result = []
  for key, session of sessions
    result.push session
  result.sort (a, b) -> (b.updatedAt or 0) - (a.updatedAt or 0)
  result

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
          primary: 'glm/GLM-4-Flash'
        models:
          'glm/GLM-4-Flash': {}
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

createIdentity = ->
  return if fs.existsSync identityFile
  
  console.log 'Creating identity...'
  identity = """# IDENTITY.md - Who Am I?

- **Name:** CoffeeClaw
- **Creature:** AI Assistant
- **Vibe:** helpful and friendly
- **Emoji:** ☕

I am a desktop AI assistant powered by OpenClaw and Zhipu GLM models.
I can help you with various tasks and answer your questions.
"""
  
  fs.writeFileSync identityFile, identity
  console.log 'Identity created at:', identityFile

createAgentConfig = (apiKey) ->
  key = apiKey or ''
  
  agentModels =
    providers: {}
  
  if key
    agentModels.providers.glm =
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4'
      apiKey: key
      api: 'openai-completions'
      models: [
        id: 'GLM-4-Flash'
        name: 'GLM 4 Flash'
        reasoning: false
        input: ['text']
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
        contextWindow: 200000
        maxTokens: 8192
        api: 'openai-completions'
      ]
  
  fs.writeFileSync agentModelsFile, JSON.stringify(agentModels, null, 2)
  
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
      { id: 'glm-4-flash', name: 'GLM-4-Flash (Free)', free: true }
      { id: 'glm-4-plus', name: 'GLM-4-Plus' }
      { id: 'glm-4-air', name: 'GLM-4-Air' }
    ]
    baseUrl: 'open.bigmodel.cn'
    apiPath: '/api/paas/v4/chat/completions'
  openrouter:
    name: 'OpenRouter'
    models: [
      { id: 'openrouter/auto', name: 'Auto (Best Free)', free: true }
      { id: 'google/gemini-2.0-flash-001', name: 'Gemini 2.0 Flash', free: true }
      { id: 'meta-llama/llama-3.3-70b-instruct', name: 'Llama 3.3 70B', free: true }
      { id: 'deepseek/deepseek-chat', name: 'DeepSeek Chat', free: true }
    ]
    baseUrl: 'openrouter.ai'
    apiPath: '/api/v1/chat/completions'
  openai:
    name: 'OpenAI'
    models: [
      { id: 'gpt-4o-mini', name: 'GPT-4o Mini' }
      { id: 'gpt-4o', name: 'GPT-4o' }
      { id: 'gpt-4-turbo', name: 'GPT-4 Turbo' }
    ]
    baseUrl: 'api.openai.com'
    apiPath: '/v1/chat/completions'
  deepseek:
    name: 'DeepSeek'
    models: [
      { id: 'deepseek-chat', name: 'DeepSeek Chat' }
      { id: 'deepseek-coder', name: 'DeepSeek Coder' }
    ]
    baseUrl: 'api.deepseek.com'
    apiPath: '/v1/chat/completions'

callOpenClawAgent = (sessionId, message) ->
  new Promise (resolve, reject) ->
    cmd = "openclaw agent --local --session-id \"#{sessionId}\" --message #{JSON.stringify(message)} --json 2>/dev/null"
    exec cmd, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout, stderr) ->
      if err
        console.error 'OpenClaw Agent error:', err
        reject new Error(err.message)
        return
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

callAPI = (sessionId, message, settings, bot = null) ->
  model = bot?.model or settings.model or 'glm-4-flash'
  
  if model == 'openclaw-agent' or bot?.isAgent
    return await callOpenClawAgent(sessionId, message)
  
  new Promise (resolve, reject) ->
    provider = settings.activeProvider or settings.provider or 'zhipu'
    
    if settings.providers and settings.providers[provider]
      providerConfig = settings.providers[provider]
      apiKey = providerConfig.apiKey
      model = bot?.model or providerConfig.model or 'glm-4-flash'
    else
      apiKey = settings.apiKey
      model = bot?.model or settings.model or 'glm-4-flash'
    
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
      model = bot?.model or providerConfig.model or 'glm-4-flash'
    else
      model = bot?.model or settings.model or 'glm-4-flash'
    
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
      return false
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
  new Promise (resolve) ->
    exec "openclaw pairing approve feishu #{code}", (err, stdout, stderr) ->
      if err
        console.error 'Error approving pairing:', err
        resolve { success: false, error: err.message }
      else
        console.log 'Pairing approved:', stdout
        resolve { success: true, output: stdout }

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
  loadAgentSessions()

ipcMain.handle 'get-history', ->
  listSessions()

ipcMain.handle 'clear-history', ->
  sessions = loadSessions()
  for key of sessions
    delete sessions[key]
  saveSessions sessions
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
backupOpenClawConfig = ->
  return unless configExists()
  
  try
    timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    backupPath = "#{configFile}.backup.#{timestamp}"
    fs.copyFileSync configFile, backupPath
    console.log "Backed up OpenClaw config to: #{backupPath}"
    
    # Keep only last 5 backups
    backups = fs.readdirSync(path.dirname(configFile))
      .filter (f) -> f.startsWith('openclaw.json.backup.')
      .sort()
      .reverse()
    
    for oldBackup in backups[5...]
      fs.unlinkSync(path.join(path.dirname(configFile), oldBackup))
      console.log "Cleaned up old backup: #{oldBackup}"
  catch e
    console.error 'Failed to backup OpenClaw config:', e

# Sync providers from CoffeeClaw settings to OpenClaw's config file
# This ensures the OpenClaw agent uses the same API keys as the CoffeeClaw UI
# Returns true if sync was performed, false otherwise
syncProvidersToOpenClaw = (providers, activeProvider) ->
  return false unless configExists()
  return false unless providers
  
  # Check if there's actually something to sync
  try
    existingConfig = JSON.parse fs.readFileSync configFile, 'utf8'
    existingConfig.models ?= {}
    existingConfig.models.providers ?= {}
    
    # Check if any provider actually changed OR if active provider changed
    needsSync = false
    for providerId, providerData of providers
      openClawProviderName = PROVIDER_NAME_MAP[providerId]
      continue unless openClawProviderName
      
      existing = existingConfig.models.providers[openClawProviderName]
      if not existing or existing.apiKey isnt providerData.apiKey
        needsSync = true
        break
    
    # Also check if active provider changed
    if activeProvider
      openClawProviderName = PROVIDER_NAME_MAP[activeProvider]
      if openClawProviderName
        currentPrimary = existingConfig.agents?.defaults?.model?.primary
        newPrimary = "#{openClawProviderName}/#{providers[activeProvider]?.model}"
        if currentPrimary isnt newPrimary
          needsSync = true
    
    return false unless needsSync
    
    # Backup before writing
    backupOpenClawConfig()
    
    # Perform the sync
    config = existingConfig
    config.models ?= {}
    config.models.providers ?= {}
    
    for providerId, providerData of providers
      openClawProviderName = PROVIDER_NAME_MAP[providerId]
      continue unless openClawProviderName
      
      openClawConfig = getOpenClawProviderConfig(providerId, providerData.apiKey)
      continue unless openClawConfig
      
      config.models.providers[openClawProviderName] = openClawConfig
      console.log "Synced provider #{providerId} → #{openClawProviderName} to openclaw.json"
    
    # Update primary model to match active provider
    # Note: OpenClaw uses agents.defaults.model.primary, format: "provider/modelId"
    # e.g., "glm/GLM-4-Flash" or "openrouter/auto"
    if providers and activeProvider and PROVIDER_NAME_MAP[activeProvider]
      openClawProvider = PROVIDER_NAME_MAP[activeProvider]
      providerData = providers[activeProvider]
      if providerData and providerData.model
        # For openrouter models, the id might be "openrouter/auto" so we use it directly
        # For others like glm, it's "glm-4-flash" so we format as "provider/model"
        modelId = providerData.model
        unless modelId.startsWith(openClawProvider)
          modelId = "#{openClawProvider}/#{modelId}"
        config.agents ?= {}
        config.agents.defaults ?= {}
        config.agents.defaults.model ?= {}
        config.agents.defaults.model.primary = modelId
        console.log "Set primary model to: #{modelId}"
    
    fs.writeFileSync configFile, JSON.stringify(config, null, 2)
    console.log 'Providers synced to OpenClaw config'
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
      syncProvidersToOpenClaw(settings.providers, settings.activeProvider)
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
    syncProvidersToOpenClaw(newSettings.providers, activeProvider)
  
  true

ipcMain.handle 'get-license', ->
  getLicenseStatus()

ipcMain.handle 'get-license-prices', ->
  LICENSE_PRICES

ipcMain.handle 'activate-license', (event, plan, paymentInfo) ->
  license = loadLicense()
  unless license
    license = initLicense()
  
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
    license = loadLicense()
    unless license
      license = initLicense()
    
    { amount, method, email, currency } = paymentData
    
    unless amount and amount > 0
      return { success: false, error: 'Invalid amount' }
    
    currency = currency or 'usd'
    
    unless license.currency
      license.currency = currency
    
    if license.currency != currency
      return { success: false, error: "Currency mismatch. Your account uses #{license.currency}" }
    
    license.balance = (license.balance or 0) + amount
    license.paid = true
    
    lifetimeThreshold = if currency == 'cny' then 216 else 36
    if amount >= lifetimeThreshold
      license.plan = 'lifetime'
    
    license.paymentInfo = license.paymentInfo or []
    license.paymentInfo.push {
      amount: amount
      method: method
      email: email
      currency: currency
      timestamp: new Date().toISOString()
    }
    
    saveLicense license
    { success: true, balance: license.balance }
  catch e
    console.error 'Error adding payment:', e
    { success: false, error: e.message }

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
