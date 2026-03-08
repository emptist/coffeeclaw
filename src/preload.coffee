# CoffeeClaw - Preload Script
{ contextBridge, ipcRenderer } = require 'electron'

contextBridge.exposeInMainWorld 'api',
  sendMessage: (message) -> ipcRenderer.invoke 'send-message', message
  checkStatus: -> ipcRenderer.invoke 'check-status'
  runSetup: (apiKey) -> ipcRenderer.invoke 'run-setup', apiKey
  getSettings: -> ipcRenderer.invoke 'get-settings'
  saveApiKey: (apiKey) -> ipcRenderer.invoke 'save-api-key', apiKey
  getHistory: -> ipcRenderer.invoke 'get-history'
  clearHistory: -> ipcRenderer.invoke 'clear-history'
