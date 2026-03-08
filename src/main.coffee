# CoffeeClaw - Main Process
# Auto-configures OpenClaw on first run

{ app, BrowserWindow, ipcMain } = require 'electron'
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

callZhipuAPI = (sessionId, message, apiKey) ->
  new Promise (resolve, reject) ->
    session = getSession sessionId
    messages = [
      { role: 'system', content: 'You are CoffeeClaw, a helpful AI assistant. Respond in the same language the user uses. Be friendly and helpful.' }
    ]
    
    if session.messages
      for msg in session.messages
        messages.push
          role: msg.role
          content: msg.content
    
    messages.push
      role: 'user'
      content: message
    
    postData = JSON.stringify
      model: 'glm-4-flash'
      messages: messages
      stream: false

    options =
      hostname: 'open.bigmodel.cn'
      port: 443
      path: '/api/paas/v4/chat/completions'
      method: 'POST'
      headers:
        'Content-Type': 'application/json'
        'Authorization': "Bearer #{apiKey}"
        'Content-Length': Buffer.byteLength(postData)

    req = https.request options, (res) ->
      data = ''
      res.on 'data', (chunk) -> data += chunk
      res.on 'end', ->
        try
          result = JSON.parse data
          if result.error
            reject new Error result.error.message or 'API error'
          else if result.choices and result.choices[0]
            resolve result.choices[0].message.content
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
  
  addToSession sessionId, 'user', message
  response = await callZhipuAPI sessionId, message, apiKey
  addToSession sessionId, 'assistant', response
  response

mainWindow = null

createWindow = ->
  mainWindow = new BrowserWindow
    width: 900
    height: 800
    minWidth: 600
    minHeight: 600
    webPreferences:
      nodeIntegration: false
      contextIsolation: true
      preload: path.join __dirname, 'preload.js'
  
  mainWindow.loadFile 'index.html'
  
  mainWindow.on 'closed', ->
    mainWindow = null

app.whenReady().then ->
  createWindow()

  app.on 'activate', ->
    if BrowserWindow.getAllWindows().length == 0
      createWindow()

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

ipcMain.handle 'create-session', ->
  createSession()

ipcMain.handle 'get-session', (event, sessionId) ->
  getSession sessionId

ipcMain.handle 'list-sessions', ->
  listSessions()

ipcMain.handle 'delete-session', (event, sessionId) ->
  deleteSession sessionId
  true

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

ipcMain.handle 'save-api-key', (event, apiKey) ->
  settings = loadSettings()
  settings.apiKey = apiKey
  saveSettings settings
  
  if configExists()
    config = JSON.parse fs.readFileSync configFile, 'utf8'
    config.env ?= {}
    config.env.ZHIPU_API_KEY = apiKey
    config.models ?= {}
    config.models.providers ?= {}
    config.models.providers.glm =
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4'
      apiKey: apiKey
      api: 'openai-completions'
      models: [
        { id: 'GLM-4-Flash', name: 'GLM 4 Flash' }
        { id: 'GLM-4.5-air', name: 'GLM 4.5 air' }
        { id: 'GLM-4.7', name: 'GLM 4.7' }
      ]
    fs.writeFileSync configFile, JSON.stringify(config, null, 2)
    
    createAgentConfig apiKey
  
  true
