# CoffeeClaw - Preload Script
{ contextBridge, ipcRenderer } = require 'electron'

contextBridge.exposeInMainWorld 'api',
  sendMessage: (sessionId, message) -> ipcRenderer.invoke 'send-message', sessionId, message
  checkStatus: -> ipcRenderer.invoke 'check-status'
  checkPrerequisites: -> ipcRenderer.invoke 'check-prerequisites'
  runSetup: (apiKey) -> ipcRenderer.invoke 'run-setup', apiKey
  getSettings: -> ipcRenderer.invoke 'get-settings'
  saveSettings: (settings) -> ipcRenderer.invoke 'save-settings', settings
  saveApiKey: (apiKey) -> ipcRenderer.invoke 'save-api-key', apiKey
  getModels: -> ipcRenderer.invoke 'get-models'
  createSession: -> ipcRenderer.invoke 'create-session'
  getSession: (sessionId) -> ipcRenderer.invoke 'get-session', sessionId
  listSessions: -> ipcRenderer.invoke 'list-sessions'
  deleteSession: (sessionId) -> ipcRenderer.invoke 'delete-session', sessionId
  getHistory: -> ipcRenderer.invoke 'get-history'
  clearHistory: -> ipcRenderer.invoke 'clear-history'
  getBots: -> ipcRenderer.invoke 'get-bots'
  getBot: (botId) -> ipcRenderer.invoke 'get-bot', botId
  getActiveBot: -> ipcRenderer.invoke 'get-active-bot'
  createBot: (botConfig) -> ipcRenderer.invoke 'create-bot', botConfig
  updateBot: (botId, updates) -> ipcRenderer.invoke 'update-bot', botId, updates
  deleteBot: (botId) -> ipcRenderer.invoke 'delete-bot', botId
  setActiveBot: (botId) -> ipcRenderer.invoke 'set-active-bot', botId
  getBotTemplates: -> ipcRenderer.invoke 'get-bot-templates'
