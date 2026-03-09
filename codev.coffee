# CoffeeClaw Development TUI
# 
# A terminal-based collaboration tool for OpenClaw Agent and Trae AI.
# This enables real-time collaboration on CoffeeClaw development.
#
# Features:
# - Send messages to OpenClaw Agent
# - Real-time session file monitoring
# - Trae AI review integration via .codev/review.md
# - Task management
#
# Collaboration Flow:
# 1. User sends message via TUI
# 2. OpenClaw Agent processes and writes to JSONL session
# 3. Trae AI reads session and writes suggestions to review.md
# 4. TUI displays both agent responses and Trae AI reviews
#
# Run: coffee codev.coffee
# Watch mode: coffee -w codev.coffee

{ exec, spawn } = require 'child_process'
fs = require 'fs'
path = require 'path'
readline = require 'readline'

CONFIG =
  sessionId: 'codev-' + Date.now()
  projectDir: process.cwd()
  openclawDir: path.join process.env.HOME, '.openclaw'
  sessionsDir: path.join process.env.HOME, '.openclaw/agents/main/sessions'
  codevDir: path.join process.cwd(), '.codev'

SESSION_FILE = path.join CONFIG.sessionsDir, "#{CONFIG.sessionId}.jsonl"
REVIEW_FILE = path.join CONFIG.codevDir, 'review.md'
TASKS_FILE = path.join CONFIG.codevDir, 'tasks.md'

state =
  lastEventCount: 0
  lastReviewMtime: 0

ensureCodevDir = ->
  unless fs.existsSync CONFIG.codevDir
    fs.mkdirSync CONFIG.codevDir, { recursive: true }

initFiles = ->
  ensureCodevDir()
  fs.writeFileSync REVIEW_FILE, "# Trae AI Review\n\nWaiting for activity...\n" unless fs.existsSync REVIEW_FILE
  fs.writeFileSync TASKS_FILE, "# Tasks\n\n- [ ] Start collaboration\n" unless fs.existsSync TASKS_FILE

clearScreen = ->
  process.stdout.write '\x1b[2J\x1b[H'

printHeader = ->
  console.log """
  ┌─────────────────────────────────────────────────────────────┐
  │  🦞 Codev TUI - OpenClaw Agent + Trae AI Collaboration     │
  ├─────────────────────────────────────────────────────────────┤
  │  Session: #{CONFIG.sessionId.substring(0, 48).padEnd(48)}│
  │  Project: #{CONFIG.projectDir.substring(0, 48).padEnd(48)}│
  └─────────────────────────────────────────────────────────────┘
  """

printHelp = ->
  console.log """
  
  Commands:
    <message>            Send message to OpenClaw Agent
    /task <desc>         Add a task
    /tasks               Show tasks
    /review              Show Trae AI review
    /history             Show session history
    /watch               Toggle file watching
    /clear               Clear screen
    /exit                Exit
  
  """

callAgent = (message) ->
  new Promise (resolve, reject) ->
    cmd = "openclaw agent --local --session-id \"#{CONFIG.sessionId}\" --message #{JSON.stringify(message)} --json 2>/dev/null"
    exec cmd, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout, stderr) ->
      if err
        reject new Error(err.message)
        return
      try
        resolve JSON.parse stdout
      catch e
        resolve { raw: stdout }

readSessionEvents = ->
  return [] unless fs.existsSync SESSION_FILE
  lines = fs.readFileSync(SESSION_FILE, 'utf8').split('\n').filter(Boolean)
  events = []
  for line in lines
    try
      events.push JSON.parse(line)
    catch e
      continue
  events

formatEvent = (event) ->
  switch event.type
    when 'message'
      role = event.message?.role or 'unknown'
      content = event.message?.content?[0]?.text or ''
      content = content.substring(0, 80) + '...' if content.length > 80
      icon = if role is 'user' then '👤' else '🤖'
      "#{icon} #{role}: #{content}"
    when 'tool_call'
      tool = event.tool or 'unknown'
      "🔧 #{tool}"
    when 'tool_result'
      "✅ tool result"
    else
      null

showHistory = ->
  events = readSessionEvents()
  console.log "\n📜 History (#{events.length} events):\n"
  for e in events
    formatted = formatEvent e
    console.log "  #{formatted}" if formatted
  console.log ""

showTasks = ->
  content = fs.readFileSync TASKS_FILE, 'utf8'
  console.log "\n📋 Tasks:\n"
  console.log content

addTask = (desc) ->
  ensureCodevDir()
  content = fs.readFileSync TASKS_FILE, 'utf8'
  lines = content.split('\n')
  lines.push "- [ ] #{desc}"
  fs.writeFileSync TASKS_FILE, lines.join('\n')
  console.log "\n✅ Added: #{desc}\n"

showReview = ->
  content = fs.readFileSync REVIEW_FILE, 'utf8'
  console.log "\n🧠 Trae AI Review:\n"
  console.log content

updateReview = (events) ->
  toolCalls = events.filter (e) -> e.type is 'tool_call'
  messages = events.filter (e) -> e.type is 'message' and e.message?.role is 'assistant'
  
  review = "# Trae AI Review\n\n"
  review += "## Session: #{CONFIG.sessionId}\n\n"
  
  if toolCalls.length > 0
    review += "### Tool Calls (#{toolCalls.length})\n\n"
    for tc in toolCalls
      review += "- **#{tc.tool}**: #{JSON.stringify(tc.args or {}).substring(0, 100)}\n"
    review += "\n"
  
  if messages.length > 0
    review += "### Agent Messages\n\n"
    for m in messages
      content = m.message?.content?[0]?.text or ''
      review += "> #{content.substring(0, 200)}\n\n"
  
  review += "### Suggestions\n\n"
  review += "- Review the tool calls above\n"
  review += "- Check for any errors\n"
  review += "- Suggest improvements\n"
  
  fs.writeFileSync REVIEW_FILE, review

watchFiles = (rl) ->
  console.log "\n👀 Watching for changes...\n"
  
  watchSession = fs.watchFile SESSION_FILE, { interval: 1000 }, ->
    events = readSessionEvents()
    if events.length > state.lastEventCount
      newEvents = events[state.lastEventCount..]
      for e in newEvents
        formatted = formatEvent e
        if formatted
          console.log "\n#{formatted}"
      updateReview events
      state.lastEventCount = events.length
  
  watchReview = fs.watchFile REVIEW_FILE, { interval: 1000 }, (curr) ->
    if curr.mtime.getTime() > state.lastReviewMtime
      state.lastReviewMtime = curr.mtime.getTime()
      console.log "\n📝 Review updated by Trae AI"
  
  ->
    fs.unwatchFile SESSION_FILE
    fs.unwatchFile REVIEW_FILE
    console.log "\n👋 Stopped watching\n"

rl = readline.createInterface
  input: process.stdin
  output: process.stdout
  prompt: '\n> '

main = ->
  initFiles()
  clearScreen()
  printHeader()
  printHelp()
  
  unwatch = null
  watching = false
  
  rl.prompt()
  
  rl.on 'line', (line) ->
    line = line.trim()
    
    if line.startsWith('/')
      [cmd, ...args] = line.split(/\s+/)
      rest = args.join(' ')
      
      switch cmd
        when '/exit'
          unwatch?()
          console.log '\n👋 Goodbye!\n'
          process.exit 0
        
        when '/clear'
          clearScreen()
          printHeader()
        
        when '/history'
          showHistory()
        
        when '/tasks'
          showTasks()
        
        when '/task'
          if rest
            addTask rest
          else
            console.log '\nUsage: /task <description>\n'
        
        when '/review'
          showReview()
        
        when '/watch'
          if watching
            unwatch?()
            watching = false
          else
            unwatch = watchFiles rl
            watching = true
        
        else
          console.log "\n❓ Unknown: #{cmd}\n"
    
    else if line
      console.log '\n⏳ Sending to Agent...\n'
      
      callAgent line
        .then (result) ->
          if result.result?.payloads
            for p in result.result.payloads when p.text
              console.log "\n🤖 #{p.text.substring(0, 300)}\n"
          else if result.raw
            console.log "\n🤖 #{result.raw.substring(0, 300)}\n"
          
          events = readSessionEvents()
          updateReview events
          state.lastEventCount = events.length
          
        .catch (e) ->
          console.log "\n❌ #{e.message}\n"
    
    rl.prompt()

main()
