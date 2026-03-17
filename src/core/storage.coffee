# Storage Manager using electron-store
# Provides persistent storage with caching and dirty tracking

Store = require 'electron-store'
path = require 'path'
EventEmitter = require 'events'

class StorageManager extends EventEmitter
  @instance = null
  
  @getInstance: ->
    @instance ?= new StorageManager()
  
  constructor: ->
    super()
    @store = new Store
      name: 'coffeeclaw-data'
      cwd: path.join(path.dirname(__dirname), '..', '.secret')
      defaults:
        settings: null
        bots: null
        sessions: null
        license: null
        agentSessions: null
        identity: null
        agentModels: null
        backups: []
    
    @_cache = new Map()
    @_dirty = new Set()
  
  get: (key, defaultValue = null) ->
    if @_cache.has(key)
      return @_cache.get(key)
    
    data = @store.get(key)
    if data is undefined or data is null
      @_cache.set(key, defaultValue)
      return defaultValue
    
    @_cache.set(key, data)
    data
  
  set: (key, value) ->
    @_cache.set(key, value)
    @_dirty.add(key)
    @
  
  save: (key) ->
    return @ unless @_dirty.has(key)
    
    data = @_cache.get(key)
    
    try
      if data?.toJSON
        @store.set(key, data.toJSON())
      else
        @store.set(key, data)
      
      @_dirty.delete(key)
      @emit('saved', key, data)
    catch e
      console.error "Error saving #{key}:", e
      @emit('error', key, e)
    
    @
  
  saveAll: ->
    keysToSave = Array.from(@_dirty)
    for key in keysToSave
      @save(key)
    @
  
  delete: (key) ->
    @_cache.delete(key)
    @_dirty.delete(key)
    try
      @store.delete(key)
    catch e
      console.error "Error deleting #{key}:", e
    @
  
  clear: ->
    @_cache.clear()
    @_dirty.clear()
    try
      @store.clear()
    catch e
      console.error "Error clearing store:", e
    @
  
  has: (key) ->
    @store.has(key) or @_cache.has(key)
  
  getPath: ->
    @store.path
  
  getStore: ->
    @store
  
  isDirty: (key) ->
    if key
      @_dirty.has(key)
    else
      @_dirty.size > 0
  
  getDirtyKeys: ->
    Array.from(@_dirty)

module.exports = { StorageManager }
