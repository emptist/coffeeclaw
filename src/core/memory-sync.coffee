# MemorySync - Synchronizes memory files between OpenClaw and CoffeeClaw
# Provides bidirectional sync with conflict resolution

fs = require 'fs'
path = require 'path'
{ EventEmitter } = require 'events'

class MemorySync extends EventEmitter
  @instance = null
  
  @getInstance: (options = {}) ->
    @instance ?= new MemorySync(options)
  
  constructor: (options = {}) ->
    super()
    @openclawDir = options.openclawDir or path.join(process.env.HOME, '.openclaw')
    @coffeeclawDir = options.coffeeclawDir or path.join(@openclawDir, 'workspace', 'coffeeclaw')
    @openclawMemoryDir = path.join(@openclawDir, '.openclaw')
    @coffeeclawMemoryDir = path.join(@coffeeclawDir, '.openclaw')
    
    # Memory files to sync
    @memoryFiles = [
      'CONTEXT.md'
      'DECISIONS.md'
      'MEMORY.md'
      'PROGRESS.md'
      'PROJECT.md'
      'TODO.md'
    ]
    
    @watchers = {}
    @isSyncing = false
    @syncQueue = []
  
  # Initialize directories and start watching
  init: ->
    @ensureDirectories()
    @startWatching()
    @emit 'initialized'
  
  # Ensure all memory directories exist
  ensureDirectories: ->
    for dir in [@openclawMemoryDir, @coffeeclawMemoryDir]
      fs.mkdirSync(dir, recursive: true) unless fs.existsSync(dir)
    
    # Create default memory files if they don't exist
    for file in @memoryFiles
      for dir in [@openclawMemoryDir, @coffeeclawMemoryDir]
        filePath = path.join(dir, file)
        unless fs.existsSync(filePath)
          fs.writeFileSync(filePath, @getDefaultContent(file))
  
  # Get default content for memory files
  getDefaultContent: (filename) ->
    templates =
      'CONTEXT.md': '''# 上下文记忆

## 当前会话
（记录当前会话的上下文信息）

## 活跃项目
- 项目1: 描述...

## 待办事项
- [ ] 任务1
'''
      'DECISIONS.md': '''# 决策记录

## 关键决策
（记录重要的技术决策和理由）

## 待决策事项
- 事项1: 描述...
'''
      'MEMORY.md': '''# 项目记忆

## 关键信息
（记录项目的重要信息）

## 已知问题
（记录已知的问题和限制）

## 经验教训
（记录开发过程中的经验教训）
'''
      'PROGRESS.md': '''# 进度追踪

## 当前进度
- 阶段1: 完成度 X%

## 里程碑
- [ ] 里程碑1
- [x] 里程碑2

## 时间线
- YYYY-MM-DD: 事件描述
'''
      'PROJECT.md': '''# 项目概述

## 项目名称
coffeeclaw

## 概述
（请填写项目概述）

## 技术栈
- （请填写技术栈）

## 目录结构
```
（请填写目录结构）
```

## 关键模块
- （请填写关键模块）

## 开发指南
- 安装依赖：（请填写）
- 编译：（请填写）
- 测试：（请填写）
- 打包：（请填写）
'''
      'TODO.md': '''# 待办事项

## 高优先级
- [ ] 任务1

## 中优先级
- [ ] 任务2

## 低优先级
- [ ] 任务3

## 已完成
- [x] 已完成的任务
'''
    
    templates[filename] or "# #{filename.replace('.md', '')}\n\n"
  
  # Start watching memory files for changes
  startWatching: ->
    for file in @memoryFiles
      # Watch OpenClaw memory files
      openclawPath = path.join(@openclawMemoryDir, file)
      @watchFile(openclawPath, 'openclaw')
      
      # Watch CoffeeClaw memory files
      coffeeclawPath = path.join(@coffeeclawMemoryDir, file)
      @watchFile(coffeeclawPath, 'coffeeclaw')
  
  # Watch a specific file
  watchFile: (filePath, source) ->
    return if @watchers[filePath]
    
    try
      watcher = fs.watch filePath, (eventType) =>
        return if @isSyncing
        return unless eventType is 'change'
        
        # Debounce rapid changes
        clearTimeout(@watchers[filePath].timeout)
        @watchers[filePath].timeout = setTimeout =>
          @handleFileChange(filePath, source)
        , 100
      
      @watchers[filePath] = { watcher, timeout: null }
    catch e
      console.error "Failed to watch #{filePath}:", e.message
  
  # Handle file change event
  handleFileChange: (changedPath, source) ->
    filename = path.basename(changedPath)
    
    # Determine target path
    if source is 'openclaw'
      targetPath = path.join(@coffeeclawMemoryDir, filename)
      targetSource = 'coffeeclaw'
    else
      targetPath = path.join(@openclawMemoryDir, filename)
      targetSource = 'openclaw'
    
    # Queue sync operation
    @syncQueue.push
      source: changedPath
      target: targetPath
      filename: filename
      sourceType: source
    
    @processSyncQueue()
  
  # Process sync queue
  processSyncQueue: ->
    return if @isSyncing or @syncQueue.length is 0
    
    @isSyncing = true
    operation = @syncQueue.shift()
    
    try
      @syncFile(operation)
    catch e
      console.error "Sync error:", e
    finally
      @isSyncing = false
      @processSyncQueue() if @syncQueue.length > 0
  
  # Sync a single file with conflict resolution
  syncFile: (operation) ->
    { source, target, filename, sourceType } = operation
    
    # Check if files exist
    sourceExists = fs.existsSync(source)
    targetExists = fs.existsSync(target)
    
    unless sourceExists
      console.log "Source file doesn't exist: #{source}"
      return
    
    # Read source content
    sourceContent = fs.readFileSync(source, 'utf8')
    sourceMtime = fs.statSync(source).mtime
    
    if targetExists
      targetContent = fs.readFileSync(target, 'utf8')
      targetMtime = fs.statSync(target).mtime
      
      # If content is the same, no need to sync
      if sourceContent is targetContent
        return
      
      # Conflict resolution: use newer file
      if sourceMtime > targetMtime
        @writeFile(target, sourceContent)
        @emit 'synced', { filename, direction: "#{sourceType} -> #{if sourceType is 'openclaw' then 'coffeeclaw' else 'openclaw'}", method: 'timestamp' }
      else if targetMtime > sourceMtime
        # Target is newer, sync back to source
        @writeFile(source, targetContent)
        @emit 'synced', { filename, direction: "#{if sourceType is 'openclaw' then 'coffeeclaw' else 'openclaw'} -> #{sourceType}", method: 'timestamp' }
    else
      # Target doesn't exist, create it
      @writeFile(target, sourceContent)
      @emit 'synced', { filename, direction: "#{sourceType} -> #{if sourceType is 'openclaw' then 'coffeeclaw' else 'openclaw'}", method: 'create' }
  
  # Write file with error handling
  writeFile: (filePath, content) ->
    try
      fs.writeFileSync(filePath, content, 'utf8')
      true
    catch e
      console.error "Failed to write #{filePath}:", e.message
      false
  
  # Force sync all memory files
  forceSyncAll: ->
    results = []
    for file in @memoryFiles
      openclawPath = path.join(@openclawMemoryDir, file)
      coffeeclawPath = path.join(@coffeeclawMemoryDir, file)
      
      # Sync OpenClaw -> CoffeeClaw
      if fs.existsSync(openclawPath)
        content = fs.readFileSync(openclawPath, 'utf8')
        @writeFile(coffeeclawPath, content)
        results.push { file, direction: 'openclaw -> coffeeclaw', status: 'synced' }
    
    @emit 'forceSyncComplete', results
    results
  
  # Read memory file (prefer CoffeeClaw copy)
  readMemory: (filename) ->
    coffeeclawPath = path.join(@coffeeclawMemoryDir, filename)
    openclawPath = path.join(@openclawMemoryDir, filename)
    
    if fs.existsSync(coffeeclawPath)
      fs.readFileSync(coffeeclawPath, 'utf8')
    else if fs.existsSync(openclawPath)
      fs.readFileSync(openclawPath, 'utf8')
    else
      null
  
  # Write memory file (writes to both locations)
  writeMemory: (filename, content) ->
    coffeeclawPath = path.join(@coffeeclawMemoryDir, filename)
    openclawPath = path.join(@openclawMemoryDir, filename)
    
    @writeFile(coffeeclawPath, content)
    @writeFile(openclawPath, content)
    
    @emit 'memoryWritten', { filename }
  
  # Get all memory content
  getAllMemory: ->
    memory = {}
    for file in @memoryFiles
      content = @readMemory(file)
      memory[file] = content if content
    memory
  
  # Stop all watchers
  stop: ->
    for filePath, watcher of @watchers
      watcher.watcher?.close()
    @watchers = {}
    @emit 'stopped'

module.exports = { MemorySync }
