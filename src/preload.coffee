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
  exportBots: -> ipcRenderer.invoke 'export-bots'
  importBots: (data) -> ipcRenderer.invoke 'import-bots', data
  getFeishuStatus: -> ipcRenderer.invoke 'get-feishu-status'
  syncFeishuToOpenClaw: -> ipcRenderer.invoke 'sync-feishu-to-openclaw'
  getLicense: -> ipcRenderer.invoke 'get-license'
  getLicensePrices: -> ipcRenderer.invoke 'get-license-prices'
  activateLicense: (plan, paymentInfo) -> ipcRenderer.invoke 'activate-license', plan, paymentInfo
  addPayment: (paymentData) -> ipcRenderer.invoke 'add-payment', paymentData
  getGitEmail: -> ipcRenderer.invoke 'get-git-email'
  backupSettings: -> ipcRenderer.invoke 'backup-settings'
  listBackups: -> ipcRenderer.invoke 'list-backups'
  restoreBackup: (backupName) -> ipcRenderer.invoke 'restore-backup', backupName
  exportAllSettings: -> ipcRenderer.invoke 'export-all-settings'
  importAllSettings: (data) -> ipcRenderer.invoke 'import-all-settings', data
