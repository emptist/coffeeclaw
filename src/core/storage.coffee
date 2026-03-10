# Storage Manager using electron-store
# Integrates with existing classes (Settings, Bot, Session, etc.)

Store = require 'electron-store'
path = require 'path'

class StorageManager
  @instance = null
  
  @getInstance: ->
    @instance ?= new StorageManager()
  
  constructor: ->
    @store = new Store
      name: 'coffeeclaw-data'
      cwd: path.join(path.dirname(__dirname), '.secrete')
      defaults:
        settings: null
        bots: null
        sessions: null
        license: null
        agentSessions: null
    
    @_cache = new Map()
    @_dirty = new Set()
  
  get: (key) ->
    if @_cache.has(key)
      return @_cache.get(key)
    
    data = @store.get(key)
    @_cache.set(key, data)
    data
  
  set: (key, value) ->
    @_cache.set(key, value)
    @_dirty.add(key)
    @
  
  save: (key) ->
    return @ unless @_dirty.has(key)
    
    data = @_cache.get(key)
    
    if data?.toJSON
      @store.set(key, data.toJSON())
    else
      @store.set(key, data)
    
    @_dirty.delete(key)
    @emit('saved', key)
    @
  
  saveAll: ->
    for key from @_dirty
      @save(key)
    @
  
  delete: (key) ->
    @_cache.delete(key)
    @_dirty.delete(key)
    @store.delete(key)
    @
  
  clear: ->
    @_cache.clear()
    @_dirty.clear()
    @store.clear()
    @
  
  has: (key) ->
    @store.has(key) or @_cache.has(key)
  
  getPath: ->
    @store.path

module.exports = { StorageManager }
