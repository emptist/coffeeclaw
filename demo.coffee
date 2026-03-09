# Minimal Demo: OpenClaw Agent + Trae AI Collaboration
# 
# This script demonstrates the proof of concept for collaboration between
# OpenClaw Agent and Trae AI through shared session files.
#
# How it works:
# 1. Sends a message to OpenClaw Agent via CLI
# 2. Reads the JSONL session file created by the agent
# 3. Parses events (messages, tool calls, results)
# 4. Shows that Trae AI can read the same file and provide reviews
#
# Run: coffee demo.coffee

{ exec } = require 'child_process'
fs = require 'fs'
path = require 'path'

SESSION_ID = 'demo-' + Date.now()
SESSION_FILE = path.join process.env.HOME, '.openclaw/agents/main/sessions', "#{SESSION_ID}.jsonl"

console.log """
=== Demo: OpenClaw Agent Collaboration ===
Session: #{SESSION_ID}
"""

callAgent = (msg) ->
  new Promise (resolve, reject) ->
    cmd = "openclaw agent --local --session-id \"#{SESSION_ID}\" --message #{JSON.stringify(msg)} --json 2>/dev/null"
    exec cmd, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout) ->
      if err then reject(err) else resolve(stdout)

readSession = ->
  return [] unless fs.existsSync SESSION_FILE
  lines = fs.readFileSync(SESSION_FILE, 'utf8').split('\n').filter(Boolean)
  results = []
  for l in lines
    try
      results.push JSON.parse(l)
    catch e
      continue
  results

showEvents = (events) ->
  console.log "\n--- Session Events ---"
  for e in events
    switch e.type
      when 'message'
        role = e.message?.role
        text = e.message?.content?[0]?.text?.substring(0,100) or ''
        console.log "[#{role}] #{text}"
      when 'tool_call'
        console.log "[TOOL] #{e.tool} #{JSON.stringify(e.args or {}).substring(0,80)}"
      when 'tool_result'
        console.log "[RESULT] #{String(e.result or '').substring(0,80)}"
  console.log "----------------------\n"

console.log "\n1. Sending message to OpenClaw Agent..."

callAgent "Hello, what tools do you have?"
  .then (stdout) ->
    result = JSON.parse(stdout)
    
    if result.result?.payloads
      for p in result.result.payloads when p.text
        console.log "\nAgent response: #{p.text.substring(0,200)}"
    
    console.log "\n2. Reading session file..."
    events = readSession()
    console.log "Found #{events.length} events"
    
    showEvents events
    
    console.log "3. Session file location:"
    console.log "   #{SESSION_FILE}"
    
    console.log "\n✅ Demo complete! Collaboration is possible."
    console.log "\nTrae AI can:"
    console.log "  - Read: #{SESSION_FILE}"
    console.log "  - Write suggestions to: .codev/review.md"
    console.log "  - Monitor file changes in real-time"
    
  .catch (e) ->
    console.log "❌ Error:", e.message
