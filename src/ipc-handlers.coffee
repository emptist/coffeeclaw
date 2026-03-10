# IPC Handlers - Main process communication handlers
# Extracted from main.coffee for better organization

{ ipcMain, shell } = require 'electron'
{ exec, spawn } = require 'child_process'
fs = require 'fs'
path = require 'path'

class IPCHandlers
  constructor: (@dependencies) ->
    @storage = @dependencies.storage
    @settings = @dependencies.settings
    @bots = @dependencies.bots
    @sessions = @dependencies.sessions
    @license = @dependencies.license
    @identity = @dependencies.identity
    @agentSessions = @dependencies.agentSessions
    @openClaw = @dependencies.openClaw
    @feishu = @dependencies.feishu
    @backup = @dependencies.backup
    @secreteDir = @dependencies.secreteDir
    @settingsFile = @dependencies.settingsFile
  
  registerAll: ->
    @registerMessageHandlers()
    @registerStatusHandlers()
    @registerBotHandlers()
    @registerSessionHandlers()
    @registerSettingsHandlers()
    @registerLicenseHandlers()
    @registerFeishuHandlers()
    @registerAgentHandlers()
    @registerUtilityHandlers()
  
  registerMessageHandlers: ->
    ipcMain.handle 'send-message', async (event, sessionId, message) =>
      try
        result = await @openClaw.sendMessage(sessionId, message)
        return result
      catch e
        throw e.message or e
  
  registerStatusHandlers: ->
    ipcMain.handle 'check-status', async =>
      running = await @openClaw.checkRunning()
      configured = @openClaw.isConfigured()
      settings = @storage.getSettings()
      
      @openClaw.ensureConfig()
      
      if not running and configured
        @openClaw.start()
        return { running: false, starting: true, configured: true, hasApiKey: !!settings.apiKey }
      
      { running, starting: false, configured, hasApiKey: !!settings.apiKey }
    
    ipcMain.handle 'check-prerequisites', async =>
      platform: process.platform
      isWindows: process.platform == 'win32'
      isMac: process.platform == 'darwin'
      nodeInstalled: await @checkCommand('node --version')
      npmInstalled: await @checkCommand('npm --version')
      openclawInstalled: await @checkCommand('which openclaw')
      wslInstalled: if process.platform == 'win32' then await @checkCommand('wsl --list') else false
    
    ipcMain.handle 'has-backup', =>
      try
        if fs.existsSync @settingsFile
          return true
        files = fs.readdirSync(@secreteDir).filter (f) -> f.startsWith('backup.') and f.endsWith('.json')
        return files.length > 0
      catch
        false
  
  registerBotHandlers: ->
    ipcMain.handle 'get-bots', => @storage.getBots()
    ipcMain.handle 'get-bot', (event, botId) => @storage.getBot(botId)
    ipcMain.handle 'get-active-bot', => @storage.getActiveBot()
    ipcMain.handle 'create-bot', (event, botConfig) => @storage.createBot(botConfig)
    ipcMain.handle 'update-bot', (event, botId, updates) => @storage.updateBot(botId, updates)
    ipcMain.handle 'delete-bot', (event, botId) => @storage.deleteBot(botId)
    ipcMain.handle 'set-active-bot', (event, botId) => @storage.setActiveBot(botId)
    ipcMain.handle 'get-bot-templates', => @getBotTemplates()
    
    ipcMain.handle 'export-bots', =>
      try
        botsData = @storage.getBots()
        settings = @storage.getSettings()
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
    
    ipcMain.handle 'import-bots', (event, data) =>
      try
        unless data.bots and Array.isArray data.bots
          return { success: false, error: 'Invalid data: bots array required' }
        
        botsData = @storage.getBots()
        imported = 0
        
        for bot in data.bots
          if bot.id and bot.name
            existing = botsData.bots.find (b) -> b.id == bot.id
            if existing
              Object.assign existing, bot
            else
              botsData.bots.push bot
            imported++
        
        @storage.saveBots(botsData)
        
        if data.settings
          settings = @storage.getSettings()
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
          @storage.saveSettings(settings)
        
        { success: true, imported: imported, total: botsData.bots.length }
      catch e
        { success: false, error: e.message }
  
  registerSessionHandlers: ->
    ipcMain.handle 'create-session', => @storage.createSession()
    ipcMain.handle 'get-session', (event, sessionId) => @storage.getSession(sessionId)
    ipcMain.handle 'list-sessions', => @storage.listSessions()
    ipcMain.handle 'delete-session', (event, sessionId) =>
      @storage.deleteSession(sessionId)
      true
    ipcMain.handle 'get-history', => @storage.listSessions()
    ipcMain.handle 'clear-history', =>
      manager = @storage.getSessions()
      if manager?.clearAllSessions
        manager.clearAllSessions()
        @storage.saveSessions(manager)
      true
  
  registerSettingsHandlers: ->
    ipcMain.handle 'get-settings', => @storage.getSettings()
    
    ipcMain.handle 'save-settings', (event, newSettings) =>
      settings = @storage.getSettings()
      for key, value of newSettings
        settings[key] = value
      @storage.saveSettings(settings)
      
      if newSettings.providers
        activeProvider = newSettings.activeProvider or settings.activeProvider
        @openClaw.syncProviders(newSettings.providers, activeProvider, settings.token)
      
      true
    
    ipcMain.handle 'backup-settings', => @backup.create()
    ipcMain.handle 'list-backups', => @backup.list()
    ipcMain.handle 'restore-backup', (event, backupId, options) => @backup.restore(backupId, options)
    ipcMain.handle 'get-backup-data', (event, backupId) => @backup.get(backupId)
    ipcMain.handle 'export-all-settings', => @storage.exportAll()
    ipcMain.handle 'import-all-settings', (event, data, options) => @storage.importAll(data, options)
  
  registerLicenseHandlers: ->
    ipcMain.handle 'get-license', => @storage.getLicenseStatus()
    ipcMain.handle 'get-license-prices', => @dependencies.licensePrices
    
    ipcMain.handle 'activate-license', (event, plan, paymentInfo) =>
      license = @storage.getLicense()
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
      @storage.saveLicense(license)
      @storage.getLicenseStatus()
    
    ipcMain.handle 'add-payment', (event, paymentData) =>
      @storage.addPayment(paymentData)
    
    ipcMain.handle 'get-models', => @dependencies.models
  
  registerFeishuHandlers: ->
    ipcMain.handle 'get-feishu-status', =>
      settings = @storage.getSettings()
      existing = @feishu.detectExisting()
      {
        enabled: settings.feishu?.enabled or false
        configured: existing?.enabled or false
        appId: settings.feishu?.appId or null
      }
    
    ipcMain.handle 'sync-feishu-to-openclaw', => @feishu.syncToOpenClaw()
    
    ipcMain.handle 'approve-feishu-pairing', (event, code) =>
      new Promise (resolve) =>
        CODE_REGEX = /^[a-zA-Z0-9_-]{10,64}$/
        
        unless CODE_REGEX.test(code)
          return resolve { success: false, error: 'Invalid pairing code format' }
        
        child = spawn 'openclaw', ['pairing', 'approve', 'feishu', code]
        
        stdout = ''
        stderr = ''
        
        child.stdout.on 'data', (chunk) -> stdout += chunk.toString()
        child.stderr.on 'data', (chunk) -> stderr += chunk.toString()
        
        child.on 'error', (err) =>
          console.error 'Error approving pairing:', err
          resolve { success: false, error: err.message }
        
        child.on 'close', (code) =>
          if code is 0
            console.log 'Pairing approved:', stdout
            resolve { success: true, output: stdout }
          else
            console.error 'Pairing failed:', stderr
            resolve { success: false, error: "Exit code: #{code}" }
  
  registerAgentHandlers: ->
    ipcMain.handle 'get-agent-session', (event, sessionId) => @storage.getAgentSession(sessionId)
    ipcMain.handle 'list-agent-sessions', => @storage.listAgentSessions()
    
    ipcMain.handle 'call-openclaw-agent', (event, sessionId, message) =>
      @openClaw.callAgent(sessionId, message)
    
    ipcMain.handle 'run-local-command', (event, command, cwd) =>
      new Promise (resolve) =>
        child = exec command, { cwd: cwd or process.cwd() }, (err, stdout, stderr) =>
          if err
            resolve { success: false, error: err.message, stderr: stderr }
          else
            resolve { success: true, stdout: stdout, stderr: stderr }
  
  registerUtilityHandlers: ->
    ipcMain.handle 'open-external', (event, url) =>
      shell.openExternal url
    
    ipcMain.handle 'run-setup', async (event, apiKey) =>
      result =
        installing: false
        configuring: false
        starting: false
      
      installed = await @checkCommand('which openclaw')
      if not installed
        result.installing = true
        try
          await @installOpenClaw()
          result.installing = false
        catch e
          return { error: "Failed to install OpenClaw: #{e.message}" }
      
      result.configuring = true
      @openClaw.createDefaultConfig(apiKey)
      @identity.create()
      @openClaw.createAgentConfig(apiKey)
      result.configuring = false
      
      result.starting = true
      @openClaw.start()
      result.starting = false
      
      result.success = true
      result
  
  checkCommand: (cmd) ->
    new Promise (resolve) ->
      exec cmd, (err) ->
        resolve not err
  
  installOpenClaw: ->
    new Promise (resolve, reject) ->
      console.log 'Installing OpenClaw...'
      exec 'npm install -g openclaw', (err, stdout, stderr) ->
        if err
          console.error 'Install error:', stderr
          reject err
        else
          console.log 'OpenClaw installed successfully'
          resolve true
  
  getBotTemplates: ->
    [
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

module.exports = { IPCHandlers }
